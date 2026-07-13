"""Multi-provider outfit try-on image generation.

Supports Cloudflare Workers AI (FLUX.2 Klein), NVIDIA NIM (qwen-image-edit),
OpenAI (gpt-image-1), and Gemini. Falls through providers in priority order;
returns None if all configured providers fail.
"""

from __future__ import annotations

import asyncio
import base64
import io
import logging
from dataclasses import dataclass
from typing import Optional

import httpx

from app.config import settings
from app.services.ai_provider import get_http_client
from app.services.storage import read_image_bytes
from app.services.try_on_prep import (
    load_prompt_template,
    prep_item_bytes_list,
    prep_person_bytes,
    sort_items_for_tryon,
)

logger = logging.getLogger(__name__)


@dataclass
class TryOnImageResult:
    image_bytes: bytes
    provider: str
    model: str


def build_tryon_prompt(items: list[dict], version: str | None = None) -> str:
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
    version = version or settings.tryon_prompt_version
    template = load_prompt_template(version)
    if template:
        return template.replace("{outfit_metadata_lines}", outfit_desc).strip()

    return (
        "Create a photorealistic full-body fashion photo of this person wearing "
        "the exact clothing items from the reference images. "
        "Preserve the person's face, body shape, pose, and skin tone — only change their clothes.\n\n"
        f"Wardrobe outfit (from the user's own closet, not shopping):\n{outfit_desc}\n\n"
        "Natural lighting, clean neutral background, editorial fashion quality. "
        "The clothing must match the reference garment images precisely."
    )


async def _load_item_bytes(items: list[dict], limit: int = 4) -> list[bytes]:
    """Load raw bytes for wardrobe item images (storage keys), category-ordered."""
    ordered = sort_items_for_tryon(items)
    loaded: list[bytes] = []
    for item in ordered:
        if len(loaded) >= limit:
            break
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
        (settings.tryon_provider_quaternary, settings.tryon_model_quaternary),
    ]
    return [(p.lower(), m) for p, m in pairs if p and m]


def _provider_configured(provider: str) -> bool:
    if provider == "openai":
        return bool(settings.openai_api_key)
    if provider == "nvidia":
        return bool(settings.nvidia_api_key)
    if provider == "gemini":
        return bool(settings.gemini_api_key)
    if provider == "cloudflare":
        account = settings.cloudflare_account_id or settings.r2_account_id
        return bool(account and settings.cloudflare_api_token)
    if provider == "runpod":
        return bool(settings.runpod_api_key and settings.runpod_endpoint_id)
    return False


def _idm_category_from_items(items: list[dict]) -> str:
    """Map wardrobe categories to IDM-VTON mask categories."""
    ordered = sort_items_for_tryon(items)
    if not ordered:
        return "upper_body"
    cat = (ordered[0].get("category") or "").lower()
    if cat in {"bottom", "bottoms", "pants", "skirt", "lower"}:
        return "lower_body"
    if cat in {"dress", "dresses", "saree", "lehenga", "full"}:
        return "dresses"
    return "upper_body"


def _garment_description_from_items(items: list[dict]) -> str:
    ordered = sort_items_for_tryon(items)
    if not ordered:
        return "clothing"
    item = ordered[0]
    parts = [
        item.get("primary_color") or "",
        item.get("fabric") or "",
        item.get("sub_category") or "",
        (item.get("category") or "garment").replace("_", " "),
    ]
    return " ".join(p for p in parts if p).strip() or "clothing"


def _mime_from_bytes(data: bytes) -> str:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    return "image/png"


def _normalize_png(image_bytes: bytes) -> bytes:
    if image_bytes[:8] == b"\x89PNG\r\n\x1a\n":
        return image_bytes
    img = __import__("PIL.Image", fromlist=["Image"]).Image.open(io.BytesIO(image_bytes))
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="PNG")
    return buf.getvalue()


