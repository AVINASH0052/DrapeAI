"""Wardrobe gap analysis — what should the user buy next?

Aggregates wardrobe by category × formality × season × color group, compares to
the expected distribution given their occasions + lifestyle + climate, and asks
the heavy-reasoning model (Claude Sonnet by default) for prioritized
recommendations.

Results cached for 7 days per user via a simple analytics_daily metric key.
"""

import json
import logging
from collections import Counter

import asyncpg

from app.services.ai_provider import Role, chat
from app.utils.llm_json import strip_markdown_fence

logger = logging.getLogger(__name__)


def _summarize_wardrobe(items: list[dict]) -> dict:
    cat_count: Counter = Counter()
    sub_count: Counter = Counter()
    color_count: Counter = Counter()
    formality_count: Counter = Counter()
    season_count: Counter = Counter()
    total = 0

    for it in items:
        if not it.get("is_active", True):
            continue
        total += 1
        cat_count[it.get("category") or "unknown"] += 1
        sub = it.get("sub_category") or "unknown"
        sub_count[sub] += 1
        color_count[(it.get("primary_color") or "unknown").lower()] += 1
        formality_count[it.get("formality") or 3] += 1
        try:
            seasons = json.loads(it.get("season_tags") or "[]")
        except (TypeError, json.JSONDecodeError):
            seasons = []
        for s in seasons:
            season_count[s] += 1

    return {
        "total_items": total,
        "categories": dict(cat_count),
        "sub_categories_top": dict(sub_count.most_common(8)),
        "colors": dict(color_count.most_common(6)),
        "formality_distribution": dict(formality_count),
        "seasons": dict(season_count),
    }


GAPS_PROMPT = """You are a wardrobe consultant for an Indian user.

User profile:
- Name: {name}
- Age: {age}
- Gender: {gender}
- Body type: {body_type}
- Skin undertone: {skin_undertone}
- Style goals: {style_goals}
- Occasions they dress for: {occasions}
- Lifestyle: {lifestyle}
- Budget tier: {budget_tier}
- Location: {location_city} ({climate} climate)

Current wardrobe summary:
{wardrobe_summary}

Identify the 5 highest-impact items this user should add next. Consider:
- Category coverage gaps (e.g., not enough bottoms vs. tops)
- Color balance with their preferences and skin undertone
- Formality coverage for their occasions and lifestyle
- Season suitability for their climate
- Indian fashion context (ethnic essentials if missing)

Return ONLY a JSON array of exactly 5 objects:
[
  {{
    "item": "<concise item name, e.g. 'Navy linen blazer'>",
    "category": "<top|bottom|outerwear|footwear|accessory|ethnic|dress>",
    "reason": "<1-2 sentence why this fills a gap, tailored to the user>",
    "priority": <1-5, 1 = most impactful>,
    "est_price_range_inr": "<e.g. '₹2000-4000'>"
  }}
]
"""


async def analyze_wardrobe_gaps(
    conn: asyncpg.Connection,
    user_id: str,
    items: list[dict],
    preferences: dict,
) -> list[dict]:
    summary = _summarize_wardrobe(items)

    prompt = GAPS_PROMPT.format(
        name=preferences.get("name") or "the user",
        age=preferences.get("age") or "unknown",
        gender=preferences.get("gender") or "unknown",
        body_type=preferences.get("body_type") or "unspecified",
        skin_undertone=preferences.get("skin_undertone") or "unspecified",
        style_goals=", ".join(preferences.get("style_goals", [])) or "open",
        occasions=", ".join(preferences.get("occasions", [])) or "casual",
        lifestyle=", ".join(preferences.get("lifestyle", [])) or "unspecified",
        budget_tier=preferences.get("budget_tier") or "mid",
        location_city=preferences.get("location_city") or "unknown",
        climate=preferences.get("climate") or "temperate",
        wardrobe_summary=json.dumps(summary, indent=2),
    )

    result = await chat(Role.REASON, prompt, max_tokens=900, temp=0.4)
    raw = strip_markdown_fence(result.text)

    try:
        gaps = json.loads(raw)
        if not isinstance(gaps, list):
            raise ValueError("expected JSON array")
    except (json.JSONDecodeError, ValueError) as e:
        logger.warning(f"gap analysis: parse error {e}; raw={raw[:300]}")
        gaps = []

    # Coerce shape, clamp to 5
    cleaned = []
    for g in gaps[:5]:
        if not isinstance(g, dict):
            continue
        cleaned.append({
            "item": str(g.get("item") or "Wardrobe addition"),
            "category": str(g.get("category") or "top"),
            "reason": str(g.get("reason") or ""),
            "priority": int(g.get("priority") or 3),
            "est_price_range_inr": str(g.get("est_price_range_inr") or ""),
        })
    return cleaned
