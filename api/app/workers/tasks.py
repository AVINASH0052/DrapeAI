"""Background tasks processed via ARQ (async Redis queue).

Tasks are enqueued from API routes and processed by a separate
worker process. This keeps HTTP requests fast (return 201/202)
while heavy work (bg removal, AI tagging, embedding) runs async.
"""

import logging
from typing import Any

logger = logging.getLogger(__name__)


async def process_upload(ctx: dict[str, Any], item_id: str, user_id: str) -> str:
    """Full upload pipeline: bg removal → AI vision tagging → embedding.

    Enqueued after image is saved to storage.
    The item row already exists with image_url but has placeholder tags.
    """
    from app.database.pool import get_pool
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
        # Mark the item as failed so frontend can show error state
        try:
            pool = await get_pool()
            async with pool.acquire() as conn:
                await conn.execute(
                    "UPDATE items SET notes = $1 WHERE id = $2::uuid",
                    f"Processing failed: {str(e)[:200]}",
                    item_id,
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
    from app.services.push_sender import send_daily_outfit_push

    logger.info("[worker] send_daily_push triggered")
    try:
        count = await send_daily_outfit_push()
        logger.info(f"[worker] send_daily_push: sent to {count} users")
        return f"sent:{count}"
    except Exception as e:
        logger.error(f"[worker] send_daily_push failed: {e!r}")
        raise