async def _cloudflare_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """Cloudflare Workers AI FLUX.2 Klein — multipart with up to 4 input images."""
    account = settings.cloudflare_account_id or settings.r2_account_id
    if not account or not settings.cloudflare_api_token:
        raise RuntimeError("Cloudflare Workers AI not configured")

    model_id = model if model.startswith("@") else f"@cf/{model}"
    url = (
        f"https://api.cloudflare.com/client/v4/accounts/"
        f"{account}/ai/run/{model_id}"
    )

    person = prep_person_bytes(person_bytes, for_cloudflare=True)
    garments = prep_item_bytes_list(item_bytes, for_cloudflare=True, limit=3)

    files: list[tuple] = [
        ("prompt", (None, prompt)),
        ("width", (None, str(settings.tryon_cloudflare_width))),
        ("height", (None, str(settings.tryon_cloudflare_height))),
        ("input_image_0", ("person.jpg", person, _mime_from_bytes(person))),
    ]
    for i, b in enumerate(garments):
        files.append(
            (f"input_image_{i + 1}", (f"item{i}.jpg", b, _mime_from_bytes(b)))
        )

    client = get_http_client()
    r = await client.post(
        url,
        headers={"Authorization": f"Bearer {settings.cloudflare_api_token}"},
        files=files,
        timeout=httpx.Timeout(float(settings.tryon_job_timeout_sec), connect=15.0),
    )
    r.raise_for_status()

    content_type = (r.headers.get("content-type") or "").lower()
    if "image/" in content_type:
        return r.content

    body = r.json()
    # Workers AI may wrap as { result: { image: "<b64>" } } or { image: "..." }
    result = body.get("result") if isinstance(body, dict) else None
    image_b64 = None
    if isinstance(result, dict):
        image_b64 = result.get("image") or result.get("b64_json")
    if not image_b64 and isinstance(body, dict):
        image_b64 = body.get("image") or body.get("b64_json")
    if isinstance(image_b64, str):
        if "," in image_b64 and image_b64.startswith("data:"):
            image_b64 = image_b64.split(",", 1)[1]
        return base64.b64decode(image_b64)

    raise RuntimeError(f"Cloudflare Workers AI returned no image: {str(body)[:200]}")


async def _openai_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """OpenAI POST /images/edits — gpt-image-1 family."""
    person = prep_person_bytes(person_bytes)
    garments = prep_item_bytes_list(item_bytes, limit=3)

    client = get_http_client()
    files: list[tuple] = [
        ("image[]", ("person.png", person, _mime_from_bytes(person))),
    ]
    for i, b in enumerate(garments):
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

    person = prep_person_bytes(person_bytes)
    garments = prep_item_bytes_list(item_bytes, limit=2)

    client = get_http_client()
    files: list[tuple] = [
        ("image[]", ("person.png", person, _mime_from_bytes(person))),
    ]
    for i, b in enumerate(garments):
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


async def _runpod_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
    *,
    category: str = "upper_body",
    garment_description: str = "",
) -> bytes:
    """RunPod Serverless IDM-VTON worker via /runsync."""
    if not settings.runpod_api_key or not settings.runpod_endpoint_id:
        raise RuntimeError("RunPod try-on not configured")

    person = prep_person_bytes(person_bytes)
    garments = prep_item_bytes_list(item_bytes, limit=1)
    if not garments:
        raise RuntimeError("RunPod try-on requires at least one garment image")

    payload = {
        "input": {
            "person_image": base64.b64encode(person).decode("ascii"),
            "garment_image": base64.b64encode(garments[0]).decode("ascii"),
            "category": category,
            "garment_description": garment_description or prompt[:200],
            "model": model,
        }
    }
    base = f"https://api.runpod.ai/v2/{settings.runpod_endpoint_id}"
    headers = {
        "Authorization": f"Bearer {settings.runpod_api_key}",
        "Content-Type": "application/json",
    }
    client = get_http_client()
    timeout_sec = float(settings.runpod_tryon_timeout_sec)
    deadline = asyncio.get_event_loop().time() + timeout_sec

    r = await client.post(
        f"{base}/runsync",
        headers=headers,
        json=payload,
        timeout=httpx.Timeout(timeout_sec, connect=15.0),
    )
    r.raise_for_status()
    body = r.json()

    # /runsync waits ~90s server-side, then returns IN_QUEUE/IN_PROGRESS on a
    # cold worker instead of blocking further. Poll /status until it settles
    # or our own deadline (runpod_tryon_timeout_sec) runs out.
    job_id = body.get("id")
    status = (body.get("status") or "").upper()
    while status in {"IN_QUEUE", "IN_PROGRESS"} and job_id:
        remaining = deadline - asyncio.get_event_loop().time()
        if remaining <= 0:
            raise RuntimeError(f"RunPod job {job_id} timed out after {timeout_sec:.0f}s (status={status})")
        await asyncio.sleep(min(3.0, max(0.5, remaining)))
        r = await client.get(
            f"{base}/status/{job_id}",
            headers=headers,
            timeout=httpx.Timeout(15.0, connect=15.0),
        )
        r.raise_for_status()
        body = r.json()
        status = (body.get("status") or "").upper()

    if status in {"FAILED", "CANCELLED", "TIMED_OUT"}:
        raise RuntimeError(f"RunPod job {status}: {body.get('error') or body}")

    output = body.get("output") if isinstance(body.get("output"), dict) else body
    if isinstance(output, list) and output:
        output = output[0] if isinstance(output[0], dict) else {"image": output[0]}
    if not isinstance(output, dict):
        raise RuntimeError(f"RunPod returned unexpected payload: {str(body)[:200]}")

    if output.get("error"):
        raise RuntimeError(f"RunPod worker error: {output['error']}")

    image_b64 = output.get("image") or output.get("b64_json")
    if isinstance(image_b64, str):
        if "," in image_b64 and image_b64.startswith("data:"):
            image_b64 = image_b64.split(",", 1)[1]
        return base64.b64decode(image_b64)

    raise RuntimeError(f"RunPod returned no image: {str(body)[:200]}")


