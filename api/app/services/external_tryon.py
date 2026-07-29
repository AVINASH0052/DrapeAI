"""External (shop / screenshot) outfit try-on — uses saved body photo + one garment image."""

from __future__ import annotations

import io
import logging
from dataclasses import dataclass

from PIL import Image

from app.config import settings
from app.services.storage import (
    read_image_bytes,
    upload_try_on_session_result,
)

logger = logging.getLogger(__name__)


@dataclass
class ExternalTryOnResult:
    result_key: str
    method: str
    model: str | None = None
    provider: str | None = None


def _composite_external(person_bytes: bytes, garment_bytes: bytes) -> bytes:
    """Last-resort preview: person + garment side-by-side."""
    person = Image.open(io.BytesIO(person_bytes)).convert("RGB")
    garment = Image.open(io.BytesIO(garment_bytes)).convert("RGB")
    h = max(person.height, garment.height, 512)
    scale_p = h / person.height
    scale_g = h / garment.height
    person = person.resize(
        (max(1, int(person.width * scale_p)), h), Image.LANCZOS
    )
    garment = garment.resize(
        (max(1, int(garment.width * scale_g)), h), Image.LANCZOS
    )
    canvas = Image.new("RGB", (person.width + garment.width, h), (245, 245, 245))
    canvas.paste(person, (0, 0))
    canvas.paste(garment, (person.width, 0))
    out = io.BytesIO()
    canvas.save(out, format="PNG", optimize=True)
    return out.getvalue()


async def run_external_tryon(
    user_id: str,
    session_id: str,
    try_on_photo_key: str,
    reference_image_key: str,
) -> ExternalTryOnResult:
    from app.services.image_gen_provider import generate_external_tryon_image

    person_bytes = await read_image_bytes(try_on_photo_key)
    garment_bytes = await read_image_bytes(reference_image_key)

    ai = await generate_external_tryon_image(person_bytes, garment_bytes)
    if ai:
        result_bytes = ai.image_bytes
        method = f"ai:{ai.provider}"
        model = ai.model
        provider = ai.provider
    elif settings.tryon_fallback_composite:
        result_bytes = _composite_external(person_bytes, garment_bytes)
        method = "composite"
        model = None
        provider = None
    else:
        raise RuntimeError(
            "External try-on failed: no AI provider available and composite fallback disabled"
        )

    result_key = await upload_try_on_session_result(user_id, session_id, result_bytes)
    return ExternalTryOnResult(
        result_key=result_key,
        method=method,
        model=model,
        provider=provider,
    )
