"""Multi-provider outfit try-on image generation.

Supports Cloudflare Workers AI (FLUX.2 Klein), NVIDIA NIM (qwen-image-edit),
OpenAI (gpt-image-1), and Gemini. Falls through providers in priority order;
returns None if all configured providers fail.
"""

from __future__ import annotations

import asyncio
import base64
import io
import json
import logging
import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import httpx

from app.config import settings
from app.services.ai_provider import get_http_client
from app.services.storage import read_image_bytes
from app.services.try_on_prep import (
    HD_GARMENT_MAX_EDGE,
    HD_PERSON_MAX_EDGE,
    load_prompt_template,
    prep_item_bytes_list,
    prep_person_bytes,
    sort_items_for_tryon,
)

logger = logging.getLogger(__name__)

_VERTEX_SCOPES = ("https://www.googleapis.com/auth/cloud-platform",)
_vertex_token_lock = asyncio.Lock()
_vertex_cached_token: str | None = None
_vertex_token_expiry: float = 0.0


@dataclass
class TryOnImageResult:
    image_bytes: bytes
    provider: str
    model: str


# Regions the model must not invent when the user did not supply that garment.
_PRESERVE_REGIONS = (
    ("top", ("top", "tops", "shirt", "kurta", "blouse", "ethnic_top"), "tops/shirts/upper garments"),
    (
        "bottom",
        ("bottom", "bottoms", "pants", "trousers", "jeans", "skirt", "ethnic_bottom"),
        "pants/trousers/skirts/lower garments",
    ),
    ("dress", ("dress", "dresses", "saree", "lehenga", "sherwani", "gown"), "dresses/one-pieces"),
    ("outerwear", ("outer", "outerwear", "jacket", "blazer", "coat"), "jackets/outerwear"),
    ("footwear", ("shoe", "shoes", "footwear"), "shoes/footwear"),
    (
        "accessory",
        ("accessory", "accessories", "bag", "jewelry", "jewellery", "watch", "cap", "hat", "glasses"),
        "accessories (watch, belt, bag, jewelry, caps, glasses)",
    ),
)


def _item_region_keys(item: dict) -> set[str]:
    cat = (item.get("category") or "").strip().lower().replace("-", "_")
    sub = (item.get("sub_category") or "").strip().lower().replace("-", "_")
    tokens = {t for t in f"{cat} {sub}".replace("/", " ").split() if t}
    keys: set[str] = set()
    for region, aliases, _label in _PRESERVE_REGIONS:
        if cat in aliases or sub in aliases or tokens & set(aliases):
            keys.add(region)
    return keys or {"top"}  # unknown item: still treat as a targeted swap


# A dress/sherwani on the body photo covers the same area as a top or bottom.
_REGION_OVERLAP = {
    "top": {"dress"},
    "bottom": {"dress"},
    "dress": {"top", "bottom"},
}


def _changing_regions(items: list[dict]) -> set[str]:
    changing: set[str] = set()
    for item in items:
        changing |= _item_region_keys(item)
    extra = set()
    for region in changing:
        extra |= _REGION_OVERLAP.get(region, set())
    return changing | extra


def _preserve_instructions(items: list[dict]) -> str:
    """Tell the model which body regions must stay from the person photo."""
    changing = _changing_regions(items)
    keep_labels = [
        label
        for region, _aliases, label in _PRESERVE_REGIONS
        if region not in changing
    ]
    change_labels = [
        label
        for region, _aliases, label in _PRESERVE_REGIONS
        if region in changing
    ]
    if not keep_labels:
        return (
            "- Replace the full outfit using only the provided references; "
            "do not invent extra garments beyond those references."
        )
    return (
        f"- Regions to REPLACE: {', '.join(change_labels)}.\n"
        f"- Regions to KEEP unchanged from IMAGE 0: {', '.join(keep_labels)}."
    )


