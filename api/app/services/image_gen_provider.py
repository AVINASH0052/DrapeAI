"""Multi-provider outfit try-on image generation.

Supports NVIDIA NIM (qwen-image-edit), OpenAI (gpt-image-1), and Gemini
(gemini-2.5-flash-image / gemini-3.1-flash-image). Falls through providers
in priority order; returns None if all configured providers fail.
"""

from __future__ import annotations

import base64
import io
import logging
from dataclasses import dataclass
from typing import Optional

import httpx

from app.config import settings
from app.services.ai_provider import get_http_client
from app.services.storage import read_image_bytes

logger = logging.getLogger(__name__)


@dataclass
class TryOnImageResult:
    image_bytes: bytes
    provider: str
    model: str


def build_tryon_prompt(items: list[dict]) -> str:
    """Build a virtual try-on prompt from wardrobe item metadata."""
    lines = []
    for item in items:
        cat = (item.get("category") or "piece").replace("_", " ")
        color = item.get("primary_color") or ""
        fabric = item.get("fabric") or ""
        sub = item.get("sub_category") or ""
        ethnic = " (ethnic/traditional)" if item.get("ethnic_flag") else ""
        detail = " ".join(p for p in [color, fabric, sub, cat] if p).strip()
        lines.append(f"- {detail}{ethnic}")

    outfit_desc = "\n".join(lines) if lines else "- styled outfit from reference images"

    return (
        "Create a photorealistic full-body fashion photo of this person wearing "
        "the exact clothing items from the reference images. "
        "Preserve the person's face, body shape, pose, and skin tone — only change their clothes.\n\n"
        f"Wardrobe outfit (from the user's own closet, not shopping):\n{outfit_desc}\n\n"
        "Natural lighting, clean neutral background, editorial fashion quality. "
        "The clothing must match the reference garment images precisely."
    )


async def _load_item_bytes(items: list[dict], limit: int = 4) -> list[bytes]:
    """Load raw bytes for wardrobe item images (storage keys)."""
    loaded: list[bytes] = []
    for item in items[:limit]:
        key = item.get("image_url") or ""
        if not key or key.startswith("http"):
            continue
        try:
            loaded.append(await read_image_bytes(key))
        except Exception as e:
            logger.warning(f"tryon: skip item {key}: {e}")
    return loaded


def _route_tryon() -> list[tuple[str, str]]:
    """Return ordered (provider, model) pairs from settings."""
    pairs = [
        (settings.tryon_provider_primary, settings.tryon_model_primary),
        (settings.tryon_provider_secondary, settings.tryon_model_secondary),
        (settings.tryon_provider_tertiary, settings.tryon_model_tertiary),
    ]
    return [(p.lower(), m) for p, m in pairs if p and m]


def _provider_configured(provider: str) -> bool:
    if provider == "openai":
        return bool(settings.openai_api_key)
    if provider == "nvidia":
        return bool(settings.nvidia_api_key)
    if provider == "gemini":
        return bool(settings.gemini_api_key)
    return False


def _mime_from_bytes(data: bytes) -> str:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "image/png"


async def _openai_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """OpenAI POST /images/edits — gpt-image-1 family."""
    client = get_http_client()
    files: list[tuple] = [
        ("image[]", ("person.png", person_bytes, _mime_from_bytes(person_bytes))),
    ]
    for i, b in enumerate(item_bytes[:3]):
        files.append(("image[]", (f"item{i}.png", b, _mime_from_bytes(b))))

    data = {
        "model": model,
        "prompt": prompt,
        "size": settings.tryon_image_size,
        "quality": settings.tryon_image_quality,
    }

    r = await client.post(
        "https://api.openai.com/v1/images/edits",
        headers={"Authorization": f"Bearer {settings.openai_api_key}"},
        files=files,
        data=data,
        timeout=httpx.Timeout(180.0, connect=15.0),
    )
    r.raise_for_status()
    body = r.json()
    b64 = body["data"][0].get("b64_json")
    if not b64:
        raise RuntimeError("OpenAI image edit returned no b64_json")
    return base64.b64decode(b64)


