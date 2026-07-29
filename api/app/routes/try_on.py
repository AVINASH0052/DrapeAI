"""External outfit try-on routes (shop / screenshot garments on saved body photo)."""

from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User
from app.services.storage import get_image_url, upload_try_on_session_ref
from app.utils.image_validation import validate_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/try-on", tags=["try-on"])


@router.post("/external")
async def create_external_tryon(
    reference_image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Try an external outfit photo on the user's saved full-body photo."""
    from app.config import settings
    from app.services import try_on_job
    from app.services.external_tryon import run_external_tryon

    await try_on_job.check_tryon_enabled()

    file_bytes = await reference_image.read()
    validate_image(
        reference_image.content_type or "image/jpeg",
        file_bytes,
    )

    pool = await get_pool()
    async with pool.acquire() as conn:
        person = await conn.fetchrow(
            "SELECT try_on_photo_key FROM users WHERE id = $1", user.id
        )
        if not person or not person["try_on_photo_key"]:
            raise HTTPException(
                status_code=400,
                detail="Upload a full-body photo in Profile → See me in outfits first.",
            )

        await try_on_job.check_daily_limit(user.id)
        session_id = str(uuid.uuid4())
        ref_key = await upload_try_on_session_ref(
            user.id,
            session_id,
            file_bytes,
            reference_image.content_type or "image/jpeg",
        )

        await conn.execute(
            """
            INSERT INTO try_on_sessions (
                id, user_id, reference_image_key, status, prompt_version
            ) VALUES ($1::uuid, $2, $3, 'processing', 'external_tryon_v1')
            """,
            session_id,
            user.id,
            ref_key,
        )
        job = await try_on_job.create_job(
            conn, user.id, outfit_id=None, session_id=session_id
        )
        await try_on_job.increment_daily_count(user.id)

    job_id = str(job["id"])
    usage = await try_on_job.daily_usage(user.id)
    person_key = person["try_on_photo_key"]

    # Prefer sync for reliability without Redis in docker-compose.dev.
    # When TRYON_ASYNC + ARQ available, still run inline if enqueue fails.
    run_inline = True
    if settings.tryon_async:
        enqueued = await try_on_job.enqueue_external_tryon_job(
            job_id, user.id, session_id
        )
        if enqueued:
            run_inline = False
            return {
                "session_id": session_id,
                "job_id": job_id,
                "status": "queued",
                **usage,
            }

    if run_inline:
        try:
            result = await run_external_tryon(
                user.id, session_id, person_key, ref_key
            )
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    UPDATE try_on_sessions
                    SET result_image_key = $2,
                        method = $3,
                        provider = $4,
                        model = $5,
                        status = 'completed',
                        completed_at = NOW()
                    WHERE id = $1::uuid AND user_id = $6
                    """,
                    session_id,
                    result.result_key,
                    result.method,
                    result.provider,
                    result.model,
                    user.id,
                )
                await try_on_job.mark_completed(
                    conn,
                    job_id,
                    result_key=result.result_key,
                    method=result.method,
                    provider=result.provider,
                    model=result.model,
                )
            usage = await try_on_job.daily_usage(user.id)
            return {
                "session_id": session_id,
                "job_id": job_id,
                "status": "completed",
                "result_url": get_image_url(result.result_key),
                "method": result.method,
                "model": result.model,
                "provider": result.provider,
                **usage,
            }
        except Exception as e:
            logger.exception("external try-on failed: %s", e)
            async with pool.acquire() as conn:
                await try_on_job.mark_failed(conn, job_id, str(e))
                await conn.execute(
                    """
                    UPDATE try_on_sessions
                    SET status = 'failed',
                        error_message = $2,
                        completed_at = NOW()
                    WHERE id = $1::uuid AND user_id = $3
                    """,
                    session_id,
                    str(e)[:500],
                    user.id,
                )
            await try_on_job.refund_daily_count(user.id)
            usage = await try_on_job.daily_usage(user.id)
            return {
                "session_id": session_id,
                "job_id": job_id,
                "status": "failed",
                "error": str(e),
                **usage,
            }


@router.get("/external/{session_id}")
async def get_external_tryon(
    session_id: str,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT * FROM try_on_sessions
            WHERE id = $1::uuid AND user_id = $2
            """,
            session_id,
            user.id,
        )
    if not row:
        raise HTTPException(status_code=404, detail="Session not found")
    return {
        "session_id": str(row["id"]),
        "status": row["status"],
        "result_url": get_image_url(row["result_image_key"])
        if row["result_image_key"]
        else None,
        "reference_url": get_image_url(row["reference_image_key"]),
        "method": row["method"],
        "model": row["model"],
        "provider": row["provider"],
        "error": row["error_message"],
        "created_at": row["created_at"].isoformat() if row["created_at"] else None,
    }


@router.get("/history")
async def tryon_history(
    user: User = Depends(get_current_user),
    limit: int = Query(20, ge=1, le=50),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, reference_image_key, result_image_key, method, provider,
                   model, status, created_at
            FROM try_on_sessions
            WHERE user_id = $1 AND status = 'completed' AND result_image_key IS NOT NULL
            ORDER BY created_at DESC
            LIMIT $2
            """,
            user.id,
            limit,
        )
    return {
        "sessions": [
            {
                "id": str(r["id"]),
                "result_url": get_image_url(r["result_image_key"]),
                "reference_url": get_image_url(r["reference_image_key"]),
                "method": r["method"],
                "provider": r["provider"],
                "model": r["model"],
                "created_at": r["created_at"].isoformat() if r["created_at"] else None,
            }
            for r in rows
        ]
    }