def build_tryon_prompt(
    items: list[dict],
    version: str | None = None,
    *,
    extra_directives: str | None = None,
) -> str:
    """Build a virtual try-on prompt from wardrobe item metadata."""
    lines = []
    for item in items:
        cat = (item.get("category") or "piece").replace("_", " ")
        color = item.get("primary_color") or ""
        fabric = item.get("fabric") or ""
        sub = item.get("sub_category") or ""
        ethnic = " (ethnic/traditional)" if item.get("ethnic_flag") else ""
        size = (item.get("garment_size") or "").strip()
        fit = (item.get("garment_fit") or "").strip()
        extra_bits = [p for p in (
            f"size {size}" if size else "",
            f"{fit} fit" if fit else "",
        ) if p]
        extra = f" ({', '.join(extra_bits)})" if extra_bits else ""
        detail = " ".join(p for p in [color, fabric, sub, cat] if p).strip()
        lines.append(f"- {detail}{ethnic}{extra}")

    outfit_desc = "\n".join(lines) if lines else "- styled outfit from reference images"
    preserve = _preserve_instructions(items)
    version = version or settings.tryon_prompt_version
    template = load_prompt_template(version)
    if template:
        prompt = (
            template.replace("{outfit_metadata_lines}", outfit_desc)
            .replace("{preserve_instructions}", preserve)
            .strip()
        )
    else:
        prompt = (
            "Edit IMAGE 0 (the person). Apply ONLY the wardrobe reference garments. "
            "Preserve face, body shape, pose, and skin tone. "
            "Do not change clothing that was not provided as a reference.\n\n"
            f"Wardrobe pieces to apply:\n{outfit_desc}\n\n"
            f"{preserve}\n\n"
            "Photorealistic; clothing must match the reference garment images precisely."
        )
    if extra_directives and extra_directives.strip():
        prompt = (
            f"{prompt}\n\nAdditional direction:\n{extra_directives.strip()}\n"
            "Style/pose/quality notes do not override the replace/keep regions above."
        )
    return prompt


async def _load_item_bytes(items: list[dict], limit: int = 4) -> list[bytes]:
    """Load raw bytes for wardrobe item images (storage keys), category-ordered."""
    pairs = await _load_item_bytes_with_meta(items, limit=limit)
    return [b for _item, b in pairs]


async def _load_item_bytes_with_meta(
    items: list[dict], limit: int = 4
) -> list[tuple[dict, bytes]]:
    """Load item images paired with metadata so prompt labels stay aligned."""
    ordered = sort_items_for_tryon(items)
    loaded: list[tuple[dict, bytes]] = []
    for item in ordered:
        if len(loaded) >= limit:
            break
        key = item.get("image_url") or ""
        if not key or key.startswith("http"):
            continue
        try:
            loaded.append((item, await read_image_bytes(key)))
        except Exception as e:
            logger.warning(f"tryon: skip item {key}: {e}")
    return loaded


def _route_tryon() -> list[tuple[str, str]]:
    """Return ordered (provider, model) pairs from settings.

    When Vertex is configured, it is always tried first (Cloud credits),
    even if env cascade mistakenly lists another provider as primary.
    """
    pairs = [
        (settings.tryon_provider_primary, settings.tryon_model_primary),
        (settings.tryon_provider_secondary, settings.tryon_model_secondary),
        (settings.tryon_provider_tertiary, settings.tryon_model_tertiary),
        (settings.tryon_provider_quaternary, settings.tryon_model_quaternary),
    ]
    routes = [(p.lower(), m) for p, m in pairs if p and m]
    if not _vertex_is_configured():
        return routes
    vertex_model = (
        settings.vertex_model_image
        or settings.tryon_model_primary
        or "gemini-2.5-flash-image"
    )
    preferred = ("vertex", vertex_model)
    rest = [pair for pair in routes if pair[0] != "vertex"]
    return [preferred] + rest


def _vertex_credentials_path() -> str | None:
    path = (settings.google_application_credentials or "").strip()
    if not path:
        path = (os.environ.get("GOOGLE_APPLICATION_CREDENTIALS") or "").strip()
    return path or None


def _resolve_vertex_project() -> str:
    project = (settings.google_cloud_project or "").strip()
    if project:
        return project
    path = _vertex_credentials_path()
    if path and Path(path).is_file():
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
            return str(data.get("project_id") or "").strip()
        except Exception as e:
            logger.warning("vertex: could not read project_id from credentials: %r", e)
    return ""


def _vertex_is_configured() -> bool:
    if not _resolve_vertex_project():
        return False
    path = _vertex_credentials_path()
    if path:
        return Path(path).is_file()
    # Ambient ADC (Cloud Run / GCE) — only if google-auth can load something.
    try:
        import google.auth

        google.auth.default(scopes=list(_VERTEX_SCOPES))
        return True
    except Exception:
        return False