async def _nvidia_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """NVIDIA NIM OpenAI-compatible POST /images/edits (qwen-image-edit)."""
    base = settings.nvidia_visual_genai_url.rstrip("/") if settings.nvidia_visual_genai_url else (
        settings.nvidia_nim_base_url.rstrip("/")
    )
    url = f"{base}/images/edits"

    client = get_http_client()
    files: list[tuple] = [
        ("image[]", ("person.png", person_bytes, _mime_from_bytes(person_bytes))),
    ]
    for i, b in enumerate(item_bytes[:2]):
        files.append(("image[]", (f"item{i}.png", b, _mime_from_bytes(b))))

    data = {"model": model, "prompt": prompt, "n": "1"}

    r = await client.post(
        url,
        headers={"Authorization": f"Bearer {settings.nvidia_api_key}"},
        files=files,
        data=data,
        timeout=httpx.Timeout(180.0, connect=15.0),
    )
    r.raise_for_status()
    body = r.json()
    item = body["data"][0]
    if item.get("b64_json"):
        return base64.b64decode(item["b64_json"])
    if item.get("url"):
        img_r = await client.get(item["url"])
        img_r.raise_for_status()
        return img_r.content
    raise RuntimeError("NVIDIA image edit returned no image data")


async def _gemini_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """Gemini generateContent with person + clothing reference images."""
    parts: list[dict] = [{"text": prompt}]
    parts.append({
        "inline_data": {
            "mime_type": _mime_from_bytes(person_bytes),
            "data": base64.b64encode(person_bytes).decode("ascii"),
        }
    })
    for b in item_bytes[:4]:
        parts.append({
            "inline_data": {
                "mime_type": _mime_from_bytes(b),
                "data": base64.b64encode(b).decode("ascii"),
            }
        })

    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {
            "responseModalities": ["IMAGE"],
        },
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

    candidates = data.get("candidates") or []
    for cand in candidates:
        for part in (cand.get("content") or {}).get("parts") or []:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])

    raise RuntimeError("Gemini returned no image in response")


async def _call_provider(
    provider: str,
    model: str,
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
) -> bytes:
    if provider == "openai":
        return await _openai_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "nvidia":
        return await _nvidia_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "gemini":
        return await _gemini_tryon(person_bytes, item_bytes, prompt, model)
    raise ValueError(f"Unknown try-on provider: {provider}")


async def generate_tryon_image(
    person_bytes: bytes,
    items: list[dict],
) -> Optional[TryOnImageResult]:
    """Try each configured provider until one succeeds. Returns None if all fail."""
    prompt = build_tryon_prompt(items)
    item_bytes = await _load_item_bytes(items)

    last_error: Exception | None = None
    for provider, model in _route_tryon():
        if not _provider_configured(provider):
            logger.debug(f"tryon: skip {provider}/{model} — no api key")
            continue
        try:
            image_bytes = await _call_provider(
                provider, model, person_bytes, item_bytes, prompt
            )
            # Normalize to PNG bytes
            if image_bytes[:8] != b"\x89PNG\r\n\x1a\n":
                img = __import__("PIL.Image", fromlist=["Image"]).Image.open(
                    io.BytesIO(image_bytes)
                )
                buf = io.BytesIO()
                img.convert("RGB").save(buf, format="PNG")
                image_bytes = buf.getvalue()

            logger.info(f"tryon: success {provider}/{model} ({len(image_bytes)} bytes)")
            return TryOnImageResult(
                image_bytes=image_bytes,
                provider=provider,
                model=model,
            )
        except Exception as e:
            last_error = e
            logger.warning(f"tryon: {provider}/{model} failed: {e!r}")

    logger.warning(f"tryon: all providers failed; last_error={last_error!r}")
    return None
