"""Demo wardrobe activation — copy demo items into a user's closet."""

import json
import logging
import uuid

from app.database.pool import get_pool
from app.services.demo_wardrobe import DEMO_USER_ID

logger = logging.getLogger(__name__)


async def activate_demo_for_user(user_id: str) -> dict:
    """Copy demo wardrobe items into the user's account (marked is_demo=True)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        existing = await conn.fetchval(
            "SELECT COUNT(*) FROM items WHERE user_id = $1 AND is_demo = TRUE",
            user_id,
        )
        if existing and existing > 0:
            return {"activated": True, "items_added": 0, "already_active": True}

        demo_rows = await conn.fetch(
            """
            SELECT image_url, category, sub_category, primary_color,
                   secondary_colors, pattern, fabric, style_tags, formality,
                   season_tags, ethnic_flag, confidence
            FROM items
            WHERE user_id = $1 AND is_active = TRUE
            ORDER BY created_at
            """,
            DEMO_USER_ID,
        )
        if not demo_rows:
            return {"activated": False, "items_added": 0, "error": "demo_not_seeded"}

        count = 0
        for row in demo_rows:
            item_id = str(uuid.uuid4())
            sec = row["secondary_colors"]
            styles = row["style_tags"]
            seasons = row["season_tags"]
            if isinstance(sec, str):
                sec = json.loads(sec)
            if isinstance(styles, str):
                styles = json.loads(styles)
            if isinstance(seasons, str):
                seasons = json.loads(seasons)

            await conn.execute(
                """
                INSERT INTO items (
                    id, user_id, image_url, category, sub_category,
                    primary_color, secondary_colors, pattern, fabric,
                    style_tags, formality, season_tags, ethnic_flag,
                    confidence, is_demo
                ) VALUES (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, TRUE
                )
                """,
                item_id,
                user_id,
                row["image_url"],
                row["category"],
                row["sub_category"],
                row["primary_color"],
                json.dumps(sec),
                row["pattern"],
                row["fabric"],
                json.dumps(styles),
                row["formality"],
                json.dumps(seasons),
                row["ethnic_flag"],
                row["confidence"],
            )
            count += 1

    logger.info(f"Demo wardrobe activated for user={user_id}, items={count}")
    return {"activated": True, "items_added": count, "already_active": False}


async def clear_demo_for_user(user_id: str) -> dict:
    """Remove demo items from a user's wardrobe."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            "DELETE FROM items WHERE user_id = $1 AND is_demo = TRUE",
            user_id,
        )
    # result like "DELETE 15"
    deleted = int(result.split()[-1]) if result else 0
    return {"cleared": True, "items_removed": deleted}
