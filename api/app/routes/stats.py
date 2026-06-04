"""User wardrobe statistics routes."""

import logging

from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User
from app.services.storage import get_image_url

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Stats"])


@router.get("/me/stats")
async def get_my_stats(user: User = Depends(get_current_user)):
    """Aggregated wardrobe statistics for the current user."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Total active items
        total_items = await conn.fetchval(
            "SELECT COUNT(*) FROM items WHERE user_id = $1 AND is_active = TRUE",
            user.id,
        )

        # Saved outfits
        saved_outfits = await conn.fetchval(
            "SELECT COUNT(*) FROM outfits WHERE user_id = $1 AND is_saved = TRUE",
            user.id,
        )

        # Total outfits generated
        total_outfits_generated = await conn.fetchval(
            "SELECT COUNT(*) FROM outfits WHERE user_id = $1",
            user.id,
        )

        # Utilization: percentage of active items worn at least once
        worn_count = await conn.fetchval(
            "SELECT COUNT(*) FROM items WHERE user_id = $1 AND is_active = TRUE AND wear_count > 0",
            user.id,
        )
        utilization_pct = round((worn_count / total_items * 100) if total_items else 0, 1)

        # Top 5 most worn items
        most_worn_rows = await conn.fetch(
            """
            SELECT id, image_url, category, wear_count
            FROM items
            WHERE user_id = $1 AND is_active = TRUE AND wear_count > 0
            ORDER BY wear_count DESC
            LIMIT 5
            """,
            user.id,
        )
        most_worn_items = [
            {
                "id": str(r["id"]),
                "image_url": get_image_url(r["image_url"]),
                "category": r["category"],
                "wear_count": r["wear_count"],
            }
            for r in most_worn_rows
        ]

        # Bottom 5 least worn items (wear_count = 0)
        least_worn_rows = await conn.fetch(
            """
            SELECT id, image_url, category
            FROM items
            WHERE user_id = $1 AND is_active = TRUE AND wear_count = 0
            ORDER BY created_at DESC
            LIMIT 5
            """,
            user.id,
        )
        least_worn_items = [
            {
                "id": str(r["id"]),
                "image_url": get_image_url(r["image_url"]),
                "category": r["category"],
            }
            for r in least_worn_rows
        ]

        # Category distribution
        cat_rows = await conn.fetch(
            """
            SELECT category, COUNT(*) AS cnt
            FROM items
            WHERE user_id = $1 AND is_active = TRUE
            GROUP BY category
            ORDER BY cnt DESC
            """,
            user.id,
        )
        category_distribution = {r["category"]: r["cnt"] for r in cat_rows}

    return {
        "total_items": total_items,
        "saved_outfits": saved_outfits,
        "total_outfits_generated": total_outfits_generated,
        "utilization_pct": utilization_pct,
        "most_worn_items": most_worn_items,
        "least_worn_items": least_worn_items,
        "category_distribution": category_distribution,
    }
