"""Orchestrates the item upload pipeline.

Fast path: store the image + placeholder row, return immediately.
Background: rembg → vision tags → update row → embedding.
"""

import logging
import uuid

from app.database.pool import get_pool
from app.database.queries.items import (
    apply_tags_and_image,
    insert_item,
    set_processing_status,
    store_embedding,
)
from app.services.bg_remover import remove_background
from app.services.embedder import generate_embedding
from app.services.storage import get_image_url, read_image_bytes, upload_image
from app.services.vision_tagger import tag_item

logger = logging.getLogger(__name__)

PLACEHOLDER_TAGS = {
    "category": "top",
    "sub_category": "processing",
    "primary_color": "unknown",
    "secondary_colors": [],
    "pattern": "solid",
    "fabric": "cotton",
    "style_tags": [],
    "formality": 3,
    "season_tags": ["all_season"],
    "ethnic_flag": False,
    "confidence": 0.0,
}


async def enqueue_upload_job(item_id: str, user_id: str) -> bool:
    """Enqueue ARQ upload analysis. Returns False if Redis/worker unavailable."""
    try:
        from arq import create_pool

        from app.workers.worker import _parse_redis_url

        redis = await create_pool(_parse_redis_url(fast_fail=True))
        try:
            await redis.enqueue_job(
                "app.workers.tasks.process_upload",
                item_id,
                user_id,
                _job_id=f"upload:{item_id}",
            )
        finally:
            await redis.close()
        return True
    except Exception as e:
        logger.warning(f"upload: ARQ enqueue failed, will run inline: {e!r}")
        return False


async def accept_upload(user_id: str, file_bytes: bytes, _content_type: str | None) -> dict:
    """Remove the background, persist the clean image, and queue AI analysis."""
    item_id = str(uuid.uuid4())
    processed_bytes = await remove_background(file_bytes)
    storage_key = await upload_image(
        user_id, item_id, processed_bytes, "image/png"
    )

    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await insert_item(
            conn,
            user_id,
            storage_key,
            PLACEHOLDER_TAGS,
            item_id=item_id,
            processing_status="queued",
        )

    return {
        "id": item["id"],
        "image_url": get_image_url(item["image_url"]),
        "status": "processing",
        "processing_status": "queued",
        "tags": PLACEHOLDER_TAGS,
        "confidence": 0.0,
    }


async def run_upload_pipeline(conn, item_id: str, user_id: str) -> None:
    """Background analysis for an already-accepted upload."""
    row = await conn.fetchrow(
        """
        SELECT id, image_url, processing_status
        FROM items
        WHERE id = $1::uuid AND user_id = $2 AND is_active = true
        """,
        item_id,
        user_id,
    )
    if not row:
        raise RuntimeError(f"Item {item_id} not found for user {user_id}")

    await set_processing_status(conn, item_id, user_id, "processing")

    processed_bytes = await read_image_bytes(row["image_url"])
    storage_key = row["image_url"]
    tags = await tag_item(processed_bytes)

    updated = await apply_tags_and_image(conn, item_id, user_id, storage_key, tags)
    if not updated:
        raise RuntimeError(f"Failed to update tags for item {item_id}")

    try:
        embedding = await generate_embedding(tags)
        await store_embedding(conn, item_id, embedding)
    except Exception as e:
        logger.error(f"Embedding generation failed for item {item_id}: {e}")


async def run_upload_pipeline_standalone(item_id: str, user_id: str) -> None:
    """Run analysis outside an open transaction (BackgroundTasks / fallback)."""
    pool = await get_pool()
    try:
        async with pool.acquire() as conn:
            await run_upload_pipeline(conn, item_id, user_id)
    except Exception as e:
        logger.error(f"Background upload analysis failed item={item_id}: {e!r}")
        try:
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


async def process_upload(user_id: str, file_bytes: bytes, content_type: str) -> dict:
    """Legacy sync path: accept + analyze before returning (tests / fallback)."""
    result = await accept_upload(user_id, file_bytes, content_type)
    await run_upload_pipeline_standalone(result["id"], user_id)
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM items WHERE id = $1::uuid AND user_id = $2",
            result["id"],
            user_id,
        )
    item = dict(row) if row else {}
    return {
        "id": result["id"],
        "image_url": get_image_url(item.get("image_url", "")),
        "status": "ready",
        "processing_status": item.get("processing_status", "ready"),
        "tags": {
            "category": item.get("category"),
            "sub_category": item.get("sub_category"),
            "primary_color": item.get("primary_color"),
            "secondary_colors": item.get("secondary_colors"),
            "pattern": item.get("pattern"),
            "fabric": item.get("fabric"),
            "style_tags": item.get("style_tags"),
            "formality": item.get("formality"),
            "season_tags": item.get("season_tags"),
            "ethnic_flag": item.get("ethnic_flag"),
            "confidence": item.get("confidence", 0.0),
        },
        "confidence": item.get("confidence", 0.0),
    }