async def _gemini_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
) -> bytes:
    """Gemini generateContent with person + clothing reference images."""
    person = prep_person_bytes(person_bytes)
    garments = prep_item_bytes_list(item_bytes, limit=4)

    parts: list[dict] = [{"text": prompt}]
    parts.append({
        "inline_data": {
            "mime_type": _mime_from_bytes(person),
            "data": base64.b64encode(person).decode("ascii"),
        }
    })
    for b in garments:
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
    *,
    items: list[dict] | None = None,
) -> bytes:
    if provider == "cloudflare":
        return await _cloudflare_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "openai":
        return await _openai_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "nvidia":
        return await _nvidia_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "gemini":
        return await _gemini_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "runpod":
        meta = items or []
        return await _runpod_tryon(
            person_bytes,
            item_bytes,
            prompt,
            model,
            category=_idm_category_from_items(meta),
            garment_description=_garment_description_from_items(meta),
        )
    raise ValueError(f"Unknown try-on provider: {provider}")


async def _track_tryon_cost(provider: str, model: str) -> None:
    """Best-effort spend tracking for try-on generations."""
    estimates = {
        "cloudflare": 0.02,
        "openai": 0.06,
        "nvidia": 0.0,
        "gemini": 0.04,
        "runpod": 0.01,
    }
    cost = estimates.get(provider, 0.0)
    if cost <= 0:
        return
    try:
        from app.utils.cost_tracker import track_provider_spend

        await track_provider_spend(provider, model, None, None, cost)
        # Also log dedicated try-on metric
        from app.database.pool import get_pool

        pool = await get_pool()
        metric = "ai_cost_cloudflare_tryon" if provider == "cloudflare" else f"ai_cost_{provider}_tryon"
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO analytics_daily (date, metric, value)
                VALUES (CURRENT_DATE, $1, $2)
                ON CONFLICT (date, metric)
                DO UPDATE SET value = analytics_daily.value + EXCLUDED.value
                """,
                metric,
                cost,
            )
    except Exception as e:
        logger.debug(f"tryon cost track skipped: {e}")


async def generate_tryon_image(
    person_bytes: bytes,
    items: list[dict],
) -> Optional[TryOnImageResult]:
    """Try each configured provider until one succeeds. Returns None if all fail."""
    ordered_items = sort_items_for_tryon(items)
    prompt = build_tryon_prompt(ordered_items)
    item_bytes = await _load_item_bytes(ordered_items)

    last_error: Exception | None = None
    for provider, model in _route_tryon():
        if not _provider_configured(provider):
            logger.debug(f"tryon: skip {provider}/{model} — not configured")
            continue
        try:
            image_bytes = await _call_provider(
                provider, model, person_bytes, item_bytes, prompt, items=ordered_items
            )
            image_bytes = _normalize_png(image_bytes)
            await _track_tryon_cost(provider, model)
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
