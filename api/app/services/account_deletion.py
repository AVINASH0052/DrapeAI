"""Hard-delete a user: collect private objects, then CASCADE the row."""

from __future__ import annotations

import logging

from app.services.storage import delete_image, delete_user_prefix

logger = logging.getLogger(__name__)


async def collect_user_image_keys(conn, user_id: str) -> list[str]:
    keys: list[str] = []
    row = await conn.fetchrow(
        "SELECT try_on_photo_key, avatar_base_key FROM users WHERE id = $1",
        user_id,
    )
    if row:
        keys.extend([row["try_on_photo_key"], row["avatar_base_key"]])
    item_rows = await conn.fetch(
        "SELECT image_url FROM items WHERE user_id = $1", user_id
    )
    keys.extend(r["image_url"] for r in item_rows)
    outfit_rows = await conn.fetch(
        "SELECT preview_image_key FROM outfits WHERE user_id = $1", user_id
    )
    keys.extend(r["preview_image_key"] for r in outfit_rows)
    try:
        session_rows = await conn.fetch(
            """
            SELECT reference_image_key, result_image_key
            FROM try_on_sessions WHERE user_id = $1
            """,
            user_id,
        )
        for r in session_rows:
            keys.extend([r["reference_image_key"], r["result_image_key"]])
    except Exception:
        pass
    try:
        job_rows = await conn.fetch(
            "SELECT result_key FROM try_on_jobs WHERE user_id = $1", user_id
        )
        keys.extend(r["result_key"] for r in job_rows)
    except Exception:
        pass
    return [k for k in keys if k]


async def delete_account_data(conn, user_id: str) -> bool:
    """Delete storage then the user row. Safe to retry. Returns whether a row existed."""
    keys = await collect_user_image_keys(conn, user_id)
    existed = await conn.fetchval("SELECT 1 FROM users WHERE id = $1", user_id)
    for key in keys:
        await delete_image(key)
    await delete_user_prefix(user_id)
    if existed:
        await conn.execute("DELETE FROM users WHERE id = $1", user_id)
    logger.info("Account deletion finished for user_ref=%s existed=%s", user_id[:8], bool(existed))
    return bool(existed)
