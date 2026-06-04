"""Wardrobe-level routes (analytics, gap analysis)."""

import logging

from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.preferences import get_preferences
from app.models.user import User
from app.services.wardrobe_analysis import analyze_wardrobe_gaps

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wardrobe", tags=["Wardrobe"])


@router.get("/gaps")
async def get_gaps(user: User = Depends(get_current_user)):
    """Return prioritized list of items the user should add to their wardrobe.

    Backed by the heavy-reasoning model (Claude Sonnet primary). Cached per-user
    for 7 days via outfit_cache table to avoid re-running on every open.
    """
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT * FROM items WHERE user_id = $1 AND is_active = TRUE",
            user.id,
        )
        items = [dict(r) for r in rows]
        prefs = await get_preferences(conn, user.id) or {}

        if len(items) < 1:
            return {
                "gaps": [],
                "message": "Add some items to your wardrobe first.",
            }

        gaps = await analyze_wardrobe_gaps(conn, user.id, items, prefs)
    return {"gaps": gaps, "total_items": len(items)}
