"""Natural-language outfit refinement.

The user sees an outfit and types something like "make it more formal" or
"swap the shirt for something darker". This service asks the chat model to
pick replacement items from the user's wardrobe and returns the updated
outfit.
"""

import json
import logging
from typing import Any

import asyncpg

from app.database.queries.items import get_items
from app.services.ai_provider import Role, chat
from app.services.storage import get_image_url

logger = logging.getLogger(__name__)


CHAT_PROMPT = """You are a personal stylist helping a user refine an outfit.

User profile:
- Name: {name}
- Style goals: {style_goals}
- Skin undertone: {skin_undertone}

Current outfit (item_id | type | color):
{current_outfit}

User says: "{message}"

Available wardrobe items (item_id | category | sub_category | color | formality 1-5):
{wardrobe}

Choose 0 or more swaps to apply. Keep items that already fit the user's request.

Return ONLY a JSON object in this exact shape:
{{
  "swaps": [
    {{ "old_id": "<item_id from current outfit>", "new_id": "<item_id from wardrobe>" }}
  ],
  "reason": "<1-2 sentence explanation tailored to the user>"
}}

Rules:
- Only use item_ids that appear in the lists above
- Don't swap items that already match the request
- Reasoning must be concise and emoji-free
- If no swap makes sense, return empty swaps with a brief reason
"""


def _strip_md(s: str) -> str:
    s = s.strip()
    if s.startswith("```"):
        s = s.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    return s


def _format_items(items: list[dict]) -> str:
    return "\n".join(
        f"  {it['id']} | {it.get('category','?')} | "
        f"{it.get('sub_category','?')} | "
        f"{it.get('primary_color','?')} | "
        f"formality={it.get('formality',3)}"
        for it in items
    )


async def refine_outfit(
    conn: asyncpg.Connection,
    user_id: str,
    outfit_items: list[dict],
    message: str,
    preferences: dict,
) -> dict[str, Any]:
    """Apply a natural-language refinement to an outfit.

    Returns dict with `items` (new outfit list, formatted with image URLs),
    `reason` (LLM-provided), and `swaps` (list of {old_id, new_id}).
    """
    # Hydrate wardrobe (cap to keep prompt manageable)
    wardrobe, _ = await get_items(conn, user_id, limit=80)

    # Exclude items already in outfit (so LLM only suggests *swap* candidates)
    current_ids = {str(it["id"]) for it in outfit_items}
    candidate_pool = [it for it in wardrobe if str(it["id"]) not in current_ids]

    prompt = CHAT_PROMPT.format(
        name=preferences.get("name") or "the user",
        style_goals=", ".join(preferences.get("style_goals", [])) or "open",
        skin_undertone=preferences.get("skin_undertone") or "unspecified",
        current_outfit=_format_items(outfit_items),
        wardrobe=_format_items(candidate_pool),
        message=message.strip()[:300],
    )

    result = await chat(Role.CHAT, prompt, max_tokens=400, temp=0.3)
    raw = _strip_md(result.text)

    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        logger.warning(f"chat refine: invalid JSON: {raw[:200]}")
        parsed = {"swaps": [], "reason": "I couldn't parse a clear swap — keeping it as is."}

    swaps = parsed.get("swaps", []) or []
    reason = parsed.get("reason") or ""

    # Apply swaps
    by_id = {str(it["id"]): it for it in outfit_items}
    wardrobe_by_id = {str(it["id"]): it for it in wardrobe}

    for s in swaps:
        old_id = str(s.get("old_id", ""))
        new_id = str(s.get("new_id", ""))
        if old_id in by_id and new_id in wardrobe_by_id and new_id not in by_id:
            by_id.pop(old_id)
            by_id[new_id] = wardrobe_by_id[new_id]

    new_items = list(by_id.values())

    # Format with public image URLs
    formatted = []
    for it in new_items:
        copy = dict(it)
        copy["image_url"] = get_image_url(copy.get("image_url", ""))
        formatted.append(copy)

    return {
        "items": formatted,
        "reason": reason,
        "swaps": swaps,
        "model": result.model,
        "provider": result.provider,
    }
