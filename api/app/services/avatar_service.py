"""Validation and persistence for avatar-studio garment selections."""

import json
import uuid

import asyncpg
from fastapi import HTTPException

SLOT_ORDER = (
    "tops",
    "bottoms",
    "dresses",
    "outerwear",
    "footwear",
    "accessories",
    "caps",
    "glasses",
)


def _norm(value: str | None) -> str:
    return (value or "").strip().lower().replace("-", "_").replace(" ", "_")


def _compatible(slot: str, item: dict) -> bool:
    category = _norm(item.get("category"))
    subtype = _norm(item.get("sub_category"))
    text = f"{category} {subtype}"
    if slot == "tops":
        return category in {"top", "tops"}
    if slot == "bottoms":
        return category in {"bottom", "bottoms"}
    if slot == "dresses":
        return category in {"dress", "dresses"}
    if slot == "outerwear":
        return category in {"outer", "outerwear"}
    if slot == "footwear":
        return category in {"shoe", "shoes", "footwear"}
    if slot == "caps":
        return any(word in text for word in ("cap", "hat", "beanie"))
    if slot == "glasses":
        return any(word in text for word in ("glass", "sunglass", "eyewear"))
    if slot == "accessories":
        return category in {
            "accessory",
            "accessories",
            "bag",
            "jewelry",
            "jewellery",
        } and not _compatible("caps", item) and not _compatible("glasses", item)
    return False


async def create_avatar_outfit(
    conn: asyncpg.Connection,
    user_id: str,
    slots: dict[str, str],
) -> str:
    """Validate selected owned items and persist a manual outfit."""
    if not slots:
        raise HTTPException(status_code=400, detail="Select at least one wardrobe item.")
    unknown = set(slots) - set(SLOT_ORDER)
    if unknown:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported avatar slot: {sorted(unknown)[0]}",
        )
    if "dresses" in slots and ({"tops", "bottoms"} & set(slots)):
        raise HTTPException(
            status_code=400,
            detail="A dress cannot be combined with a top or bottom.",
        )

    try:
        item_ids = [uuid.UUID(value) for value in slots.values()]
    except (ValueError, TypeError) as exc:
        raise HTTPException(status_code=400, detail="Invalid wardrobe item ID.") from exc
    if len(set(item_ids)) != len(item_ids):
        raise HTTPException(
            status_code=400,
            detail="The same wardrobe item cannot fill more than one slot.",
        )

    rows = await conn.fetch(
        """
        SELECT id, category, sub_category, processing_status
        FROM items
        WHERE user_id = $1
          AND is_active = TRUE
          AND id = ANY($2::uuid[])
        """,
        user_id,
        item_ids,
    )
    by_id = {str(row["id"]): dict(row) for row in rows}
    if len(by_id) != len(item_ids):
        raise HTTPException(
            status_code=404,
            detail="One or more wardrobe items were not found.",
        )

    for slot, item_id in slots.items():
        item = by_id[item_id]
        if item["processing_status"] != "ready":
            raise HTTPException(
                status_code=409,
                detail=f"The item selected for {slot} is still being prepared.",
            )
        if not _compatible(slot, item):
            raise HTTPException(
                status_code=400,
                detail=f"That item is not compatible with the {slot} slot.",
            )

    outfit_id = str(uuid.uuid4())
    ordered_ids = [slots[slot] for slot in SLOT_ORDER if slot in slots]
    await conn.execute(
        """
        INSERT INTO outfits (
            id, user_id, item_ids, occasion, generated_by, llm_reason
        ) VALUES ($1, $2, $3, 'avatar studio', 'manual', $4)
        """,
        outfit_id,
        user_id,
        json.dumps(ordered_ids),
        "Created in the avatar studio from user-selected wardrobe pieces.",
    )
    return outfit_id
