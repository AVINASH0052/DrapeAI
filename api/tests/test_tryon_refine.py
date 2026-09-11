"""Tests for post-result try-on preview refine."""

import io
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from PIL import Image

from app.services.image_gen_provider import (
    TryOnImageResult,
    _refine_multimodal_parts,
    build_tryon_refine_prompt,
    generate_tryon_refine,
    refine_change_scope,
)
from tests.helpers import mark_avatar_ready


def _png(w: int = 64, h: int = 96, color=(80, 100, 140)) -> bytes:
    img = Image.new("RGB", (w, h), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def test_build_tryon_refine_prompt_includes_instruction():
    prompt = build_tryon_refine_prompt("rooftop golden hour")
    assert "rooftop golden hour" in prompt
    assert "IMAGE 0" in prompt
    assert "garment" in prompt.lower() or "outfit" in prompt.lower()


@pytest.mark.asyncio
async def test_generate_tryon_refine_vertex_success():
    fake = _png(100, 150)
    with patch(
        "app.services.image_gen_provider._route_refine",
        return_value=[("vertex", "gemini-2.5-flash-image")],
    ), patch(
        "app.services.image_gen_provider._provider_configured", return_value=True
    ), patch(
        "app.services.image_gen_provider._provider_affordable",
        new_callable=AsyncMock,
        return_value=True,
    ), patch(
        "app.services.image_gen_provider._vertex_image_edit",
        new_callable=AsyncMock,
        return_value=fake,
    ):
        result = await generate_tryon_refine(_png(), "change to outdoor background")

    assert result is not None
    assert isinstance(result, TryOnImageResult)
    assert result.provider == "vertex"
    assert len(result.image_bytes) > 0


@pytest.mark.asyncio
async def test_refine_requires_existing_preview(
    client, auth_headers, test_outfit, clean_db
):
    png = _png(200, 400)
    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize/refine",
        headers=auth_headers,
        json={"message": "outdoor background"},
    )
    assert resp.status_code == 400
    assert "preview" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_refine_success(
    client, auth_headers, test_outfit, test_item, clean_db
):
    from app.config import settings
    from app.database.pool import get_pool

    png = _png(200, 400)
    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    preview_key = f"users/test-user-001/previews/{test_outfit}.png"
    path = Path("uploads") / preview_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_png(120, 180, (60, 80, 120)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE outfits SET preview_image_key = $1 WHERE id = $2",
            preview_key,
            test_outfit,
        )

    fake_out = _png(128, 192, (200, 100, 50))
    with patch.object(settings, "tryon_async", False), patch(
        "app.services.image_gen_provider.generate_tryon_refine",
        new_callable=AsyncMock,
        return_value=TryOnImageResult(
            image_bytes=fake_out, provider="vertex", model="gemini-2.5-flash-image"
        ),
    ):
        resp = await client.post(
            f"/outfits/{test_outfit}/visualize/refine",
            headers=auth_headers,
            json={"message": "warmer light, slight turn"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "completed"
    assert data.get("preview_url")
    assert "refine" in (data.get("method") or "")
    assert "preview-" in data["preview_url"]
    assert preview_key not in data["preview_url"]


@pytest.mark.asyncio
async def test_refine_409_when_other_job_active(
    client, auth_headers, test_outfit, clean_db
):
    """A new change-look message must not be silently replaced by an active job."""
    from app.database.pool import get_pool

    png = _png(200, 400)
    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    preview_key = f"users/test-user-001/previews/{test_outfit}.png"
    path = Path("uploads") / preview_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_png(120, 180, (60, 80, 120)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE outfits SET preview_image_key = $1 WHERE id = $2",
            preview_key,
            test_outfit,
        )
        await conn.execute(
            """
            INSERT INTO try_on_jobs (user_id, outfit_id, status, directives)
            VALUES ($1, $2::uuid, 'processing', $3)
            """,
            "test-user-001",
            test_outfit,
            "different earlier instruction",
        )

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize/refine",
        headers=auth_headers,
        json={"message": "outdoor golden hour"},
    )
    assert resp.status_code == 409
    assert "already in progress" in resp.json()["detail"].lower()


def test_refine_prompt_requests_hd():
    prompt = build_tryon_refine_prompt("turn slightly left")
    assert "HD" in prompt or "ultra-sharp" in prompt.lower()


def test_refine_scope_pose_does_not_unlock_clothes():
    assert refine_change_scope("Walking pose") == ["pose"]
    assert refine_change_scope("Outdoor background") == ["background"]
    prompt = build_tryon_refine_prompt("Walking pose")
    lower = prompt.lower()
    assert "change only" in lower
    assert "pose" in lower
    assert "same face" in lower
    assert "height" in lower
    assert "same garments" in lower
    assert "not a new person" in lower or "do not invent" in lower


def test_refine_parts_include_identity_reference():
    preview = _png(32, 48)
    identity = _png(32, 48, (20, 40, 60))
    parts = _refine_multimodal_parts(
        preview, "lock identity", identity_bytes=identity
    )
    texts = [p.get("text", "") for p in parts if "text" in p]
    assert any("IMAGE 0" in t for t in texts)
    assert any("IMAGE 1" in t and "REAL PERSON" in t for t in texts)
    assert sum(1 for p in parts if "inline_data" in p) == 2
