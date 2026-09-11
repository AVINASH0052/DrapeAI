"""Prepare and persist the user's body-first 2.5D avatar base."""

import asyncio
import json
import logging
from io import BytesIO

from PIL import Image, ImageOps

from app.database.pool import get_pool
from app.services.bg_remover import remove_background
from app.services.storage import read_image_bytes, upload_avatar_base
from app.services.tryon_input_check import check_person_photo

logger = logging.getLogger(__name__)


def _sanitize_source_sync(image_bytes: bytes) -> bytes:
    """Normalize orientation and remove EXIF/GPS metadata from body photos."""
    image = ImageOps.exif_transpose(Image.open(BytesIO(image_bytes))).convert("RGB")
    image.thumbnail((2048, 2048), Image.Resampling.LANCZOS)
    output = BytesIO()
    image.save(output, format="JPEG", quality=90, optimize=True)
    return output.getvalue()


async def sanitize_avatar_source(image_bytes: bytes) -> bytes:
    """Strip metadata without blocking the API event loop."""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(None, _sanitize_source_sync, image_bytes)


async def enqueue_avatar_analysis(user_id: str) -> bool:
    """Queue avatar analysis in ARQ, returning False when Redis is unavailable."""
    try:
        from arq import create_pool

        from app.workers.worker import _parse_redis_url

        redis = await create_pool(_parse_redis_url(fast_fail=True))
        try:
            await redis.enqueue_job(
                "app.workers.tasks.process_avatar",
                user_id,
            )
        finally:
            await redis.close()
        return True
    except Exception as exc:
        logger.warning("avatar: ARQ enqueue unavailable: %r", exc)
        return False


def _renderability_profile(png_bytes: bytes) -> dict:
    image = Image.open(BytesIO(png_bytes)).convert("RGBA")
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        raise ValueError("No visible person was found after segmentation.")

    left, top, right, bottom = bbox
    width, height = image.size
    return {
        "pose": "front_or_three_quarter",
        "visibility": "full_body",
        "aspect_ratio": round(width / height, 4),
        "image_size": {"width": width, "height": height},
        "crop_bounds": {
            "left": round(left / width, 4),
            "top": round(top / height, 4),
            "right": round(right / width, 4),
            "bottom": round(bottom / height, 4),
        },
    }


async def run_avatar_analysis(user_id: str) -> dict:
    """Validate and segment a full-body photo without inferring measurements."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        source_key = await conn.fetchval(
            """
            UPDATE users
            SET avatar_status = 'processing', avatar_error = NULL
            WHERE id = $1
            RETURNING try_on_photo_key
            """,
            user_id,
        )
    if not source_key:
        raise ValueError("Upload a full-body photo before preparing an avatar.")

    try:
        source = await read_image_bytes(source_key)
        check = await check_person_photo(source)
        if not check.ok:
            raise ValueError(check.reason or "Use a clear, full-body photo.")

        # Keep avatar base sharp for Studio overlays (not the old 1024 cap).
        avatar_bytes = await remove_background(source, max_side=2048)
        profile = _renderability_profile(avatar_bytes)
        avatar_key = await upload_avatar_base(user_id, avatar_bytes)

        async with pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE users
                SET avatar_status = 'ready',
                    avatar_base_key = $2,
                    avatar_profile = $3::jsonb,
                    avatar_error = NULL,
                    avatar_analyzed_at = NOW()
                WHERE id = $1
                """,
                user_id,
                avatar_key,
                json.dumps(profile),
            )
            from app.database.queries.notifications import create_notification

            try:
                await create_notification(
                    conn,
                    user_id,
                    title="Avatar ready",
                    body="Your body photo is ready — open Avatar Studio to try looks.",
                    notif_type="avatar",
                    data=json.dumps({"screen": "avatar_studio"}),
                )
            except Exception:
                logger.exception("Failed to create avatar-ready notification")
        return profile
    except Exception as exc:
        logger.exception("Avatar analysis failed for user %s", user_id)
        async with pool.acquire() as conn:
            await conn.execute(
                """
                UPDATE users
                SET avatar_status = 'failed', avatar_error = $2
                WHERE id = $1
                """,
                user_id,
                str(exc)[:500],
            )
        raise