def _provider_configured(provider: str) -> bool:
    if provider == "openai":
        return bool(settings.openai_api_key)
    if provider == "nvidia":
        return bool(settings.nvidia_api_key)
    if provider == "gemini":
        return bool(settings.gemini_api_key)
    if provider == "vertex":
        return _vertex_is_configured()
    if provider == "cloudflare":
        account = settings.cloudflare_account_id or settings.r2_account_id
        return bool(account and settings.cloudflare_api_token)
    if provider == "runpod":
        return bool(settings.runpod_api_key and settings.runpod_endpoint_id)
    return False


async def _provider_affordable(provider: str) -> bool:
    """False when this provider has hit its monthly cap.

    Image generation is the most expensive thing this service does, so the
    budget check belongs in the cascade: an over-budget provider is skipped and
    the next one is tried, exactly like an unconfigured one. If every provider
    is over budget the caller falls through to the composite fallback rather
    than to a surprise invoice.
    """
    try:
        from app.utils.cost_tracker import within_budget

        return await within_budget(provider)
    except Exception as e:
        # A tracking outage must not silently disable spend control, but it
        # also must not take down try-on. Log loudly and allow the call.
        logger.error("budget check failed for %s, allowing call: %r", provider, e)
        return True


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


def _tryon_multimodal_parts(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    *,
    person_max_edge: int = HD_PERSON_MAX_EDGE,
    garment_max_edge: int = HD_GARMENT_MAX_EDGE,
    items: list[dict] | None = None,
) -> list[dict]:
    """Shared person + garment parts for Gemini Developer API and Vertex."""
    person = prep_person_bytes(person_bytes, max_edge=person_max_edge)
    garments = prep_item_bytes_list(
        item_bytes, limit=4, max_edge=garment_max_edge
    )
    meta = list(items or [])

    parts: list[dict] = [{"text": prompt}]
    parts.append({
        "text": (
            "IMAGE 0 — PERSON SOURCE. Keep identity (face, body, skin). "
            "Do not keep a dress, sherwani, or one-piece from this photo "
            "when a top or bottom reference is supplied."
        )
    })
    parts.append({
        "inline_data": {
            "mime_type": _mime_from_bytes(person),
            "data": base64.b64encode(person).decode("ascii"),
        }
    })
    for i, b in enumerate(garments):
        item = meta[i] if i < len(meta) else {}
        cat = (item.get("category") or item.get("sub_category") or "garment")
        cat = str(cat).replace("_", " ")
        parts.append({
            "text": (
                f"IMAGE {i + 1} — GARMENT TO APPLY ONLY ({cat}). "
                "Replace this garment type on the person; leave all other clothes unchanged."
            )
        })
        parts.append({
            "inline_data": {
                "mime_type": _mime_from_bytes(b),
                "data": base64.b64encode(b).decode("ascii"),
            }
        })
    return parts


def _extract_inline_image(data: dict) -> bytes:
    candidates = data.get("candidates") or []
    for cand in candidates:
        for part in (cand.get("content") or {}).get("parts") or []:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline and inline.get("data"):
                return base64.b64decode(inline["data"])
    raise RuntimeError("Image model returned no image in response")


def _refresh_vertex_access_token_sync() -> tuple[str, float]:
    """Sync SA / ADC refresh. Run via asyncio.to_thread."""
    path = _vertex_credentials_path()
    if path:
        # Ensure google-auth and downstream see the same file.
        os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", path)
        from google.oauth2 import service_account

        creds = service_account.Credentials.from_service_account_file(
            path, scopes=list(_VERTEX_SCOPES)
        )
    else:
        import google.auth

        creds, _project = google.auth.default(scopes=list(_VERTEX_SCOPES))

    import google.auth.transport.requests

    creds.refresh(google.auth.transport.requests.Request())
    if not creds.token:
        raise RuntimeError("Vertex credentials refresh returned no access token")
    expiry = time.time() + 3000
    if getattr(creds, "expiry", None) is not None:
        try:
            expiry = creds.expiry.timestamp() - 60
        except Exception:
            pass
    return creds.token, expiry


