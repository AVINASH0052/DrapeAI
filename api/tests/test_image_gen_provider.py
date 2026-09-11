"""Tests for multi-provider try-on image generation."""

import base64
import io
from unittest.mock import AsyncMock, patch

import pytest
from PIL import Image

from app.services.image_gen_provider import (
    TryOnImageResult,
    build_tryon_prompt,
    generate_tryon_image,
)


def _png_bytes(w: int = 64, h: int = 64) -> bytes:
    img = Image.new("RGB", (w, h), (120, 80, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_build_tryon_prompt_includes_size_and_fit():
    prompt = build_tryon_prompt(
        [
            {
                "category": "top",
                "primary_color": "red",
                "sub_category": "t-shirt",
                "garment_size": "m",
                "garment_fit": "baggy",
            }
        ]
    )
    lower = prompt.lower()
    assert "size m" in lower
    assert "baggy" in lower


def test_build_tryon_prompt_includes_items():
    items = [
        {
            "category": "top",
            "primary_color": "blue",
            "fabric": "cotton",
            "sub_category": "kurta",
            "ethnic_flag": True,
        },
        {"category": "bottom", "primary_color": "black"},
    ]
    prompt = build_tryon_prompt(items)
    assert "blue" in prompt
    assert "kurta" in prompt
    assert "wardrobe" in prompt.lower() or "garment" in prompt.lower()


def test_build_tryon_prompt_top_replaces_source_dress():
    """A top must not keep a sherwani/dress from the body photo."""
    from app.services.image_gen_provider import _preserve_instructions

    text = _preserve_instructions(
        [{"category": "top", "sub_category": "t-shirt"}]
    ).lower()
    assert "dresses" in text or "one-piece" in text
    assert "regions to replace" in text
    assert "tops" in text or "shirts" in text
    assert "pants" in text or "trousers" in text or "lower garments" in text


def test_build_tryon_prompt_preserves_unselected_bottoms():
    items = [
        {
            "category": "top",
            "primary_color": "cream",
            "sub_category": "shirt",
        }
    ]
    prompt = build_tryon_prompt(items, version="wardrobe_v1")
    lower = prompt.lower()
    assert "only" in lower
    assert "pants" in lower or "trousers" in lower or "lower garments" in lower
    assert "keep" in lower
    assert "regions to replace" in lower
    assert "tops" in lower or "shirts" in lower


@pytest.mark.asyncio
async def test_generate_tryon_vertex_success():
    person = _png_bytes()
    items = [{"image_url": "users/u/items/x.png", "category": "top"}]
    fake_png = _png_bytes(100, 150)

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._vertex_tryon", new_callable=AsyncMock) as mock_vertex, \
         patch(
             "app.services.image_gen_provider._load_item_bytes_with_meta",
             new_callable=AsyncMock,
         ) as mock_load:
        route.return_value = [("vertex", "gemini-2.5-flash-image")]
        mock_load.return_value = [(items[0], _png_bytes())]
        mock_vertex.return_value = fake_png

        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "vertex"
    assert result.model == "gemini-2.5-flash-image"
    assert len(result.image_bytes) > 0


@pytest.mark.asyncio
async def test_generate_tryon_openai_success():
    person = _png_bytes()
    items = [{"image_url": "users/u/items/x.png", "category": "top"}]
    fake_png = _png_bytes(100, 150)
    b64 = base64.b64encode(fake_png).decode()

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._openai_tryon", new_callable=AsyncMock) as mock_openai, \
         patch(
             "app.services.image_gen_provider._load_item_bytes_with_meta",
             new_callable=AsyncMock,
         ) as mock_load:
        route.return_value = [("openai", "gpt-image-1")]
        mock_load.return_value = [(items[0], _png_bytes())]
        mock_openai.return_value = fake_png

        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "openai"
    assert result.model == "gpt-image-1"
    assert len(result.image_bytes) > 0


@pytest.mark.asyncio
async def test_generate_tryon_failover_to_gemini():
    person = _png_bytes()
    items = [{"category": "dress", "primary_color": "red"}]
    fake_png = _png_bytes(80, 120)

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._nvidia_tryon", new_callable=AsyncMock) as mock_nvidia, \
         patch("app.services.image_gen_provider._gemini_tryon", new_callable=AsyncMock) as mock_gemini, \
         patch(
             "app.services.image_gen_provider._load_item_bytes_with_meta",
             new_callable=AsyncMock,
         ) as mock_load:
        route.return_value = [
            ("nvidia", "qwen/qwen-image-edit"),
            ("gemini", "gemini-2.5-flash-image"),
        ]
        mock_load.return_value = []
        mock_nvidia.side_effect = RuntimeError("rate limited")
        mock_gemini.return_value = fake_png

        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "gemini"
    mock_nvidia.assert_awaited_once()
    mock_gemini.assert_awaited_once()


@pytest.mark.asyncio
async def test_generate_tryon_all_fail_returns_none():
    person = _png_bytes()
    items = []

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._openai_tryon", new_callable=AsyncMock) as mock_openai, \
         patch(
             "app.services.image_gen_provider._load_item_bytes_with_meta",
             new_callable=AsyncMock,
             return_value=[],
         ):
        route.return_value = [("openai", "gpt-image-1")]
        mock_openai.side_effect = RuntimeError("no key")

        result = await generate_tryon_image(person, items)

    assert result is None
