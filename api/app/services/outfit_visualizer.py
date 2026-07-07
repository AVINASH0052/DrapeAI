"""Outfit visualization: composite user photo + wardrobe items into a preview image."""

from __future__ import annotations

import io
import json
import logging
from dataclasses import dataclass

from PIL import Image, ImageDraw, ImageFilter, ImageFont

from app.services.storage import read_image_bytes, upload_outfit_preview

logger = logging.getLogger(__name__)

CANVAS_W = 720
CANVAS_H = 1080

# Category → vertical anchor (fraction of canvas height) for clothing overlays
_CATEGORY_Y = {
    "top": 0.28,
    "outerwear": 0.24,
    "ethnic_top": 0.26,
    "kurta": 0.26,
    "saree_blouse": 0.26,
    "bottom": 0.52,
    "ethnic_bottom": 0.50,
    "skirt": 0.48,
    "dress": 0.38,
    "saree": 0.35,
    "lehenga": 0.42,
    "shoes": 0.78,
    "accessory": 0.14,
    "bag": 0.40,
}


@dataclass
class VisualizeResult:
    preview_key: str
    method: str  # "composite" | "ai"


def _load_rgba(data: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(data)).convert("RGBA")
    return img


def _fit_cover(img: Image.Image, w: int, h: int) -> Image.Image:
    """Resize and center-crop to fill w×h."""
    ratio = max(w / img.width, h / img.height)
    resized = img.resize(
        (int(img.width * ratio), int(img.height * ratio)), Image.LANCZOS
    )
    left = (resized.width - w) // 2
    top = (resized.height - h) // 2
    return resized.crop((left, top, left + w, top + h))


def _overlay_item(
    canvas: Image.Image,
    item_img: Image.Image,
    category: str,
    index: int,
) -> None:
    """Place a clothing item on the canvas near the appropriate body region."""
    base_y = _CATEGORY_Y.get(category, 0.35 + index * 0.08)
    target_w = int(CANVAS_W * 0.42)
    target_h = int(CANVAS_H * 0.22)

    item = _fit_cover(item_img, target_w, target_h)

    # Soft shadow behind item
    shadow = Image.new("RGBA", item.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (8, item.height - 18, item.width - 8, item.height + 6),
        fill=(0, 0, 0, 60),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))

    x = (CANVAS_W - item.width) // 2 + (index % 2) * 24 - 12
    y = int(CANVAS_H * base_y)

    canvas.alpha_composite(shadow, (x, y))
    canvas.alpha_composite(item, (x, y))


async def _load_item_images(items: list[dict]) -> list[tuple[Image.Image, str]]:
    loaded: list[tuple[Image.Image, str]] = []
    for item in items:
        key = item.get("image_url") or ""
        if not key or key.startswith("http"):
            continue
        try:
            data = await read_image_bytes(key)
            loaded.append((_load_rgba(data), item.get("category", "top")))
        except Exception as e:
            logger.warning(f"skip item image {key}: {e}")
    return loaded


async def build_composite_preview(
    person_bytes: bytes,
    items: list[dict],
) -> bytes:
    """Async composite builder."""
    person = _load_rgba(person_bytes)
    person_layer = _fit_cover(person, CANVAS_W, int(CANVAS_H * 0.72))

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (252, 248, 244, 255))
    draw = ImageDraw.Draw(canvas)

    person_y = 60
    canvas.paste(person_layer, (0, person_y), person_layer)
    dim = Image.new("RGBA", person_layer.size, (255, 255, 255, 40))
    canvas.paste(dim, (0, person_y), dim)

    item_images = await _load_item_images(items)
    for i, (img, category) in enumerate(item_images):
        _overlay_item(canvas, img, category, i)

    # Bottom info strip
    strip_h = 120
    strip = Image.new("RGBA", (CANVAS_W, strip_h), (30, 20, 35, 220))
    canvas.paste(strip, (0, CANVAS_H - strip_h), strip)

    labels = [it.get("category", "piece").replace("_", " ") for it in items[:4]]
    label_text = " · ".join(labels) if labels else "your outfit"
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
        small = font

    draw = ImageDraw.Draw(canvas)
    draw.text((24, CANVAS_H - strip_h + 20), "See me in this fit", fill=(255, 200, 120, 255), font=font)
    draw.text((24, CANVAS_H - strip_h + 52), label_text, fill=(220, 215, 230, 255), font=small)
    draw.text((24, CANVAS_H - strip_h + 78), "from your wardrobe", fill=(160, 150, 170, 255), font=small)

    # Vignette
    vignette = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    vdraw = ImageDraw.Draw(vignette)
    vdraw.rectangle([0, 0, CANVAS_W, CANVAS_H], outline=(20, 10, 30, 50), width=3)
    canvas = Image.alpha_composite(canvas, vignette)

    out = io.BytesIO()
    canvas.convert("RGB").save(out, format="PNG", optimize=True)
    return out.getvalue()


async def visualize_outfit(
    user_id: str,
    outfit_id: str,
    try_on_photo_key: str,
    items: list[dict],
) -> VisualizeResult:
    """Generate and store outfit preview image."""
    person_bytes = await read_image_bytes(try_on_photo_key)
    preview_bytes = await build_composite_preview(person_bytes, items)
    preview_key = await upload_outfit_preview(user_id, outfit_id, preview_bytes)
    return VisualizeResult(preview_key=preview_key, method="composite")


async def get_outfit_items_from_db(conn, outfit_id: str, user_id: str) -> list[dict]:
    """Load item records for an outfit."""
    from app.database.queries.items import get_item

    row = await conn.fetchrow(
        "SELECT item_ids FROM outfits WHERE id = $1 AND user_id = $2",
        outfit_id,
        user_id,
    )
    if not row:
        return []

    try:
        item_ids = json.loads(row["item_ids"])
    except (TypeError, json.JSONDecodeError):
        item_ids = []

    items = []
    for iid in item_ids:
        it = await get_item(conn, iid, user_id)
        if it:
            items.append(it)
    return items
