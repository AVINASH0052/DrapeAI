"""Image preparation helpers for virtual try-on inference."""

from __future__ import annotations

import io
import logging
from typing import Optional

from PIL import Image

logger = logging.getLogger(__name__)

# Prefer these categories first when selecting garment refs (person + up to 3 garments).
_CATEGORY_PRIORITY = {
    "top": 0,
    "ethnic_top": 0,
    "kurta": 0,
    "saree_blouse": 0,
    "dress": 0,
    "saree": 0,
    "lehenga": 0,
    "bottom": 1,
    "ethnic_bottom": 1,
    "skirt": 1,
    "shoes": 2,
    "outerwear": 3,
    "accessory": 4,
    "bag": 4,
}


def sort_items_for_tryon(items: list[dict]) -> list[dict]:
    """Order wardrobe items: top → bottom → footwear → outerwear."""
    return sorted(
        items,
        key=lambda it: (
            _CATEGORY_PRIORITY.get((it.get("category") or "").lower(), 50),
            it.get("category") or "",
        ),
    )


# Default prep sizes for model inference (HD). Cloudflare stays at 512 (platform cap).
HD_PERSON_MAX_EDGE = 2048
HD_GARMENT_MAX_EDGE = 1536
HD_JPEG_QUALITY = 92


def resize_max_edge(
    image_bytes: bytes,
    max_edge: int = HD_PERSON_MAX_EDGE,
    quality: int = HD_JPEG_QUALITY,
) -> bytes:
    """Resize so the longest edge is <= max_edge. Returns JPEG or PNG bytes."""
    img = Image.open(io.BytesIO(image_bytes))
    has_alpha = img.mode in ("RGBA", "LA") or (
        img.mode == "P" and "transparency" in img.info
    )
    img = img.convert("RGBA" if has_alpha else "RGB")

    w, h = img.size
    longest = max(w, h)
    if longest > max_edge:
        # Anchor the long edge exactly at max_edge (avoid float truncating to max_edge-1).
        if w >= h:
            new_w = max_edge
            new_h = max(1, round(h * max_edge / w))
        else:
            new_h = max_edge
            new_w = max(1, round(w * max_edge / h))
        img = img.resize((new_w, new_h), Image.LANCZOS)

    buf = io.BytesIO()
    if has_alpha:
        img.save(buf, format="PNG", optimize=True)
    else:
        img.save(buf, format="JPEG", quality=quality, optimize=True)
    return buf.getvalue()


def resize_for_cloudflare(image_bytes: bytes, max_edge: int = 512) -> bytes:
    """Cloudflare FLUX Klein requires input images smaller than 512×512."""
    return resize_max_edge(image_bytes, max_edge=max_edge, quality=HD_JPEG_QUALITY)


def prep_person_bytes(
    person_bytes: bytes,
    *,
    for_cloudflare: bool = False,
    max_edge: int = HD_PERSON_MAX_EDGE,
) -> bytes:
    if for_cloudflare:
        return resize_for_cloudflare(person_bytes)
    return resize_max_edge(person_bytes, max_edge=max_edge)


def prep_item_bytes_list(
    item_bytes: list[bytes],
    *,
    for_cloudflare: bool = False,
    limit: int = 4,
    max_edge: int = HD_GARMENT_MAX_EDGE,
) -> list[bytes]:
    prepared: list[bytes] = []
    for raw in item_bytes[:limit]:
        try:
            prepared.append(
                resize_for_cloudflare(raw)
                if for_cloudflare
                else resize_max_edge(raw, max_edge=max_edge)
            )
        except Exception as e:
            logger.warning(f"tryon prep: skip garment bytes: {e}")
    return prepared


def load_prompt_template(version: str = "wardrobe_v1") -> Optional[str]:
    """Load a versioned prompt from api/prompts/. Returns None if missing."""
    from pathlib import Path

    name = {
        "wardrobe_v1": "wardrobe_tryon_v1.txt",
        "external_v1": "external_tryon_v1.txt",
    }.get(version, f"{version}.txt")

    # api/prompts relative to this file: api/app/services → api/prompts
    prompts_dir = Path(__file__).resolve().parents[2] / "prompts"
    path = prompts_dir / name
    if not path.is_file():
        return None
    return path.read_text(encoding="utf-8")
