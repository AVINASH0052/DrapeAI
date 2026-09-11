"""Smart item pairing.

Given a wardrobe item, return the top N items from the same user's wardrobe
that pair well with it. Combines:
1. Embedding similarity (pgvector cosine distance)
2. Rule-engine compatibility (color harmony, formality match)
3. Past pairing success from outfit_feedback (saved combos boost)
"""

import json
import logging

import asyncpg

from app.services.rule_engine import GOOD_COLOR_PAIRS, CLASHING_PAIRS
from app.services.storage import get_image_url

logger = logging.getLogger(__name__)

# Categories that "pair" with another category
PAIRING_TARGET = {
    "top":       ["bottom", "outerwear", "footwear", "accessory"],
    "bottom":    ["top", "outerwear", "footwear", "accessory"],
    "dress":     ["outerwear", "footwear", "accessory"],
    "outerwear": ["top", "bottom", "dress"],
    "footwear":  ["top", "bottom", "dress"],
    "accessory": ["top", "bottom", "dress"],
    "ethnic":    ["bottom", "footwear", "accessory", "outerwear"],
}


def _color_compat(c1: str, c2: str) -> float:
    c1 = (c1 or "").lower()
    c2 = (c2 or "").lower()
    if (c1, c2) in GOOD_COLOR_PAIRS or (c2, c1) in GOOD_COLOR_PAIRS:
        return 1.0
    if (c1, c2) in CLASHING_PAIRS or (c2, c1) in CLASHING_PAIRS:
        return -0.5
    return 0.4  # neutral


def _formality_compat(f1: int, f2: int) -> float:
    diff = abs((f1 or 3) - (f2 or 3))
    return max(0.0, 1.0 - diff * 0.25)


async def get_pairings(
    conn: asyncpg.Connection, item_id: str, user_id: str, limit: int = 5,
) -> list[dict]:
    """Return top-N wardrobe items that pair with the given item."""
    base = await conn.fetchrow(
        "SELECT * FROM items WHERE id = $1 AND user_id = $2 AND is_active = TRUE",
        item_id, user_id,
    )
    if not base:
        return []

    target_cats = PAIRING_TARGET.get(base["category"], [])
    if not target_cats:
        return []

    # Embedding similarity (pgvector). embedding may be NULL for older items.
    has_embedding = base.get("embedding") is not None
    if has_embedding:
        rows = await conn.fetch(
            """
            SELECT *, 1 - (embedding <=> $1) AS similarity
            FROM items
            WHERE user_id = $2
              AND id != $3
              AND is_active = TRUE
              AND category = ANY($4::text[])
              AND embedding IS NOT NULL
            ORDER BY embedding <=> $1
            LIMIT 30
            """,
            base["embedding"], user_id, item_id, target_cats,
        )
    else:
        rows = await conn.fetch(
            """
            SELECT *, 0.5 AS similarity
            FROM items
            WHERE user_id = $1
              AND id != $2
              AND is_active = TRUE
              AND category = ANY($3::text[])
            LIMIT 30
            """,
            user_id, item_id, target_cats,
        )

    # Get user's saved outfits that include the base item — items co-occurring there get a bonus
    saved = await conn.fetch(
        """
        SELECT item_ids FROM outfits
        WHERE user_id = $1 AND is_saved = TRUE
        """,
        user_id,
    )
    co_count: dict[str, int] = {}
    for s in saved:
        try:
            ids = json.loads(s["item_ids"])
        except (TypeError, json.JSONDecodeError):
            ids = []
        if item_id in [str(i) for i in ids]:
            for other in ids:
                k = str(other)
                if k != item_id:
                    co_count[k] = co_count.get(k, 0) + 1

    # Score each candidate
    base_color = (base.get("primary_color") or "").lower()
    base_formality = base.get("formality") or 3

    scored = []
    for r in rows:
        sim = float(r.get("similarity") or 0)
        color = _color_compat(base_color, r.get("primary_color") or "")
        formality = _formality_compat(base_formality, r.get("formality") or 3)
        co = co_count.get(str(r["id"]), 0)
        co_boost = min(0.3, co * 0.1)

        # Weighted: embeddings 40%, rules 40%, history 20%
        score = (0.4 * sim) + (0.4 * (color * 0.5 + formality * 0.5)) + (0.2 * co_boost)

        reason_bits = []
        if color > 0.6:
            reason_bits.append("colors harmonize")
        if formality > 0.7:
            reason_bits.append("formality matches")
        if co_boost > 0:
            reason_bits.append("you've saved this combo before")
        if sim > 0.7 and not reason_bits:
            reason_bits.append("similar style")
        reason = ", ".join(reason_bits) or "complements the base item"

        scored.append({
            "id": str(r["id"]),
            "image_url": get_image_url(r["image_url"]),
            "category": r["category"],
            "sub_category": r["sub_category"],
            "primary_color": r["primary_color"],
            "formality": r["formality"],
            "match_score": round(score * 100, 1),
            "reason": reason,
        })

    scored.sort(key=lambda x: x["match_score"], reverse=True)
    return scored[:limit]