async def _vertex_access_token() -> str:
    global _vertex_cached_token, _vertex_token_expiry
    async with _vertex_token_lock:
        if _vertex_cached_token and time.time() < _vertex_token_expiry:
            return _vertex_cached_token
        token, expiry = await asyncio.to_thread(_refresh_vertex_access_token_sync)
        _vertex_cached_token = token
        _vertex_token_expiry = expiry
        return token


async def _gemini_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
    *,
    person_max_edge: int = HD_PERSON_MAX_EDGE,
    garment_max_edge: int = HD_GARMENT_MAX_EDGE,
    items: list[dict] | None = None,
) -> bytes:
    """Gemini Developer API generateContent with person + clothing refs."""
    parts = _tryon_multimodal_parts(
        person_bytes,
        item_bytes,
        prompt,
        person_max_edge=person_max_edge,
        garment_max_edge=garment_max_edge,
        items=items,
    )
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
    return _extract_inline_image(r.json())


async def _vertex_tryon(
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    model: str,
    *,
    person_max_edge: int = HD_PERSON_MAX_EDGE,
    garment_max_edge: int = HD_GARMENT_MAX_EDGE,
    items: list[dict] | None = None,
) -> bytes:
    """Vertex AI Gemini image generateContent (bills Google Cloud / credits)."""
    project = _resolve_vertex_project()
    if not project:
        raise RuntimeError("Vertex try-on requires GOOGLE_CLOUD_PROJECT")
    location = (settings.google_cloud_location or "us-central1").strip()
    model_id = (model or settings.vertex_model_image or "gemini-2.5-flash-image").strip()

    parts = _tryon_multimodal_parts(
        person_bytes,
        item_bytes,
        prompt,
        person_max_edge=person_max_edge,
        garment_max_edge=garment_max_edge,
        items=items,
    )
    payload = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"],
        },
    }

    url = (
        f"https://{location}-aiplatform.googleapis.com/v1/"
        f"projects/{project}/locations/{location}/publishers/google/"
        f"models/{model_id}:generateContent"
    )
    token = await _vertex_access_token()
    client = get_http_client()
    r = await client.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=httpx.Timeout(180.0, connect=15.0),
    )
    if r.status_code >= 400:
        detail = ""
        try:
            detail = (r.json().get("error") or {}).get("message") or r.text[:200]
        except Exception:
            detail = r.text[:200]
        raise RuntimeError(f"Vertex {r.status_code}: {detail}")
    return _extract_inline_image(r.json())


async def _call_provider(
    provider: str,
    model: str,
    person_bytes: bytes,
    item_bytes: list[bytes],
    prompt: str,
    *,
    items: list[dict] | None = None,
    person_max_edge: int = HD_PERSON_MAX_EDGE,
    garment_max_edge: int = HD_GARMENT_MAX_EDGE,
) -> bytes:
    if provider == "cloudflare":
        return await _cloudflare_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "openai":
        return await _openai_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "nvidia":
        return await _nvidia_tryon(person_bytes, item_bytes, prompt, model)
    if provider == "gemini":
        return await _gemini_tryon(
            person_bytes,
            item_bytes,
            prompt,
            model,
            person_max_edge=person_max_edge,
            garment_max_edge=garment_max_edge,
            items=items,
        )
    if provider == "vertex":
        return await _vertex_tryon(
            person_bytes,
            item_bytes,
            prompt,
            model,
            person_max_edge=person_max_edge,
            garment_max_edge=garment_max_edge,
            items=items,
        )
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
        "vertex": 0.04,
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


