"""Format user feedback history into LLM-ready personalization context."""

import json
import logging

import asyncpg

logger = logging.getLogger(__name__)


async def get_recent_feedback(
    conn: asyncpg.Connection, user_id: str, limit: int = 30
) -> list[dict]:
    """Pull recent outfit_feedback joined with the outfit items + occasion.

    Returns a list of dicts like:
      {action: "like", occasion: "work", items: [{sub_category, primary_color}, ...]}
    """
    rows = await conn.fetch(
        """
        SELECT f.action, o.occasion, o.item_ids, o.created_at
        FROM outfit_feedback f
        JOIN outfits o ON o.id = f.outfit_id
        WHERE f.user_id = $1
        ORDER BY f.created_at DESC
        LIMIT $2
        """,
        user_id, limit,
    )

    if not rows:
        return []

    # Collect all item ids to hydrate in one query
    all_item_ids = set()
    parsed_rows = []
    for r in rows:
        try:
            ids = json.loads(r["item_ids"]) if isinstance(r["item_ids"], str) else r["item_ids"]
        except (TypeError, json.JSONDecodeError):
            ids = []
        all_item_ids.update(ids)
        parsed_rows.append({
            "action": r["action"],
            "occasion": r["occasion"],
            "item_ids": ids,
        })

    if not all_item_ids:
        return parsed_rows

    items_rows = await conn.fetch(
        """
        SELECT id, sub_category, primary_color, category
        FROM items
        WHERE id = ANY($1::uuid[])
        """,
        list(all_item_ids),
    )
    items_map = {
        str(it["id"]): {
            "sub_category": it["sub_category"] or it["category"],
            "primary_color": it["primary_color"],
        }
        for it in items_rows
    }

    out = []
    for r in parsed_rows:
        out.append({
            "action": r["action"],
            "occasion": r["occasion"],
            "items": [items_map.get(str(i), {"sub_category": "?", "primary_color": "?"})
                      for i in r["item_ids"]],
        })
    return out


def format_feedback_for_prompt(feedback: list[dict]) -> str:
    """Format feedback list into a section the ranker can read in-context."""
    if not feedback:
        return ""

    liked = [f for f in feedback if f["action"] in ("like", "save", "wear")]
    disliked = [f for f in feedback if f["action"] in ("dislike", "skip")]

    def _fmt_combo(f: dict) -> str:
        items_desc = ", ".join(
            f"{it['sub_category']} ({it['primary_color']})"
            for it in f["items"][:4]
        )
        return f"  - [{f['occasion']}] {items_desc}"

    sections = []
    if liked:
        sections.append("Past outfits the user LOVED (prioritize patterns like these):")
        sections.extend(_fmt_combo(f) for f in liked[:10])
    if disliked:
        sections.append("\nPast outfits the user PASSED on (avoid patterns like these):")
        sections.extend(_fmt_combo(f) for f in disliked[:10])

    return "\n".join(sections)
