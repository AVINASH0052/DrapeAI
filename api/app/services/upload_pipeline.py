"""Orchestrates the item upload pipeline.

HTTP accept stores the original photo as a processing placeholder and
returns immediately (Cloudflare ~100s). Background work then Gemini-splits,
tags, and embeds. ARQ when Redis is up; FastAPI BackgroundTasks otherwise.
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
from app.services.garment_splitter import extract_garments
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


def _placeholder_tags(category_hint: str | None = None, label: str | None = None) -> dict:
    tags = dict(PLACEHOLDER_TAGS)
    if category_hint:
        tags["category"] = category_hint
    if label:
        tags["sub_category"] = label
    return tags


async def enqueue_upload_job(item_id: str, user_id: str) -> bool:
    """Enqueue ARQ upload analysis / embedding. Returns False if Redis unavailable."""
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


async def _persist_piece(
    user_id: str,
    image_bytes: bytes,
    *,
    tags: dict,
    processing_status: str = "ready",
    item_id: str | None = None,
    conn=None,
) -> dict:
    item_id = item_id or str(uuid.uuid4())
    storage_key = await upload_image(user_id, item_id, image_bytes, "image/png")

    async def _insert(db) -> dict:
        return await insert_item(
            db,
            user_id,
            storage_key,
            tags,
            item_id=item_id,
            processing_status=processing_status,
        )

    if conn is not None:
        item = await _insert(conn)
    else:
        pool = await get_pool()
        async with pool.acquire() as db:
            item = await _insert(db)

    return {
        "id": item["id"],
        "image_url": get_image_url(item["image_url"]),
        "status": "ready" if processing_status == "ready" else "processing",
        "processing_status": processing_status,
        "tags": tags,
        "confidence": tags.get("confidence", 0.0),
        "category": tags.get("category"),
        "sub_category": tags.get("sub_category"),
        "primary_color": tags.get("primary_color"),
    }


async def _tag_piece(
    image_bytes: bytes,
    *,
    category_hint: str | None = None,
    label: str | None = None,
) -> dict:
    try:
        tags = await tag_item(image_bytes)
        # Keep detect hint if tagger is vague.
        if category_hint and (tags.get("category") or "") in {"", "unknown"}:
            tags["category"] = category_hint
        if label and (tags.get("sub_category") or "") in {"", "processing", "unknown"}:
            tags["sub_category"] = label
        return tags
    except Exception as exc:
        logger.warning("Gemini tag failed, using detect hints: %r", exc)
        return _placeholder_tags(category_hint, label)


async def accept_upload(user_id: str, file_bytes: bytes, _content_type: str | None) -> dict:
    """Store the photo as a processing placeholder. Split/tag runs in background."""
    item = await _persist_piece(
        user_id,
        file_bytes,
        tags=_placeholder_tags(),
        processing_status="processing",
    )
    logger.info("Upload accepted item=%s user=%s (processing)", item["id"], user_id)
    return {
        **item,
        "uploaded": 1,
        "items": [item],
        "split": False,
    }


async def _embed(conn, item_id: str, tags: dict) -> None:
    try:
        embedding = await generate_embedding(tags)
        await store_embedding(conn, item_id, embedding)
    except Exception as e:
        logger.error("Embedding generation failed for item %s: %s", item_id, e)


async def _split_placeholder(conn, item_id: str, user_id: str, source_bytes: bytes) -> None:
    """Replace a processing placeholder with extracted, tagged garments."""
    pieces = await extract_garments(source_bytes)
    if not pieces:
        logger.warning("Gemini split empty — falling back to whole-image + tag")
        processed_bytes = await remove_background(source_bytes)
        tags = await _tag_piece(processed_bytes)
        # New file key so the closet URL changes (CachedNetworkImage + keep source).
        storage_key = await upload_image(user_id, str(uuid.uuid4()), processed_bytes, "image/png")
        updated = await apply_tags_and_image(conn, item_id, user_id, storage_key, tags)
        if not updated:
            raise RuntimeError(f"Failed to update tags for item {item_id}")
        await _embed(conn, item_id, tags)
        return

    first, *rest = pieces
    tags = await _tag_piece(
        first.image_bytes,
        category_hint=first.category_hint,
        label=first.label,
    )
    storage_key = await upload_image(user_id, str(uuid.uuid4()), first.image_bytes, "image/png")
    updated = await apply_tags_and_image(conn, item_id, user_id, storage_key, tags)
    if not updated:
        raise RuntimeError(f"Failed to update tags for item {item_id}")
    await _embed(conn, item_id, tags)

    for piece in rest:
        extra_tags = await _tag_piece(
            piece.image_bytes,
            category_hint=piece.category_hint,
            label=piece.label,
        )
        extra = await _persist_piece(
            user_id,
            piece.image_bytes,
            tags=extra_tags,
            processing_status="ready",
            conn=conn,
        )
        await _embed(conn, extra["id"], extra_tags)

    logger.info(
        "Upload Gemini-split into %d tagged garments for user %s (item=%s)",
        1 + len(rest),
        user_id,
        item_id,
    )


async def run_upload_pipeline(conn, item_id: str, user_id: str) -> None:
    """Background: ensure tags (if still processing) + embedding."""
    row = await conn.fetchrow(
        """
        SELECT id, image_url, processing_status, category, sub_category
        FROM items
        WHERE id = $1::uuid AND user_id = $2 AND is_active = true
        """,
        item_id,
        user_id,
    )
    if not row:
        raise RuntimeError(f"Item {item_id} not found for user {user_id}")

    processed_bytes = await read_image_bytes(row["image_url"])

    if row["processing_status"] != "ready":
        await set_processing_status(conn, item_id, user_id, "processing")
        await _split_placeholder(conn, item_id, user_id, processed_bytes)
        return

    full = await conn.fetchrow(
        """
        SELECT category, sub_category, primary_color, secondary_colors,
               pattern, fabric, style_tags, formality, season_tags, ethnic_flag
        FROM items
        WHERE id = $1::uuid AND user_id = $2
        """,
        item_id,
        user_id,
    )
    if full:
        await _embed(conn, item_id, dict(full))


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


async def regenerate_embedding(item_id: str) -> None:
    """Re-embed a single item after tag edits (BackgroundTasks / ARQ)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT category, sub_category, primary_color, secondary_colors,
                   pattern, fabric, style_tags, formality, season_tags, ethnic_flag
            FROM items
            WHERE id = $1::uuid AND is_active = TRUE
            """,
            item_id,
        )
        if not row:
            logger.warning("regenerate_embedding: item %s not found", item_id)
            return
        tags = dict(row)
        try:
            embedding = await generate_embedding(tags)
            await store_embedding(conn, item_id, embedding)
        except Exception as e:
            logger.error("regenerate_embedding failed item=%s: %r", item_id, e)
            raise
