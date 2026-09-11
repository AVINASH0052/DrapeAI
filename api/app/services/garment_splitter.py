"""Gemini wardrobe intake: detect every garment, isolate a faithful product shot.

Detect uses Gemini vision JSON (with optional crop boxes). Isolation uses
Gemini image generation with copy-exact prompts — no catalog restyle.
If image gen is blocked, crop + rembg so the real pixels still land in
the wardrobe.
"""

from __future__ import annotations

import base64
import json
import logging
from dataclasses import dataclass
from io import BytesIO

import httpx
from PIL import Image

from app.config import settings
from app.services.ai_provider import Role, get_http_client, vision
from app.utils.llm_json import extract_json
from app.utils.prompt_loader import load_prompt

logger = logging.getLogger(__name__)

# Reload prompts each call so prompt edits apply without stale lru cache issues
# in long-lived workers (load_prompt itself is cached by name).


def _detect_prompt() -> str:
    load_prompt.cache_clear()
    return load_prompt("garment_detect")


def _extract_prompt() -> str:
    load_prompt.cache_clear()
    return load_prompt("garment_extract")


_ALLOWED_CATEGORIES = {
    "top",
    "bottom",
    "dress",
    "outerwear",
    "footwear",
    "accessory",
    "ethnic",
}

_MAX_GARMENTS = 6
_MAX_SIDE = 1536

_IMAGE_MODELS = (
    "gemini-2.5-flash-image",
)


@dataclass(frozen=True)
class ExtractedGarment:
    image_bytes: bytes
    category_hint: str
    label: str
    description: str = ""
    coverage: float = 1.0


