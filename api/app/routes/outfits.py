"""Outfit generation and feedback routes."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.outfits import record_feedback, get_today_outfits
from app.database.queries.preferences import get_preferences
from app.database.queries.items import get_item
from app.models.user import User
from app.services.outfit_service import generate_outfits, shuffle_outfit
from app.services.outfit_chat import refine_outfit
from app.services.storage import get_image_url
from app.services.outfit_visualizer import get_outfit_items_from_db

router = APIRouter(prefix="/outfits", tags=["Outfits"])


class GenerateRequest(BaseModel):
    occasion: Literal["casual", "work", "party", "gym", "date", "festive", "travel"]
    weather_override: dict | None = None


class FeedbackRequest(BaseModel):
    action: Literal["like", "dislike", "save", "wear", "skip"]


class RefineRequest(BaseModel):
    message: str


@router.post("/generate")
async def generate(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await generate_outfits(user.id, req.occasion, req.weather_override)
    return result


@router.post("/shuffle")
async def shuffle(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await shuffle_outfit(user.id, req.occasion)
    return result


@router.post("/{outfit_id}/feedback")
async def submit_feedback(
    outfit_id: str,
    req: FeedbackRequest,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM outfits WHERE id = $1 AND user_id = $2", outfit_id, user.id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")
        await record_feedback(conn, user.id, outfit_id, req.action)
    return {"recorded": True}


@router.get("/today")
async def today(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        outfits = await get_today_outfits(conn, user.id)
    if not outfits:
        return {"outfits": [], "cached": False}
    return {"outfits": outfits, "cached": True}


@router.post("/{outfit_id}/refine")
async def refine(
    outfit_id: str,
    req: RefineRequest,
    user: User = Depends(get_current_user),
):
    """Natural-language outfit refinement. User text → swap items from wardrobe."""
    import json

    if not req.message.strip():
        raise HTTPException(status_code=400, detail="message required")

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT item_ids FROM outfits WHERE id = $1 AND user_id = $2",
            outfit_id, user.id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")

        try:
            item_ids = json.loads(row["item_ids"])
        except (TypeError, json.JSONDecodeError):
            item_ids = []

        outfit_items = []
        for iid in item_ids:
            it = await get_item(conn, iid, user.id)
            if it:
                outfit_items.append(it)

        if not outfit_items:
            raise HTTPException(status_code=400, detail="Outfit has no items")

        prefs = await get_preferences(conn, user.id) or {}
        result = await refine_outfit(conn, user.id, outfit_items, req.message, prefs)

    return result


@router.post("/{outfit_id}/visualize")
async def visualize_outfit_preview(
    outfit_id: str,
    user: User = Depends(get_current_user),
    force: bool = Query(False, description="Regenerate even if cached"),
):
    """Generate a preview image of the user wearing this outfit.

    When TRYON_ASYNC is enabled and Redis/ARQ is available, returns
    ``{job_id, status}`` for the client to poll via GET .../visualize/status.
    Otherwise runs synchronously (dev/tests fallback).
    """
    from app.config import settings
    from app.services import try_on_job

    await try_on_job.check_tryon_enabled()

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT o.preview_image_key, u.try_on_photo_key,
                   u.avatar_status, u.avatar_error
            FROM outfits o
            JOIN users u ON u.id = o.user_id
            WHERE o.id = $1 AND o.user_id = $2
            """,
            outfit_id,
            user.id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")

        if row["preview_image_key"] and not force:
            return {
                "preview_url": get_image_url(row["preview_image_key"]),
                "cached": True,
                "method": "cached",
                "status": "completed",
            }

        if not row["try_on_photo_key"]:
            raise HTTPException(
                status_code=400,
                detail="Upload a full-body photo in Profile → See me in outfits first.",
            )

        # The photo is stored before background validation runs, so
        # try_on_photo_key alone doesn't mean it's usable — generating from a
        # rejected photo produces garbage and still costs a try-on.
        try_on_job.check_avatar_ready(row["avatar_status"], row["avatar_error"])

        items = await get_outfit_items_from_db(conn, outfit_id, user.id)
        if not items:
            raise HTTPException(status_code=400, detail="Outfit has no items")

        active = await try_on_job.find_active_job(conn, user.id, outfit_id)
        if active and not force:
            return try_on_job.job_status_payload(active)

        await try_on_job.check_daily_limit(user.id)
        job = await try_on_job.create_job(conn, user.id, outfit_id)
        await try_on_job.increment_daily_count(user.id)

    job_id = str(job["id"])
    usage = await try_on_job.daily_usage(user.id)

    if settings.tryon_async:
        enqueued = await try_on_job.enqueue_visualize_job(job_id, user.id, outfit_id)
        if enqueued:
            return {
                "job_id": job_id,
                "status": "queued",
                "cached": False,
                "outfit_id": outfit_id,
                **usage,
            }

    # Sync fallback (no Redis worker, or TRYON_ASYNC=false). run_visualize_job
    # already marks the job failed + refunds quota internally on error, then
    # re-raises — catch that here so the client gets a clean failed-status
    # payload instead of an unhandled 500.
    try:
        result = await try_on_job.run_visualize_job(job_id, user.id, outfit_id)
    except Exception as e:
        async with pool.acquire() as conn:
            failed = await try_on_job.get_job(conn, job_id, user.id)
        result = (
            try_on_job.job_status_payload(failed)
            if failed
            else {"job_id": job_id, "status": "failed", "error": str(e)}
        )
    usage = await try_on_job.daily_usage(user.id)  # refreshed: failures refund
    return {**result, **usage}


@router.get("/{outfit_id}/visualize/status")
async def visualize_outfit_status(
    outfit_id: str,
    user: User = Depends(get_current_user),
    job_id: str | None = Query(None, description="Specific job to poll"),
):
    """Poll async try-on job status for an outfit."""
    from app.services import try_on_job

    usage = await try_on_job.daily_usage(user.id)
    pool = await get_pool()
    async with pool.acquire() as conn:
        if job_id:
            job = await try_on_job.get_job(conn, job_id, user.id)
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")
            if job.get("outfit_id") and str(job["outfit_id"]) != outfit_id:
                raise HTTPException(status_code=404, detail="Job not found")
            job = await try_on_job.fail_if_stale(conn, job, user.id)
            return {**try_on_job.job_status_payload(job), **usage}

        # Latest job for this outfit
        row = await conn.fetchrow(
            """
            SELECT * FROM try_on_jobs
            WHERE user_id = $1 AND outfit_id = $2::uuid
            ORDER BY created_at DESC
            LIMIT 1
            """,
            user.id,
            outfit_id,
        )
        if not row:
            # Fall back to cached preview if present
            cached = await conn.fetchrow(
                """
                SELECT preview_image_key FROM outfits
                WHERE id = $1::uuid AND user_id = $2
                """,
                outfit_id,
                user.id,
            )
            if cached and cached["preview_image_key"]:
                return {
                    "status": "completed",
                    "preview_url": get_image_url(cached["preview_image_key"]),
                    "cached": True,
                    "method": "cached",
                }
            raise HTTPException(status_code=404, detail="No try-on job found")
        job = await try_on_job.fail_if_stale(conn, dict(row), user.id)
        return {**try_on_job.job_status_payload(job), **usage}