def _prefer_hd_routes(routes: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Put the configured HD Vertex/Gemini image model first when available."""
    if _vertex_is_configured():
        hd_model = (
            settings.vertex_model_image_hd
            or settings.vertex_model_image
            or "gemini-2.5-flash-image"
        )
        return [("vertex", hd_model)] + [
            pair for pair in routes if not (pair[0] == "vertex" and pair[1] == hd_model)
        ]
    if settings.gemini_api_key:
        hd_model = settings.gemini_model_image_hd or "gemini-2.5-flash-image"
        return [("gemini", hd_model)] + [
            pair for pair in routes if not (pair[0] == "gemini" and pair[1] == hd_model)
        ]
    return routes


_HD_OUTPUT_DIRECTIVE = (
    "Output ultra-sharp HD fashion photography: crisp fabric weave, "
    "clear button/embroidery detail, natural skin texture, no blur, "
    "no plastic skin, high dynamic range."
)


async def generate_tryon_image(
    person_bytes: bytes,
    items: list[dict],
    *,
    extra_directives: str | None = None,
    quality: str | None = None,
) -> Optional[TryOnImageResult]:
    """Try each configured provider until one succeeds. Returns None if all fail.

    Inference always uses HD input sizes and prefers HD model routes.
    """
    ordered_items = sort_items_for_tryon(items)
    loaded_pairs = await _load_item_bytes_with_meta(ordered_items, limit=4)
    loaded_items = [item for item, _b in loaded_pairs] or ordered_items
    item_bytes = [b for _item, b in loaded_pairs]
    # Always HD into the model (person 2048 / garments 1536 long edge).
    # Prompt also asks for HD output unless avatar-studio already said so.
    quality_n = (quality or "hd").strip().lower() or "hd"
    directives = (extra_directives or "").strip()
    if quality_n == "hd" and "ultra-sharp HD" not in directives:
        directives = f"{directives}\n{_HD_OUTPUT_DIRECTIVE}".strip()
    prompt = build_tryon_prompt(loaded_items, extra_directives=directives or None)
    person_max = HD_PERSON_MAX_EDGE
    garment_max = HD_GARMENT_MAX_EDGE

    routes = _prefer_hd_routes(_route_tryon())

    last_error: Exception | None = None
    for provider, model in routes:
        if not _provider_configured(provider):
            logger.debug(f"tryon: skip {provider}/{model} — not configured")
            continue
        if not await _provider_affordable(provider):
            logger.warning(f"tryon: skip {provider}/{model} — monthly cap reached")
            continue
        try:
            image_bytes = await _call_provider(
                provider,
                model,
                person_bytes,
                item_bytes,
                prompt,
                items=loaded_items,
                person_max_edge=person_max,
                garment_max_edge=garment_max,
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


_REFINE_MAX_MESSAGE = 500

_REFINE_SCOPES: tuple[tuple[str, str, tuple[str, ...]], ...] = (
    (
        "pose",
        "pose / stance / how the body is standing or walking",
        (
            "pose",
            "walk",
            "walking",
            "stand",
            "standing",
            "sit",
            "turn",
            "stride",
            "facing",
            "three-quarter",
            "three quarter",
        ),
    ),
    (
        "background",
        "background / scene behind the person",
        (
            "background",
            "backdrop",
            "outdoor",
            "studio white",
            "street",
            "scene",
            "setting",
        ),
    ),
    (
        "lighting",
        "lighting / color temperature",
        ("light", "lighting", "warmer", "cooler", "golden", "brighter", "dim"),
    ),
    (
        "crop",
        "framing / crop / camera distance",
        ("crop", "closer", "zoom", "framing", "close-up", "close up"),
    ),
    (
        "clothes",
        "garments / outfit",
        (
            "shirt",
            "dress",
            "pant",
            "wear",
            "outfit",
            "garment",
            "kurta",
            "saree",
            "color of",
            "recolor",
        ),
    ),
)


def refine_change_scope(message: str) -> list[str]:
    """Which edit axes the user asked for. Empty = unknown, still lock identity."""
    text = (message or "").strip().lower()
    hit = [
        name
        for name, _label, keys in _REFINE_SCOPES
        if any(key in text for key in keys)
    ]
    return hit


def build_tryon_refine_prompt(message: str) -> str:
    """Surgical edit: change only what was asked; copy the same person."""
    instruction = (message or "").strip()
    scopes = refine_change_scope(instruction)
    labels = {
        name: label for name, label, _keys in _REFINE_SCOPES
    }
    if scopes:
        change = "; ".join(labels[name] for name in scopes)
    else:
        change = (
            "only the specific detail in the user instruction — "
            "the smallest possible edit"
        )
    lock_clothes = "clothes" not in scopes
    clothes_lock = (
        "- the same garments: same cut, color, fabric, logos, and drape\n"
        if lock_clothes
        else "- garments may change only as the instruction requires; keep everything else\n"
    )
    pose_rule = ""
    if "pose" in scopes:
        pose_rule = (
            "Pose change: move THIS same person into the new pose. "
            "Same face, same height, same build, same clothes. "
            "Do not generate a different body or a fashion model.\n"
        )
    bg_rule = ""
    if "background" in scopes and "pose" not in scopes:
        bg_rule = (
            "Background change: keep the person as a faithful copy of IMAGE 0; "
            "replace only the scene behind them.\n"
        )
    return (
        "Surgical edit of IMAGE 0. This is not a new photoshoot and not a new person.\n"
        f"CHANGE ONLY: {change}.\n"
        "User instruction (apply this and nothing else):\n"
        f"{instruction}\n\n"
        "LOCKED — copy from IMAGE 0. Do not invent, beautify, or recast:\n"
        "- the same face (features, age, expression family)\n"
        "- the same identity — not a different person, celebrity, or model\n"
        "- the same height and body proportions "
        "(do not make them taller, shorter, thinner, or more muscular)\n"
        "- the same skin tone and hair\n"
        f"{clothes_lock}"
        "If IMAGE 1 is present, that is the real person. "
        "Match IMAGE 1's face and body; edit IMAGE 0's current look.\n"
        f"{pose_rule}{bg_rule}"
        "Output one ultra-sharp HD photorealistic full-body fashion photo: "
        "crisp fabric detail, natural skin texture, no blur, no plastic skin. "
        "No text overlays or watermarks."
    )


def _refine_multimodal_parts(
    preview_bytes: bytes,
    prompt: str,
    *,
    identity_bytes: bytes | None = None,
) -> list[dict]:
    prepared = prep_person_bytes(preview_bytes, max_edge=HD_PERSON_MAX_EDGE)
    parts: list[dict] = [
        {"text": prompt},
        {
            "text": (
                "IMAGE 0 — CURRENT LOOK. Change only what the instruction asks. "
                "Copy this person's face, height, body, and clothes unless asked."
            )
        },
        {
            "inline_data": {
                "mime_type": _mime_from_bytes(prepared),
                "data": base64.b64encode(prepared).decode("ascii"),
            }
        },
    ]
    if identity_bytes:
        identity = prep_person_bytes(identity_bytes, max_edge=HD_PERSON_MAX_EDGE)
        parts.append(
            {
                "text": (
                    "IMAGE 1 — REAL PERSON. Same face, height, and body as this photo. "
                    "Do not replace them with someone else."
                )
            }
        )
        parts.append(
            {
                "inline_data": {
                    "mime_type": _mime_from_bytes(identity),
                    "data": base64.b64encode(identity).decode("ascii"),
                }
            }
        )
    return parts


async def _gemini_image_edit(
    image_bytes: bytes,
    prompt: str,
    model: str,
    *,
    identity_bytes: bytes | None = None,
) -> bytes:
    parts = _refine_multimodal_parts(
        image_bytes, prompt, identity_bytes=identity_bytes
    )
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"]},
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
    return _extract_inline_image(r.json())


async def _vertex_image_edit(
    image_bytes: bytes,
    prompt: str,
    model: str,
    *,
    identity_bytes: bytes | None = None,
) -> bytes:
    project = _resolve_vertex_project()
    if not project:
        raise RuntimeError("Vertex refine requires GOOGLE_CLOUD_PROJECT")
    location = (settings.google_cloud_location or "us-central1").strip()
    model_id = (model or settings.vertex_model_image or "gemini-2.5-flash-image").strip()
    parts = _refine_multimodal_parts(
        image_bytes, prompt, identity_bytes=identity_bytes
    )
    payload = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }
    url = (
        f"https://{location}-aiplatform.googleapis.com/v1/"
        f"projects/{project}/locations/{location}/publishers/google/"
        f"models/{model_id}:generateContent"
    )
    token = await _vertex_access_token()
    client = get_http_client()
    r = await client.post(
        url,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json=payload,
        timeout=httpx.Timeout(180.0, connect=15.0),
    )
    if r.status_code >= 400:
        detail = ""
        try:
            detail = (r.json().get("error") or {}).get("message") or r.text[:200]
        except Exception:
            detail = r.text[:200]
        raise RuntimeError(f"Vertex {r.status_code}: {detail}")
    return _extract_inline_image(r.json())


def _route_refine() -> list[tuple[str, str]]:
    """Vertex first, then Gemini Developer API — HD image models only."""
    routes: list[tuple[str, str]] = []
    if _vertex_is_configured():
        routes.append(
            (
                "vertex",
                settings.vertex_model_image_hd
                or settings.vertex_model_image
                or "gemini-2.5-flash-image",
            )
        )
    if settings.gemini_api_key:
        gemini_model = (
            settings.gemini_model_image_hd
            or settings.gemini_model_image
            or "gemini-2.5-flash-image"
        )
        if not any(p == "gemini" and m == gemini_model for p, m in routes):
            routes.append(("gemini", gemini_model))
    return _prefer_hd_routes(routes)


async def generate_tryon_refine(
    preview_bytes: bytes,
    message: str,
    *,
    identity_bytes: bytes | None = None,
) -> Optional[TryOnImageResult]:
    """Edit an existing try-on preview from freeform text. No garment reload."""
    text = (message or "").strip()
    if not text:
        raise ValueError("Refine message is required")
    if len(text) > _REFINE_MAX_MESSAGE:
        raise ValueError(f"Refine message must be at most {_REFINE_MAX_MESSAGE} characters")

    prompt = build_tryon_refine_prompt(text)
    last_error: Exception | None = None
    for provider, model in _route_refine():
        if not _provider_configured(provider):
            continue
        if not await _provider_affordable(provider):
            logger.warning(f"tryon refine: skip {provider}/{model} — monthly cap")
            continue
        try:
            if provider == "vertex":
                image_bytes = await _vertex_image_edit(
                    preview_bytes, prompt, model, identity_bytes=identity_bytes
                )
            elif provider == "gemini":
                image_bytes = await _gemini_image_edit(
                    preview_bytes, prompt, model, identity_bytes=identity_bytes
                )
            else:
                continue
            image_bytes = _normalize_png(image_bytes)
            await _track_tryon_cost(provider, model)
            logger.info(
                f"tryon refine: success {provider}/{model} ({len(image_bytes)} bytes)"
            )
            return TryOnImageResult(
                image_bytes=image_bytes,
                provider=provider,
                model=model,
            )
        except Exception as e:
            last_error = e
            logger.warning(f"tryon refine: {provider}/{model} failed: {e!r}")

    logger.warning(f"tryon refine: all providers failed; last_error={last_error!r}")
    return None


def build_external_tryon_prompt() -> str:
    template = load_prompt_template("external_tryon_v1")
    if template:
        return template.strip()
    return (
        "Dress the person in image 0 using the outfit shown in image 1. "
        "Preserve face, hairstyle, body shape, and pose. "
        "Keep the clothing design from image 1 as closely as possible. "
        "Ultra-sharp HD photorealistic fashion photo. "
        "Do not change identity. Do not add text or watermarks."
    )


async def generate_external_tryon_image(
    person_bytes: bytes,
    garment_bytes: bytes,
) -> Optional[TryOnImageResult]:
    """Try-on using a single external outfit/garment reference image."""
    prompt = build_external_tryon_prompt()
    placeholder_items = [{"category": "top", "primary_color": "", "sub_category": "external"}]
    last_error: Exception | None = None
    for provider, model in _prefer_hd_routes(_route_tryon()):
        if not _provider_configured(provider):
            logger.debug(f"tryon external: skip {provider}/{model} — not configured")
            continue
        if not await _provider_affordable(provider):
            logger.warning(
                f"tryon external: skip {provider}/{model} — monthly cap reached"
            )
            continue
        try:
            image_bytes = await _call_provider(
                provider,
                model,
                person_bytes,
                [garment_bytes],
                prompt,
                items=placeholder_items,
                person_max_edge=HD_PERSON_MAX_EDGE,
                garment_max_edge=HD_GARMENT_MAX_EDGE,
            )
            image_bytes = _normalize_png(image_bytes)
            await _track_tryon_cost(provider, model)
            logger.info(
                f"tryon external: success {provider}/{model} ({len(image_bytes)} bytes)"
            )
            return TryOnImageResult(
                image_bytes=image_bytes,
                provider=provider,
                model=model,
            )
        except Exception as e:
            last_error = e
            logger.warning(f"tryon external: {provider}/{model} failed: {e!r}")

    logger.warning(f"tryon external: all providers failed; last_error={last_error!r}")
    return None
