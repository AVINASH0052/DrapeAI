"""Tests for Cloudflare try-on provider and prompt/prep helpers."""

import base64
import io
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from PIL import Image

from app.services.image_gen_provider import (
    build_tryon_prompt,
    generate_tryon_image,
)
from app.services.try_on_prep import (
    resize_for_cloudflare,
    sort_items_for_tryon,
)


def _png_bytes(w: int = 64, h: int = 64) -> bytes:
    img = Image.new("RGB", (w, h), (120, 80, 200))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_build_tryon_prompt_uses_template():
    items = [
        {
            "category": "top",
            "primary_color": "blue",
            "fabric": "cotton",
            "sub_category": "kurta",
            "ethnic_flag": True,
        }
    ]
    prompt = build_tryon_prompt(items, version="wardrobe_v1")
    assert "blue" in prompt
    assert "kurta" in prompt
    assert "Preserve face" in prompt or "preserve face" in prompt.lower()


def test_sort_items_for_tryon_priority():
    items = [
        {"category": "shoes", "id": "s"},
        {"category": "outerwear", "id": "o"},
        {"category": "top", "id": "t"},
        {"category": "bottom", "id": "b"},
    ]
    ordered = sort_items_for_tryon(items)
    assert [i["id"] for i in ordered] == ["t", "b", "s", "o"]


def test_resize_for_cloudflare_under_512():
    big = _png_bytes(1200, 800)
    out = resize_for_cloudflare(big)
    img = Image.open(io.BytesIO(out))
    assert max(img.size) <= 512


@pytest.mark.asyncio
async def test_generate_tryon_cloudflare_success():
    person = _png_bytes(200, 300)
    items = [{"image_url": "users/u/items/x.png", "category": "top"}]
    fake_png = _png_bytes(100, 150)
    b64 = base64.b64encode(fake_png).decode()

    mock_resp = MagicMock()
    mock_resp.headers = {"content-type": "application/json"}
    mock_resp.raise_for_status = MagicMock()
    mock_resp.json.return_value = {"result": {"image": b64}}

    mock_client = MagicMock()
    mock_client.post = AsyncMock(return_value=mock_resp)

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider.get_http_client", return_value=mock_client), \
         patch("app.services.image_gen_provider._load_item_bytes", new_callable=AsyncMock) as mock_load, \
         patch("app.services.image_gen_provider.settings") as mock_settings, \
         patch("app.services.image_gen_provider._track_tryon_cost", new_callable=AsyncMock):
        route.return_value = [("cloudflare", "@cf/black-forest-labs/flux-2-klein-9b")]
        mock_load.return_value = [_png_bytes()]
        mock_settings.cloudflare_account_id = "acct"
        mock_settings.cloudflare_api_token = "tok"
        mock_settings.r2_account_id = ""
        mock_settings.tryon_cloudflare_width = 1024
        mock_settings.tryon_cloudflare_height = 1536
        mock_settings.tryon_job_timeout_sec = 120
        mock_settings.tryon_prompt_version = "wardrobe_v1"

        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "cloudflare"
    assert result.image_bytes[:8] == b"\x89PNG\r\n\x1a\n"
    mock_client.post.assert_awaited_once()


@pytest.mark.asyncio
async def test_generate_tryon_failover_cloudflare_to_openai():
    person = _png_bytes()
    items = [{"category": "dress", "primary_color": "red"}]
    fake_png = _png_bytes(80, 120)

    with patch("app.services.image_gen_provider._route_tryon") as route, \
         patch("app.services.image_gen_provider._provider_configured", return_value=True), \
         patch("app.services.image_gen_provider._cloudflare_tryon", new_callable=AsyncMock) as mock_cf, \
         patch("app.services.image_gen_provider._openai_tryon", new_callable=AsyncMock) as mock_openai, \
         patch("app.services.image_gen_provider._load_item_bytes", new_callable=AsyncMock) as mock_load, \
         patch("app.services.image_gen_provider._track_tryon_cost", new_callable=AsyncMock):
        route.return_value = [
            ("cloudflare", "@cf/black-forest-labs/flux-2-klein-9b"),
            ("openai", "gpt-image-1"),
        ]
        mock_load.return_value = []
        mock_cf.side_effect = RuntimeError("quota")
        mock_openai.return_value = fake_png

        result = await generate_tryon_image(person, items)

    assert result is not None
    assert result.provider == "openai"
    mock_cf.assert_awaited_once()
    mock_openai.assert_awaited_once()
