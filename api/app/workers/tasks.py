"""Background tasks processed via ARQ (async Redis queue).

Tasks are enqueued from API routes and processed by a separate
worker process. This keeps HTTP requests fast (return 201/202)
while heavy work (bg removal, AI tagging, embedding) runs async.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


async def process_avatar(ctx: dict[str, Any], user_id: str) -> str:
    """Validate and segment a user's uploaded full-body avatar source."""
    from app.services.avatar_analysis import run_avatar_analysis

    logger.info("[worker] process_avatar: user=%s", user_id)
    await run_avatar_analysis(user_id)
    logger.info("[worker] process_avatar complete: user=%s", user_id)
    return f"ok:{user_id}"


async def process_upload(ctx: dict[str, Any], item_id: str, user_id: str) -> str:
    """Full upload pipeline: bg removal → AI vision tagging → embedding.

    Enqueued after image is saved to storage.
    The item row already exists with image_url but has placeholder tags.
    """
    from app.database.pool import get_pool
    from app.database.queries.items import set_processing_status
    from app.services.upload_pipeline import run_upload_pipeline

    logger.info(f"[worker] process_upload: item={item_id} user={user_id}")
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            await run_upload_pipeline(conn, item_id, user_id)
        logger.info(f"[worker] process_upload complete: item={item_id}")
        return f"ok:{item_id}"
    except Exception as e:
        logger.error(f"[worker] process_upload failed: item={item_id}: {e!r}")
        try:
            pool = await get_pool()
            async with pool.acquire() as conn:
                await set_processing_status(
                    conn,
                    item_id,
                    user_id,
                    "failed",
                    notes=f"Processing failed: {str(e)[:200]}",
                )
        except Exception:
            pass
        raise


async def regenerate_embedding(ctx: dict[str, Any], item_id: str) -> str:
    """Re-generate embedding for a single item after tag edits."""
    from app.database.pool import get_pool
    from app.services.embedding import generate_and_store_embedding

    logger.info(f"[worker] regenerate_embedding: item={item_id}")
    pool = await get_pool()
    async with pool.acquire() as conn:
        await generate_and_store_embedding(conn, item_id)
    logger.info(f"[worker] regenerate_embedding complete: item={item_id}")
    return f"ok:{item_id}"


async def send_daily_push(ctx: dict[str, Any]) -> str:
    """Morning push notification — 'Your outfit for today is ready!'

    Scheduled via ARQ cron at 7:30 AM IST.
    """
    from app.services.push_sender import send_daily_outfit_pushes_batch

    logger.info("[worker] send_daily_push triggered")
    try:
        count = await send_daily_outfit_pushes_batch()
        logger.info(f"[worker] send_daily_push: sent to {count} users")
        return f"sent:{count}"
    except Exception as e:
        logger.error(f"[worker] send_daily_push failed: {e!r}")
        raise


async def process_try_on(
    ctx: dict[str, Any],
    job_id: str,
    user_id: str,
    outfit_id: str,
) -> str:
    """Generate outfit try-on preview for an async job."""
    from app.services.try_on_job import run_visualize_job

    logger.info(f"[worker] process_try_on: job={job_id} outfit={outfit_id}")
    try:
        result = await run_visualize_job(job_id, user_id, outfit_id)
        logger.info(
            f"[worker] process_try_on complete: job={job_id} status={result.get('status')}"
        )
        return f"ok:{job_id}"
    except Exception as e:
        logger.error(f"[worker] process_try_on failed: job={job_id}: {e!r}")
        raise


async def process_external_try_on(
    ctx: dict[str, Any],
    job_id: str,
    user_id: str,
    session_id: str,
) -> str:
    """Generate external (shop) try-on for an async job."""
    from app.database.pool import get_pool
    from app.services import try_on_job
    from app.services.external_tryon import run_external_tryon

    logger.info(f"[worker] process_external_try_on: job={job_id} session={session_id}")
    pool = await get_pool()
    try:
        async with pool.acquire() as conn:
            await try_on_job.mark_processing(conn, job_id)
            row = await conn.fetchrow(
                """
                SELECT s.reference_image_key, u.try_on_photo_key
                FROM try_on_sessions s
                JOIN users u ON u.id = s.user_id
                WHERE s.id = $1::uuid AND s.user_id = $2
                """,
                session_id,
                user_id,
            )
            if not row or not row["try_on_photo_key"]:
                await try_on_job.mark_failed(conn, job_id, "Missing try-on photo")
                await try_on_job.refund_daily_count(user_id)
                return f"failed:{job_id}"

        result = await run_external_tryon(
            user_id,
            session_id,
            row["try_on_photo_key"],
            row["reference_image_key"],
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
                user_id,
            )
            await try_on_job.mark_completed(
                conn,
                job_id,
                result_key=result.result_key,
                method=result.method,
                provider=result.provider,
                model=result.model,
            )
        return f"ok:{job_id}"
    except Exception as e:
        logger.error(f"[worker] process_external_try_on failed: {e!r}")
        try:
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
                    user_id,
                )
            await try_on_job.refund_daily_count(user_id)
        except Exception:
            pass
        raise