def _mime(image_bytes: bytes) -> str:
    if image_bytes[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if image_bytes[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "image/jpeg"


def _prep_source(image_bytes: bytes) -> bytes:
    """Downscale large uploads before vision / image-gen calls."""
    img = Image.open(BytesIO(image_bytes))
    img = img.convert("RGB")
    # Apply EXIF orientation so boxes match what vision sees.
    try:
        from PIL import ImageOps

        img = ImageOps.exif_transpose(img) or img
    except Exception:
        pass
    if max(img.size) > _MAX_SIDE:
        ratio = _MAX_SIDE / max(img.size)
        img = img.resize(
            (max(1, int(img.width * ratio)), max(1, int(img.height * ratio))),
            Image.LANCZOS,
        )
    out = BytesIO()
    img.save(out, format="JPEG", quality=90, optimize=True)
    return out.getvalue()


def _normalize_category(raw: str | None) -> str:
    cat = (raw or "top").strip().lower().replace(" ", "_")
    aliases = {
        "tops": "top",
        "bottoms": "bottom",
        "pants": "bottom",
        "trousers": "bottom",
        "shoes": "footwear",
        "shoe": "footwear",
        "oxfords": "footwear",
        "derby": "footwear",
        "jacket": "outerwear",
        "coat": "outerwear",
        "blazer": "outerwear",
        "bandhgala": "outerwear",
        "nehru_jacket": "outerwear",
        "dresses": "dress",
        "accessories": "accessory",
        "pocket_square": "accessory",
        "kurta": "ethnic",
        "sherwani": "ethnic",
    }
    cat = aliases.get(cat, cat)
    return cat if cat in _ALLOWED_CATEGORIES else "top"


def _parse_box(raw) -> tuple[float, float, float, float] | None:
    """Parse Gemini-style box_2d [ymin, xmin, ymax, xmax] in 0–1000 space."""
    if not isinstance(raw, (list, tuple)) or len(raw) != 4:
        return None
    try:
        ymin, xmin, ymax, xmax = [float(v) for v in raw]
    except (TypeError, ValueError):
        return None
    # Accept 0–1 floats as well.
    if max(ymin, xmin, ymax, xmax) <= 1.5:
        ymin, xmin, ymax, xmax = [v * 1000 for v in (ymin, xmin, ymax, xmax)]
    if ymax <= ymin or xmax <= xmin:
        return None
    return (
        max(0.0, min(1000.0, ymin)),
        max(0.0, min(1000.0, xmin)),
        max(0.0, min(1000.0, ymax)),
        max(0.0, min(1000.0, xmax)),
    )


def _mean_abs_diff(a_bytes: bytes, b_bytes: bytes) -> float:
    """0–255 mean channel distance on a 32x32 shrink. Same photo stays low."""
    a = Image.open(BytesIO(a_bytes)).convert("RGB").resize((32, 32), Image.BILINEAR)
    b = Image.open(BytesIO(b_bytes)).convert("RGB").resize((32, 32), Image.BILINEAR)
    pa, pb = a.tobytes(), b.tobytes()
    if len(pa) != len(pb):
        return 255.0
    return sum(abs(x - y) for x, y in zip(pa, pb)) / len(pa)


# ponytail: 32x32 mean-abs. Isolated studio shot vs selfie is >> 22; same-scene copy is not.
_COPY_THRESHOLD = 22.0


def _copied_the_photo(out_bytes: bytes, *refs: bytes) -> bool:
    """True when Gemini returned the input photo instead of an isolated garment."""
    return any(_mean_abs_diff(out_bytes, ref) < _COPY_THRESHOLD for ref in refs if ref)


def _crop_to_box(image_bytes: bytes, box: tuple[float, float, float, float]) -> bytes:
    img = Image.open(BytesIO(image_bytes)).convert("RGB")
    try:
        from PIL import ImageOps

        img = ImageOps.exif_transpose(img) or img
    except Exception:
        pass
    w, h = img.size
    ymin, xmin, ymax, xmax = box
    # Pad ~8% so hems/collars are not clipped.
    pad_y = (ymax - ymin) * 0.08
    pad_x = (xmax - xmin) * 0.08
    left = int(max(0, (xmin - pad_x) / 1000 * w))
    top = int(max(0, (ymin - pad_y) / 1000 * h))
    right = int(min(w, (xmax + pad_x) / 1000 * w))
    bottom = int(min(h, (ymax + pad_y) / 1000 * h))
    if right - left < 16 or bottom - top < 16:
        return image_bytes
    cropped = img.crop((left, top, right, bottom))
    out = BytesIO()
    cropped.save(out, format="JPEG", quality=92, optimize=True)
    return out.getvalue()


def _prompt_variants(category: str, description: str) -> list[str]:
    # All variants are copy-exact. Catalog / ghost-mannequin / "prettier"
    # restyles are forbidden — try-on can studio-style later.
    base = (
        _extract_prompt()
        .replace("{description}", description)
        .replace("{category}", category)
    )
    lock = (
        f"Extract only this {category} from the photo: {description}. "
        "Reproduce the exact print, pattern, colors, fabric, and cut. "
        "Plain light background. No person. Do not redesign or beautify."
    )
    crop_only = (
        f"Cut this {category} out of the photo and put it on a plain light "
        f"background. Item: {description}. Same pixels of the garment — "
        "do not draw a new one."
    )
    return [base, lock, crop_only]


async def detect_garments(image_bytes: bytes) -> list[dict]:
    """Gemini-first vision detect of distinct clothing pieces."""
    source = _prep_source(image_bytes)
    result = await vision(Role.VISION, source, _detect_prompt(), mime=_mime(source))
    if not (result.text or "").strip():
        raise RuntimeError(f"Empty garment detect response from {result.provider}")

    content = extract_json(result.text)
    if not content or not content.strip():
        raise RuntimeError(
            f"No JSON in garment detect response from {result.provider}: "
            f"{result.text[:200]!r}"
        )

    payload = json.loads(content)
    garments = payload.get("garments") if isinstance(payload, dict) else None
    if not isinstance(garments, list):
        return []

    cleaned: list[dict] = []
    for entry in garments[:_MAX_GARMENTS]:
        if not isinstance(entry, dict):
            continue
        description = str(entry.get("description") or entry.get("label") or "").strip()
        label = str(entry.get("label") or "garment").strip() or "garment"
        if not description:
            description = label
        box = _parse_box(entry.get("box_2d") or entry.get("box") or entry.get("bbox"))
        cleaned.append(
            {
                "category": _normalize_category(entry.get("category")),
                "label": label[:64],
                "description": description[:400],
                "box_2d": box,
            }
        )
    logger.info(
        "Garment detect via %s/%s: %d piece(s) → %s",
        result.provider,
        result.model,
        len(cleaned),
        [g["label"] for g in cleaned],
    )
    return cleaned


async def _gemini_extract_once(
    source_bytes: bytes,
    *,
    prompt: str,
    model: str,
) -> bytes:
    parts = [
        {"text": prompt},
        {
            "inline_data": {
                "mime_type": _mime(source_bytes),
                "data": base64.b64encode(source_bytes).decode("ascii"),
            }
        },
    ]
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }
    url = f"{settings.gemini_base_url.rstrip('/')}/models/{model}:generateContent"
    client = get_http_client()
    r = await client.post(
        url,
        headers={
            "x-goog-api-key": settings.gemini_api_key,
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=httpx.Timeout(180.0, connect=15.0),
    )
    r.raise_for_status()
    data = r.json()
    for cand in data.get("candidates") or []:
        finish = (cand.get("finishReason") or "").upper()
        for part in (cand.get("content") or {}).get("parts") or []:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])
        if finish and finish not in {"STOP", "MAX_TOKENS"}:
            raise RuntimeError(
                f"Gemini image blocked ({finish}): {str(cand.get('finishMessage') or data)[:220]}"
            )
    raise RuntimeError(f"Gemini returned no garment image: {str(data)[:300]}")


