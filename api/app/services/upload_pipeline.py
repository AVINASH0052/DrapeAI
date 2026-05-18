"""Orchestrates the full item upload pipeline."""

import logging
import uuid

from app.database.pool import get_pool
from app.database.queries.items import insert_item, store_embedding
from app.services.bg_remover import remove_background
from app.services.vision_tagger import tag_item
from app.services.embedder import generate_embedding
from app.services.storage import upload_image, get_image_url

logger = logging.getLogger(__name__)


async def process_upload(user_id: str, file_bytes: bytes, content_type: str) -> dict:
    """Full upload pipeline:
    1. Remove background (rembg, 2-4s)
    2. Upload processed image to storage
    3. Tag with GPT-4o Vision (~3s)
    4. Generate embedding (~0.5s)
    5. Insert item row in DB
    6. Store embedding
    """
    # 1. Background removal
    processed_bytes = await remove_background(file_bytes)

    # 2. Upload to storage (use temp UUID as item_id; real ID comes from DB insert)
    item_id = str(uuid.uuid4())
    storage_key = await upload_image(user_id, item_id, processed_bytes, "image/png")

    # 3. Vision tagging
    tags = await tag_item(processed_bytes)

    # 4. Insert item in DB
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await insert_item(conn, user_id, storage_key, tags)

    # 5. Generate and store embedding (non-blocking for response, but we await it)
    try:
        embedding = await generate_embedding(tags)
        async with pool.acquire() as conn:
            await store_embedding(conn, item["id"], embedding)
    except Exception as e:
        logger.error(f"Embedding generation failed for item {item['id']}: {e}")
        # Item is still usable without embedding

    # 6. Return response
    item["image_url"] = get_image_url(item["image_url"])
    return {
        "id": item["id"],
        "image_url": item["image_url"],
        "tags": tags,
        "confidence": tags.get("confidence", 0.0),
    }


async def regenerate_embedding(item_id: str) -> None:
    """Re-generate embedding when user edits tags. Called as background task."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("SELECT * FROM items WHERE id = $1", item_id)
    if not row:
        return

    tags = {
        "category": row["category"],
        "sub_category": row["sub_category"],
        "primary_color": row["primary_color"],
        "pattern": row["pattern"],
        "fabric": row["fabric"],
        "style_tags": row["style_tags"],
        "season_tags": row["season_tags"],
        "ethnic_flag": row["ethnic_flag"],
    }

    try:
        embedding = await generate_embedding(tags)
        async with pool.acquire() as conn:
            await store_embedding(conn, item_id, embedding)
        logger.info(f"Re-generated embedding for item {item_id}")
    except Exception as e:
        logger.error(f"Embedding regeneration failed for {item_id}: {e}")
