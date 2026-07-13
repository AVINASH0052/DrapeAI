"""Async try-on job enqueue, status, and rate limiting."""

from __future__ import annotations

import logging
from datetime import datetime, time as dt_time, timedelta, timezone
from typing import Any, Optional

from fastapi import HTTPException

from app.config import settings
from app.services.storage import get_image_url

logger = logging.getLogger(__name__)


def _utc_today() -> str:
    return datetime.now(timezone.utc).date().isoformat()


def _next_utc_midnight() -> str:
    tomorrow = datetime.now(timezone.utc).date() + timedelta(days=1)
    reset = datetime.combine(tomorrow, dt_time.min, tzinfo=timezone.utc)
    return reset.isoformat().replace("+00:00", "Z")


async def check_tryon_enabled() -> None:
    if not settings.tryon_enabled:
        raise HTTPException(
            status_code=503,
            detail="Try-on is temporarily disabled. Please try again later.",
        )


async def check_daily_limit(user_id: str) -> None:
    """Enforce TRYON_DAILY_LIMIT_FREE. Uses Redis when available, else DB count."""
    limit = settings.tryon_daily_limit_free
    if limit <= 0:
        return

    count = await _daily_count(user_id, _utc_today())
    if count >= limit:
        raise HTTPException(
            status_code=429,
            detail={
                "message": "Daily try-on limit reached",
                "limit": limit,
                "remaining": 0,
                "resets_at": _next_utc_midnight(),
            },
        )


async def daily_usage(user_id: str) -> dict[str, Any]:
    """Current limit/remaining for the UI banner. Unlimited → both None."""
    limit = settings.tryon_daily_limit_free
    if limit <= 0:
        return {"limit": None, "remaining": None}
    count = await _daily_count(user_id, _utc_today())
    return {"limit": limit, "remaining": max(0, limit - count)}


async def increment_daily_count(user_id: str) -> int:
    today = _utc_today()
    try:
        from app.services.redis_client import get_redis

        redis = await get_redis()
        key = f"tryon:daily:{user_id}:{today}"
        count = await redis.incr(key)
        if count == 1:
            await redis.expire(key, 60 * 60 * 36)
        return int(count)
    except Exception:
        # DB fallback: count completed/queued jobs created today
        return await _daily_count(user_id, today) + 1


async def refund_daily_count(user_id: str) -> None:
    """Give the try-on back when a job fails — failures shouldn't burn quota.

    Redis path only: the DB fallback count already excludes failed jobs.
    """
    try:
        from app.services.redis_client import get_redis

        redis = await get_redis()
        key = f"tryon:daily:{user_id}:{_utc_today()}"
        count = await redis.decr(key)
        if count < 0:
            await redis.set(key, 0, keepttl=True)
    except Exception as e:
        logger.debug(f"tryon: refund skipped (no redis): {e!r}")


async def _daily_count(user_id: str, today: str) -> int:
    try:
        from app.services.redis_client import get_redis

        redis = await get_redis()
        key = f"tryon:daily:{user_id}:{today}"
        raw = await redis.get(key)
        if raw is not None:
            return int(raw)
    except Exception:
        pass

    from datetime import date as date_type

    from app.database.pool import get_pool

    pool = await get_pool()
    async with pool.acquire() as conn:
        return int(
            await conn.fetchval(
                """
                SELECT COUNT(*) FROM try_on_jobs
                WHERE user_id = $1
                  AND (created_at AT TIME ZONE 'UTC')::date = $2
                  AND status IN ('queued', 'processing', 'completed')
                """,
                user_id,
                date_type.fromisoformat(today),
            )
            or 0
        )


def _stale_after_seconds() -> int:
    """Jobs stuck in queued/processing beyond this are considered dead."""
    return max(60, settings.tryon_job_timeout_sec * 2)


async def find_active_job(conn, user_id: str, outfit_id: str) -> Optional[dict]:
    row = await conn.fetchrow(
        """
        SELECT * FROM try_on_jobs
        WHERE user_id = $1 AND outfit_id = $2::uuid
          AND status IN ('queued', 'processing')
          AND created_at > NOW() - make_interval(secs => $3)
        ORDER BY created_at DESC
        LIMIT 1
        """,
        user_id,
        outfit_id,
        float(_stale_after_seconds()),
    )
    return dict(row) if row else None


async def fail_if_stale(conn, job: dict, user_id: str) -> dict:
    """Mark a dead queued/processing job failed and refund its quota."""
    if job.get("status") not in ("queued", "processing"):
        return job
    created = job.get("created_at")
    if created is None:
        return job
    age = (datetime.now(timezone.utc) - created).total_seconds()
    if age <= _stale_after_seconds():
        return job
    job_id = str(job["id"])
    await mark_failed(conn, job_id, "Timed out waiting for worker")
    await refund_daily_count(user_id)
    refreshed = await get_job(conn, job_id, user_id)
    return refreshed or job


async def create_job(conn, user_id: str, outfit_id: str) -> dict:
    row = await conn.fetchrow(
        """
        INSERT INTO try_on_jobs (user_id, outfit_id, status)
        VALUES ($1, $2::uuid, 'queued')
        RETURNING *
        """,
        user_id,
        outfit_id,
    )
    return dict(row)


async def get_job(conn, job_id: str, user_id: str) -> Optional[dict]:
    row = await conn.fetchrow(
        "SELECT * FROM try_on_jobs WHERE id = $1::uuid AND user_id = $2",
        job_id,
        user_id,
    )
    return dict(row) if row else None


async def mark_processing(conn, job_id: str) -> None:
    await conn.execute(
        """
        UPDATE try_on_jobs
        SET status = 'processing', started_at = NOW()
        WHERE id = $1::uuid AND status = 'queued'
        """,
        job_id,
    )