async def _track_extract_cost(provider: str, model: str) -> None:
    try:
        from app.utils.cost_tracker import track_provider_spend

        await track_provider_spend(provider, model, None, None, 0.04)
    except Exception as exc:
        logger.warning("extract cost track failed: %r", exc)


async def _rembg_crop_fallback(crop_bytes: bytes) -> bytes:
    from app.services.bg_remover import remove_background

    return await remove_background(crop_bytes)


def _image_model_cascade() -> list[str]:
    preferred = settings.gemini_model_image or settings.tryon_model_primary
    ordered: list[str] = []
    for model in (preferred, *_IMAGE_MODELS):
        if model and model not in ordered:
            ordered.append(model)
    return ordered


async def extract_garment_image(
    image_bytes: bytes,
    *,
    category: str,
    description: str,
    box_2d: tuple[float, float, float, float] | None = None,
) -> bytes:
    """Generate a clean product shot; retry prompts/models; crop+rembg fallback."""
    from app.utils.cost_tracker import within_budget

    if not settings.gemini_api_key:
        raise RuntimeError("GEMINI_API_KEY required for garment extraction")
    if not await within_budget("gemini"):
        raise RuntimeError("Gemini monthly spend cap reached")

    full = _prep_source(image_bytes)
    crop = _crop_to_box(full, box_2d) if box_2d else full
    prompts = _prompt_variants(category, description)
    models = _image_model_cascade()
    # Crop + fidelity prompt first. Do not lead with a catalog restyle.
    attempts: list[tuple[bytes, str, str]] = [
        (crop, models[0], prompts[0]),
        (crop, models[0], prompts[1]),
        (crop, models[1] if len(models) > 1 else models[0], prompts[2]),
        (full, models[0], prompts[0]),
    ]
    last_error: Exception | None = None

    for source, model, prompt in attempts:
        try:
            out = await _gemini_extract_once(source, prompt=prompt, model=model)
            await _track_extract_cost("gemini", model)
            if _copied_the_photo(out, full, crop):
                logger.warning(
                    "extract copied the source photo for %s/%s — retry",
                    category,
                    description[:40],
                )
                last_error = RuntimeError("Gemini returned the source photo")
                continue
            logger.info(
                "Gemini extracted %s (%s) via %s (%d bytes)",
                category,
                description[:60],
                model,
                len(out),
            )
            return out
        except Exception as exc:
            last_error = exc
            logger.warning(
                "extract retry failed %s/%s model=%s: %r",
                category,
                description[:40],
                model,
                exc,
            )

    # Last resort: keep the wardrobe complete even if Gemini image is blocked.
    try:
        fallback_src = crop if box_2d else full
        out = await _rembg_crop_fallback(fallback_src)
        logger.warning(
            "Gemini image blocked for %s — saved rembg crop fallback (%d bytes)",
            category,
            len(out),
        )
        return out
    except Exception as exc:
        raise RuntimeError(
            f"Garment AI extract failed for {category}: {last_error}; fallback={exc!r}"
        ) from exc


async def extract_garments(image_bytes: bytes) -> list[ExtractedGarment]:
    """Detect garments with Gemini vision, extract each with Gemini image."""
    try:
        detected = await detect_garments(image_bytes)
    except Exception as exc:
        logger.warning("Garment detect failed: %r", exc)
        return []

    if not detected:
        logger.warning("Garment detect returned zero pieces")
        return []

    # Sequential extracts — parallel calls often trip Gemini rate limits.
    pieces: list[ExtractedGarment] = []
    for entry in detected:
        try:
            png = await extract_garment_image(
                image_bytes,
                category=entry["category"],
                description=entry["description"],
                box_2d=entry.get("box_2d"),
            )
            pieces.append(
                ExtractedGarment(
                    image_bytes=png,
                    category_hint=entry["category"],
                    label=entry["label"],
                    description=entry["description"],
                )
            )
        except Exception as exc:
            logger.warning(
                "Skip garment %s/%s: %r",
                entry.get("category"),
                entry.get("label"),
                exc,
            )

    logger.info(
        "Gemini garment split produced %d/%d pieces",
        len(pieces),
        len(detected),
    )
    return pieces
