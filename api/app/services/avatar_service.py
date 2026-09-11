"""Validation and persistence for avatar-studio garment selections."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass

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

_TOP_SUBTYPES = {
    "shirt",
    "t_shirt",
    "tshirt",
    "polo",
    "kurta",
    "blouse",
    "sweater",
    "hoodie",
    "top",
}
_BOTTOM_SUBTYPES = {
    "trousers",
    "pants",
    "jeans",
    "chinos",
    "shorts",
    "skirt",
    "churidar",
    "dhoti",
    "palazzo",
}
_DRESS_SUBTYPES = {
    "sherwani",
    "saree",
    "lehenga",
    "anarkali",
    "gown",
    "jumpsuit",
    "dress",
}
_OUTER_SUBTYPES = {
    "jacket",
    "blazer",
    "coat",
    "nehru_jacket",
    "bandhgala",
    "overcoat",
}


def _norm(value: str | None) -> str:
    return (value or "").strip().lower().replace("-", "_").replace(" ", "_")


def _compatible(slot: str, item: dict) -> bool:
    category = _norm(item.get("category"))
    subtype = _norm(item.get("sub_category"))
    text = f"{category} {subtype}"
    # Hard category exclusions — never let a wrong primary category leak via subtype.
    if slot == "tops":
        if category in {"bottom", "bottoms", "footwear", "shoe", "shoes", "accessory"}:
            return False
        return (
            category in {"top", "tops"}
            or (category in {"", "unknown", "ethnic"} and subtype in _TOP_SUBTYPES)
            or (category == "ethnic" and subtype in _TOP_SUBTYPES)
        )
    if slot == "bottoms":
        if category in {"top", "tops", "footwear", "shoe", "shoes", "accessory"}:
            return False
        return (
            category in {"bottom", "bottoms"}
            or (category in {"", "unknown", "ethnic"} and subtype in _BOTTOM_SUBTYPES)
            or (category == "ethnic" and subtype in _BOTTOM_SUBTYPES)
        )
    if slot == "dresses":
        if category in {"bottom", "bottoms", "footwear", "shoe", "shoes"}:
            return False
        return (
            category in {"dress", "dresses"}
            or subtype in _DRESS_SUBTYPES
            or (category == "ethnic" and subtype in _DRESS_SUBTYPES)
        )
    if slot == "outerwear":
        if category in {"bottom", "bottoms", "footwear", "shoe", "shoes"}:
            return False
        return (
            category in {"outer", "outerwear"}
            or subtype in _OUTER_SUBTYPES
            or (category == "ethnic" and subtype in _OUTER_SUBTYPES)
        )
    if slot == "footwear":
        return category in {"shoe", "shoes", "footwear"} or (
            category not in {"top", "tops", "bottom", "bottoms", "dress", "outerwear"}
            and any(word in text for word in ("shoe", "oxford", "sneaker", "loafer", "boot"))
        )
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


def normalize_render_options(
    *,
    pose: str | None,
    style: str | None,
    quality: str | None,
) -> tuple[str, str, str]:
    pose_n = (pose or "natural").strip().lower() or "natural"
    style_n = (style or "studio").strip().lower() or "studio"
    quality_n = (quality or "hd").strip().lower() or "hd"
    return pose_n, style_n, quality_n


def look_fingerprint(
    slots: dict[str, str],
    *,
    pose: str | None,
    style: str | None,
    quality: str | None,
    try_on_photo_key: str,
) -> str:
    """Stable cache key for an avatar-studio look.

    Includes body photo key so swapping the avatar photo invalidates old previews.
    """
    pose_n, style_n, quality_n = normalize_render_options(
        pose=pose, style=style, quality=quality
    )
    slot_bits = [f"{slot}={slots[slot]}" for slot in SLOT_ORDER if slot in slots]
    return "|".join(
        [
            "v1",
            f"photo={try_on_photo_key}",
            f"pose={pose_n}",
            f"style={style_n}",
            f"quality={quality_n}",
            *slot_bits,
        ]
    )


def parse_fingerprint_meta(fingerprint: str | None) -> dict:
    """Extract slots / pose / style / quality from a look fingerprint."""
    out: dict = {
        "slots": {},
        "pose": "natural",
        "style": "studio",
        "quality": "hd",
    }
    if not fingerprint:
        return out
    for part in fingerprint.split("|"):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        if key in SLOT_ORDER:
            out["slots"][key] = value
        elif key == "pose":
            out["pose"] = value
        elif key == "style":
            out["style"] = value
        elif key == "quality":
            out["quality"] = value
    return out


def _render_directives(
    *,
    pose: str | None,
    style: str | None,
    quality: str | None,
) -> str:
    bits = [
        "Created in the avatar studio from user-selected wardrobe pieces.",
        "The person photo is identity and body only. Dress them in the selected "
        "wardrobe pieces. Do not keep a dress, sherwani, or one-piece from the "
        "person photo when a top or bottom is selected. Keep pants and shoes "
        "from the photo only when those slots were not selected.",
    ]
    pose_n, style_n, quality_n = normalize_render_options(
        pose=pose, style=style, quality=quality
    )
    bits.append(f"Render options: pose={pose_n}, style={style_n}, quality={quality_n}")

    if pose_n in {"standing", "walking", "three_quarter"}:
        pose_map = {
            "standing": "full-body standing pose, straight posture, facing camera",
            "walking": "natural mid-stride walking pose, fashion runway energy",
            "three_quarter": "three-quarter turned pose, elegant editorial stance",
        }
        bits.append(
            f"Adjust body pose to: {pose_map[pose_n]}. "
            "Keep the same face and identity."
        )
    else:
        bits.append("Keep the person's original pose from the source photo.")

    style_map = {
        "studio": (
            "Soft seamless studio backdrop, even fashion lighting, clean commercial look."
        ),
        "street": (
            "Urban street fashion setting, natural daylight, city atmosphere behind the subject."
        ),
        "festive": (
            "Warm festive celebration lighting, rich ambient glow, celebratory mood."
        ),
        "editorial": (
            "High-fashion editorial lighting, cinematic contrast, magazine cover quality."
        ),
    }
    bits.append(style_map.get(style_n, style_map["studio"]))

    if quality_n == "hd":
        bits.append(
            "Output ultra-sharp HD fashion photography: crisp fabric weave, "
            "clear button/embroidery detail, natural skin texture, no blur, "
            "no plastic skin, high dynamic range."
        )
    else:
        bits.append("Clean photorealistic fashion photo quality.")
    return " ".join(bits)


@dataclass
class AvatarOutfitResult:
    outfit_id: str
    created: bool
    has_preview: bool
    fingerprint: str


async def _validate_slots(
    conn: asyncpg.Connection,
    user_id: str,
    slots: dict[str, str],
) -> list[str]:
    """Validate owned items; return ordered item id list."""
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

    return [slots[slot] for slot in SLOT_ORDER if slot in slots]


async def create_avatar_outfit(
    conn: asyncpg.Connection,
    user_id: str,
    slots: dict[str, str],
    *,
    pose: str | None = None,
    style: str | None = None,
    quality: str | None = None,
    try_on_photo_key: str | None = None,
) -> str:
    """Validate and persist; reuse an existing studio outfit when fingerprint matches."""
    result = await find_or_create_avatar_outfit(
        conn,
        user_id,
        slots,
        pose=pose,
        style=style,
        quality=quality,
        try_on_photo_key=try_on_photo_key or "",
    )
    return result.outfit_id


async def delete_avatar_look(
    conn: asyncpg.Connection, user_id: str, outfit_id: str
) -> bool:
    """Hide a studio look from history. Keeps the outfit row."""
    result = await conn.execute(
        """
        UPDATE outfits
        SET preview_image_key = NULL
        WHERE id = $1::uuid
          AND user_id = $2
          AND occasion = 'avatar studio'
          AND preview_image_key IS NOT NULL
        """,
        outfit_id,
        user_id,
    )
    return result == "UPDATE 1"


async def find_or_create_avatar_outfit(
    conn: asyncpg.Connection,
    user_id: str,
    slots: dict[str, str],
    *,
    pose: str | None = None,
    style: str | None = None,
    quality: str | None = None,
    try_on_photo_key: str,
) -> AvatarOutfitResult:
    """Find a prior avatar-studio look or create a new outfit row."""
    ordered_ids = await _validate_slots(conn, user_id, slots)
    fingerprint = look_fingerprint(
        slots,
        pose=pose,
        style=style,
        quality=quality,
        try_on_photo_key=try_on_photo_key,
    )

    existing = await conn.fetchrow(
        """
        SELECT id, preview_image_key
        FROM outfits
        WHERE user_id = $1
          AND occasion = 'avatar studio'
          AND slot_fingerprint = $2
        ORDER BY created_at DESC
        LIMIT 1
        """,
        user_id,
        fingerprint,
    )
    if existing:
        return AvatarOutfitResult(
            outfit_id=str(existing["id"]),
            created=False,
            has_preview=bool(existing["preview_image_key"]),
            fingerprint=fingerprint,
        )

    outfit_id = str(uuid.uuid4())
    await conn.execute(
        """
        INSERT INTO outfits (
            id, user_id, item_ids, occasion, generated_by, llm_reason, slot_fingerprint
        ) VALUES ($1, $2, $3, 'avatar studio', 'manual', $4, $5)
        """,
        outfit_id,
        user_id,
        json.dumps(ordered_ids),
        _render_directives(pose=pose, style=style, quality=quality),
        fingerprint,
    )
    return AvatarOutfitResult(
        outfit_id=outfit_id,
        created=True,
        has_preview=False,
        fingerprint=fingerprint,
    )
