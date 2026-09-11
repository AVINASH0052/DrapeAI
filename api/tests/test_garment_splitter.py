"""Unit tests for AI garment detection / extraction helpers."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.garment_splitter import (
    ExtractedGarment,
    _copied_the_photo,
    _normalize_category,
    detect_garments,
    extract_garment_image,
    extract_garments,
)


def _tiny_jpeg() -> bytes:
    # Minimal valid-ish JPEG header + padding for prep_source / mime sniffing.
    from io import BytesIO

    from PIL import Image

    buf = BytesIO()
    Image.new("RGB", (32, 48), (20, 80, 160)).save(buf, format="JPEG")
    return buf.getvalue()


def _solid_jpeg(color: tuple[int, int, int], size: tuple[int, int] = (64, 80)) -> bytes:
    from io import BytesIO

    from PIL import Image

    buf = BytesIO()
    Image.new("RGB", size, color).save(buf, format="JPEG")
    return buf.getvalue()


def test_copied_the_photo_rejects_same_scene():
    selfie = _solid_jpeg((180, 40, 40))
    isolated = _solid_jpeg((230, 230, 230))
    assert _copied_the_photo(selfie, selfie) is True
    assert _copied_the_photo(isolated, selfie) is False


@pytest.mark.asyncio
async def test_extract_retries_when_gemini_returns_the_photo():
    source = _tiny_jpeg()
    isolated = _solid_jpeg((240, 240, 240), (48, 64))

    with (
        patch(
            "app.utils.cost_tracker.within_budget",
            new_callable=AsyncMock,
            return_value=True,
        ),
        patch(
            "app.services.garment_splitter._gemini_extract_once",
            new_callable=AsyncMock,
            side_effect=[source, isolated],
        ),
        patch(
            "app.services.garment_splitter._track_extract_cost",
            new_callable=AsyncMock,
        ),
        patch("app.services.garment_splitter.settings") as settings,
    ):
        settings.gemini_api_key = "test"
        settings.gemini_model_image = "gemini-2.5-flash-image"
        settings.tryon_model_primary = None
        out = await extract_garment_image(
            source, category="top", description="red t-shirt"
        )

    assert out == isolated


def test_extract_prompts_are_copy_exact_not_catalog():
    from app.services.garment_splitter import _prompt_variants

    text = " ".join(_prompt_variants("top", "pink floral cotton shirt")).lower()
    assert "do not redesign" in text or "do not draw a new one" in text
    assert "e-commerce" not in text
    assert "ghost mannequin" not in text
    assert "catalog" not in text


def test_normalize_category_aliases():
    assert _normalize_category("Tops") == "top"
    assert _normalize_category("trousers") == "bottom"
    assert _normalize_category("jacket") == "outerwear"
    assert _normalize_category("bandhgala") == "outerwear"
    assert _normalize_category("weird") == "top"


def test_parse_and_crop_box():
    from app.services.garment_splitter import _crop_to_box, _parse_box

    assert _parse_box([100, 200, 800, 700]) == (100.0, 200.0, 800.0, 700.0)
    assert _parse_box([0.1, 0.2, 0.8, 0.7]) == (100.0, 200.0, 800.0, 700.0)
    assert _parse_box([1, 2, 3]) is None

    from io import BytesIO

    from PIL import Image

    img = Image.new("RGB", (1000, 1000), (10, 20, 30))
    buf = BytesIO()
    img.save(buf, format="JPEG")
    cropped = _crop_to_box(buf.getvalue(), (0, 0, 500, 500))
    out = Image.open(BytesIO(cropped))
    assert out.size[0] <= 600
    assert out.size[1] <= 600


@pytest.mark.asyncio
async def test_detect_garments_parses_vision_json():
    vision_result = MagicMock()
    vision_result.provider = "test"
    vision_result.text = """
    {
      "garments": [
        {"category": "top", "label": "t-shirt", "description": "blue cotton tee"},
        {"category": "bottom", "label": "pants", "description": "beige trousers"}
      ]
    }
    """
    with patch(
        "app.services.garment_splitter.vision",
        new_callable=AsyncMock,
        return_value=vision_result,
    ):
        found = await detect_garments(_tiny_jpeg())

    assert len(found) == 2
    assert found[0]["category"] == "top"
    assert found[1]["category"] == "bottom"
    assert "blue" in found[0]["description"]


@pytest.mark.asyncio
async def test_extract_garments_calls_ai_per_detection():
    detections = [
        {"category": "top", "label": "shirt", "description": "navy shirt"},
        {"category": "bottom", "label": "pants", "description": "beige pants"},
    ]
    png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 40

    with (
        patch(
            "app.services.garment_splitter.detect_garments",
            new_callable=AsyncMock,
            return_value=detections,
        ),
        patch(
            "app.services.garment_splitter.extract_garment_image",
            new_callable=AsyncMock,
            return_value=png,
        ) as extract_one,
    ):
        pieces = await extract_garments(_tiny_jpeg())

    assert len(pieces) == 2
    assert all(isinstance(p, ExtractedGarment) for p in pieces)
    assert {p.category_hint for p in pieces} == {"top", "bottom"}
    assert extract_one.await_count == 2


@pytest.mark.asyncio
async def test_extract_garments_skips_failed_piece():
    detections = [
        {"category": "top", "label": "shirt", "description": "navy shirt"},
        {"category": "bottom", "label": "pants", "description": "beige pants"},
    ]
    png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 40

    async def _extract(_bytes, *, category, description, box_2d=None):
        if category == "bottom":
            raise RuntimeError("boom")
        return png

    with (
        patch(
            "app.services.garment_splitter.detect_garments",
            new_callable=AsyncMock,
            return_value=detections,
        ),
        patch(
            "app.services.garment_splitter.extract_garment_image",
            new_callable=AsyncMock,
            side_effect=_extract,
        ),
    ):
        pieces = await extract_garments(_tiny_jpeg())

    assert len(pieces) == 1
    assert pieces[0].category_hint == "top"
