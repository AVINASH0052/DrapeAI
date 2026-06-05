"""User analytics API — personal wardrobe insights and usage patterns.

Endpoints:
  GET /analytics/overview     — Summary metrics (items, outfits, utilization)
  GET /analytics/wear-history — Wear patterns over time
  GET /analytics/category-breakdown — Items and cost-per-wear by category
"""

import json
from datetime import date, timedelta

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool

router = APIRouter(prefix="/analytics", tags=["analytics"])


class OverviewStats(BaseModel):
    total_items: int
    active_items: int
    total_outfits_generated: int
    outfits_saved: int
    outfits_worn: int
    wardrobe_utilization_pct: float  # % of items worn at least once
    avg_wear_count: float
    total_wardrobe_value: int  # paise
    most_worn_category: str | None
    least_worn_category: str | None
    style_diversity_score: float  # 0-100, based on category spread


class WearHistoryEntry(BaseModel):
    date: str
    outfits_worn: int


class CategoryBreakdown(BaseModel):
    category: str
    item_count: int
    total_wears: int
    total_value: int  # paise
    avg_cost_per_wear: float  # paise per wear


@router.get("/overview", response_model=OverviewStats)
async def get_analytics_overview(user: dict = Depends(get_current_user)):
    """Get comprehensive wardrobe analytics overview."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Core item stats
        item_stats = await conn.fetchrow(
            """
            SELECT
                COUNT(*) AS total_items,
                COUNT(*) FILTER (WHERE is_active) AS active_items,
                COUNT(*) FILTER (WHERE wear_count > 0 AND is_active) AS worn_items,
                COALESCE(AVG(wear_count) FILTER (WHERE is_active), 0) AS avg_wear_count,
                COALESCE(SUM(purchase_price) FILTER (WHERE is_active), 0) AS total_value
            FROM items WHERE user_id = $1
            """,
            user["uid"],
        )

        # Outfit stats
        outfit_stats = await conn.fetchrow(
            """
            SELECT
                COUNT(*) AS total_outfits,
                COUNT(*) FILTER (WHERE is_saved) AS saved,
                COUNT(*) FILTER (WHERE is_worn) AS worn
            FROM outfits WHERE user_id = $1
            """,
            user["uid"],
        )

        # Category distribution for diversity + most/least worn
        categories = await conn.fetch(
            """
            SELECT category, COUNT(*) AS cnt, SUM(wear_count) AS total_wears
            FROM items WHERE user_id = $1 AND is_active = TRUE
            GROUP BY category ORDER BY total_wears DESC
            """,
            user["uid"],
        )

    total = item_stats["total_items"] or 0
    active = item_stats["active_items"] or 0
    worn = item_stats["worn_items"] or 0
    utilization = (worn / active * 100) if active > 0 else 0

    # Style diversity: Shannon entropy normalized to 0-100
    # More evenly distributed categories = higher score
    diversity = 0.0
    if categories:
        import math
        total_items = sum(r["cnt"] for r in categories)
        if total_items > 0:
            entropy = 0
            for r in categories:
                p = r["cnt"] / total_items
                if p > 0:
                    entropy -= p * math.log2(p)
            max_entropy = math.log2(len(categories)) if len(categories) > 1 else 1
            diversity = (entropy / max_entropy * 100) if max_entropy > 0 else 0

    most_worn = categories[0]["category"] if categories else None
    least_worn = categories[-1]["category"] if categories and len(categories) > 1 else None

    return OverviewStats(
        total_items=total,
        active_items=active,
        total_outfits_generated=outfit_stats["total_outfits"] or 0,
        outfits_saved=outfit_stats["saved"] or 0,
        outfits_worn=outfit_stats["worn"] or 0,
        wardrobe_utilization_pct=round(utilization, 1),
        avg_wear_count=round(float(item_stats["avg_wear_count"]), 1),
        total_wardrobe_value=int(item_stats["total_value"]),
        most_worn_category=most_worn,
        least_worn_category=least_worn,
        style_diversity_score=round(diversity, 1),
    )


@router.get("/wear-history", response_model=list[WearHistoryEntry])
async def get_wear_history(
    days: int = Query(30, ge=7, le=365),
    user: dict = Depends(get_current_user),
):
    """Get daily wear history for the past N days."""
    pool = await get_pool()
    start_date = date.today() - timedelta(days=days)

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT worn_date::text AS date, COUNT(*) AS outfits_worn
            FROM outfits
            WHERE user_id = $1
              AND worn_date >= $2
              AND worn_date IS NOT NULL
            GROUP BY worn_date
            ORDER BY worn_date
            """,
            user["uid"],
            start_date,
        )

    return [WearHistoryEntry(date=r["date"], outfits_worn=r["outfits_worn"]) for r in rows]


@router.get("/category-breakdown", response_model=list[CategoryBreakdown])
async def get_category_breakdown(user: dict = Depends(get_current_user)):
    """Get per-category item count, wear count, value, and cost-per-wear."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT
                category,
                COUNT(*) AS item_count,
                COALESCE(SUM(wear_count), 0) AS total_wears,
                COALESCE(SUM(purchase_price), 0) AS total_value
            FROM items
            WHERE user_id = $1 AND is_active = TRUE
            GROUP BY category
            ORDER BY total_wears DESC
            """,
            user["uid"],
        )

    return [
        CategoryBreakdown(
            category=r["category"],
            item_count=r["item_count"],
            total_wears=r["total_wears"],
            total_value=r["total_value"],
            avg_cost_per_wear=(
                r["total_value"] / r["total_wears"]
                if r["total_wears"] > 0
                else 0
            ),
        )
        for r in rows
    ]
