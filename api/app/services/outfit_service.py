"""Outfit generation orchestrator: cache -> weather -> rule engine -> LLM ranker."""

import logging
import random

from fastapi import HTTPException

from app.database.pool import get_pool
from app.database.queries.items import get_items
from app.database.queries.preferences import get_preferences
from app.database.queries.outfits import save_outfit
from app.database.queries.outfit_cache import get_cached_outfits, set_cached_outfits
from app.services.rule_engine import generate_candidates
from app.services.llm_ranker import rank_outfits
from app.services.personalization import get_recent_feedback
from app.services.weather import get_weather
from app.services.storage import get_image_url
from app.utils.cost_tracker import check_budget

logger = logging.getLogger(__name__)


async def generate_outfits(
    user_id: str, occasion: str, weather_override: dict | None = None
) -> dict:
    """Full outfit generation pipeline.

    1. Check cache
    2. Fetch weather (if no override)
    3. Run rule engine (deterministic, <100ms)
    4. Run LLM ranker (~3s)
    5. Save outfits to DB
    6. Cache result
    """
    pool = await get_pool()

    # 1. Check cache
    async with pool.acquire() as conn:
        cached = await get_cached_outfits(conn, user_id, occasion)
    if cached:
        logger.info(f"Cache hit for user={user_id}, occasion={occasion}")
        return {"outfits": cached, "cached": True}

    # 2. Fetch preferences + items + recent feedback (for personalization)
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user_id)
        items, _ = await get_items(conn, user_id, limit=200)
        feedback = await get_recent_feedback(conn, user_id, limit=30)

    if not prefs:
        raise HTTPException(status_code=400, detail="Complete onboarding first")

    if len(items) < 3:
        raise HTTPException(
            status_code=400, detail="Add at least 3 items to generate outfits"
        )

    # 3. Get weather
    weather = weather_override
    if not weather:
        weather = await get_weather(prefs.get("location_city", "delhi"))

    # 4. Rule engine
    candidates = generate_candidates(items, occasion, weather)
    if not candidates:
        return {"outfits": [], "cached": False}

    # 5. Check budget before LLM call
    await check_budget("openai")
    await check_budget("anthropic")

    # 6. LLM ranker (personalized with feedback)
    ranked = await rank_outfits(candidates, prefs, occasion, weather, feedback=feedback)

    # 6. Save to DB and format response
    outfits = []
    async with pool.acquire() as conn:
        for outfit_data in ranked:
            outfit_data["occasion"] = occasion
            outfit_data["weather"] = weather
            saved = await save_outfit(conn, user_id, outfit_data)

            formatted_items = []
            for item in outfit_data["items"]:
                item_copy = dict(item)
                item_copy["image_url"] = get_image_url(item_copy.get("image_url", ""))
                formatted_items.append(item_copy)

            outfits.append(
                {
                    "id": saved["id"],
                    "items": formatted_items,
                    "reason": outfit_data.get("reason"),
                    "rule_score": outfit_data.get("rule_score"),
                    "occasion": occasion,
                    "weather": weather,
                }
            )

        await set_cached_outfits(conn, user_id, occasion, outfits)

    return {"outfits": outfits, "cached": False}


async def shuffle_outfit(user_id: str, occasion: str) -> dict:
    """Generate a single random outfit. Uses rule engine + randomness, no LLM."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user_id)
        items, _ = await get_items(conn, user_id, limit=200)

    if not prefs or len(items) < 3:
        raise HTTPException(
            status_code=400, detail="Need preferences and at least 3 items"
        )

    weather = await get_weather(prefs.get("location_city", "delhi"))
    candidates = generate_candidates(items, occasion, weather, max_candidates=10)

    if not candidates:
        return {"outfit": None}

    weights = [c["score"] for c in candidates]
    chosen = random.choices(candidates, weights=weights, k=1)[0]

    async with pool.acquire() as conn:
        chosen["occasion"] = occasion
        chosen["weather"] = weather
        saved = await save_outfit(conn, user_id, chosen)

    formatted_items = []
    for item in chosen["items"]:
        item_copy = dict(item)
        item_copy["image_url"] = get_image_url(item_copy.get("image_url", ""))
        formatted_items.append(item_copy)

    return {
        "outfit": {
            "id": saved["id"],
            "items": formatted_items,
            "reason": None,
            "rule_score": chosen["score"],
            "occasion": occasion,
        }
    }