async def mark_completed(
    conn,
    job_id: str,
    *,
    result_key: str,
    method: str,
    provider: str | None,
    model: str | None,
) -> None:
    await conn.execute(
        """
        UPDATE try_on_jobs
        SET status = 'completed',
            result_key = $2,
            method = $3,
            provider = $4,
            model = $5,
            completed_at = NOW()
        WHERE id = $1::uuid
        """,
        job_id,
        result_key,
        method,
        provider,
        model,
    )


async def mark_failed(conn, job_id: str, error: str) -> None:
    await conn.execute(
        """
        UPDATE try_on_jobs
        SET status = 'failed',
            error_message = $2,
            completed_at = NOW()
        WHERE id = $1::uuid
        """,
        job_id,
        error[:500],
    )


def job_status_payload(job: dict) -> dict[str, Any]:
    status = job["status"]
    payload: dict[str, Any] = {
        "job_id": str(job["id"]),
        "status": status,
        "outfit_id": str(job["outfit_id"]) if job.get("outfit_id") else None,
        "method": job.get("method"),
        "model": job.get("model"),
        "provider": job.get("provider"),
        "error": job.get("error_message"),
        "preview_url": get_image_url(job["result_key"]) if job.get("result_key") else None,
        "cached": False,
    }
    return payload


async def enqueue_visualize_job(job_id: str, user_id: str, outfit_id: str) -> bool:
    """Enqueue ARQ task. Returns False if Redis/ARQ unavailable."""
    try:
        from arq import create_pool
        from app.workers.worker import _parse_redis_url

        redis = await create_pool(_parse_redis_url())
        try:
            # Name must match WorkerSettings.functions registration, which uses
            # the full dotted path.
            await redis.enqueue_job(
                "app.workers.tasks.process_try_on",
                str(job_id),
                user_id,
                outfit_id,
                _job_id=f"tryon:{job_id}",
            )
        finally:
            await redis.close()
        return True
    except Exception as e:
        logger.warning(f"tryon: ARQ enqueue failed, will run inline: {e!r}")
        return False


async def _ensure_garment_checked(conn, item: dict) -> "InputCheckResult":
    """Run (or reuse cached) pre-flight check on a wardrobe item's photo.

    Cached on the item row keyed by image_url, so re-visualizing the same
    outfit doesn't re-pay for a vision call every time — only a changed or
    never-checked photo triggers a fresh check.
    """
    from app.services.storage import read_image_bytes
    from app.services.tryon_input_check import InputCheckResult, check_garment_photo

    image_url = item.get("image_url") or ""
    if not image_url or image_url.startswith("http"):
        return InputCheckResult(ok=True, checked=False)

    if item.get("tryon_ref_checked_key") == image_url and item.get("tryon_ref_ok") is not None:
        return InputCheckResult(
            ok=bool(item["tryon_ref_ok"]),
            issue=item.get("tryon_ref_issue") or "none",
            reason=item.get("tryon_ref_reason") or "",
        )

    try:
        image_bytes = await read_image_bytes(image_url)
    except Exception as e:
        logger.warning(f"tryon input check: could not read item image {image_url}: {e!r}")
        return InputCheckResult(ok=True, checked=False)

    result = await check_garment_photo(image_bytes)
    if result.checked:
        await conn.execute(
            """
            UPDATE items
            SET tryon_ref_checked_key = $1, tryon_ref_ok = $2,
                tryon_ref_issue = $3, tryon_ref_reason = $4
            WHERE id = $5
            """,
            image_url,
            result.ok,
            result.issue,
            result.reason,
            item["id"],
        )
    return result


async def run_visualize_job(job_id: str, user_id: str, outfit_id: str) -> dict:
    """Execute visualize for a job and update DB rows."""
    from app.database.pool import get_pool
    from app.services.outfit_visualizer import (
        get_outfit_items_from_db,
        visualize_outfit,
    )

    pool = await get_pool()
    async with pool.acquire() as conn:
        await mark_processing(conn, job_id)
        row = await conn.fetchrow(
            """
            SELECT u.try_on_photo_key
            FROM users u
            WHERE u.id = $1
            """,
            user_id,
        )
        if not row or not row["try_on_photo_key"]:
            await mark_failed(conn, job_id, "No try-on photo")
            await refund_daily_count(user_id)
            raise RuntimeError("No try-on photo")

        items = await get_outfit_items_from_db(conn, outfit_id, user_id)
        if not items:
            await mark_failed(conn, job_id, "Outfit has no items")
            await refund_daily_count(user_id)
            raise RuntimeError("Outfit has no items")

        try:
            for item in items:
                check = await _ensure_garment_checked(conn, item)
                if not check.ok:
                    label = item.get("sub_category") or item.get("category") or "item"
                    raise RuntimeError(f"{label}: {check.reason}")

            viz = await visualize_outfit(
                user_id,
                outfit_id,
                row["try_on_photo_key"],
                items,
            )
            await conn.execute(
                "UPDATE outfits SET preview_image_key = $1 WHERE id = $2::uuid",
                viz.preview_key,
                outfit_id,
            )
            provider = None
            if viz.method.startswith("ai:"):
                provider = viz.method.split(":", 1)[1]
            await mark_completed(
                conn,
                job_id,
                result_key=viz.preview_key,
                method=viz.method,
                provider=provider,
                model=viz.model,
            )
            job = await get_job(conn, job_id, user_id)
            return job_status_payload(job or {})
        except Exception as e:
            await mark_failed(conn, job_id, str(e))
            await refund_daily_count(user_id)
            raise
