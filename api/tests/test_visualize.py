"""Tests for outfit visualization and try-on photo endpoints."""

import io

import pytest
from PIL import Image

from tests.helpers import mark_avatar_ready


def _make_test_png(w: int = 100, h: int = 150, color=(100, 150, 200)) -> bytes:
    img = Image.new("RGB", (w, h), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_try_on_photo_upload(client, auth_headers, clean_db):
    """POST /me/try-on-photo stores a reference photo."""
    png = _make_test_png()
    resp = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert resp.status_code == 202
    data = resp.json()
    assert data["uploaded"] is True
    assert "try_on_photo_url" in data

    me = await client.get("/me", headers=auth_headers)
    assert me.json()["try_on_photo_url"] is not None


@pytest.mark.asyncio
async def test_visualize_requires_try_on_photo(
    client, auth_headers, test_outfit, clean_db
):
    """POST /outfits/{id}/visualize fails without try-on photo."""
    resp = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
    )
    assert resp.status_code == 400
    assert "full-body photo" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_visualize_generates_preview(
    client, auth_headers, test_outfit, test_item, clean_db
):
    """POST /outfits/{id}/visualize creates a composite preview."""
    from pathlib import Path

    pool_fixture = None
    from app.database.pool import get_pool

    # Upload try-on photo
    png = _make_test_png(200, 400)
    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    # Place a dummy item image on disk for composite
    item_key = f"users/test-user-001/items/{test_item}.png"
    path = Path("uploads") / item_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_make_test_png(80, 80, (200, 50, 50)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE items SET image_url = $1 WHERE id = $2",
            item_key,
            test_item,
        )

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "preview_url" in data
    assert data.get("cached") is False
    assert data.get("method") == "composite"
    assert data.get("status") == "completed"

    # Second call should return cached
    resp2 = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
    )
    assert resp2.status_code == 200
    assert resp2.json()["cached"] is True
    assert resp2.json().get("status") == "completed"


@pytest.mark.asyncio
async def test_visualize_daily_limit(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    """429 when daily try-on limit is exceeded."""
    from pathlib import Path

    from app.config import settings

    monkeypatch.setattr(settings, "tryon_daily_limit_free", 1)

    png = _make_test_png(200, 400)
    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", png, "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    item_key = f"users/test-user-001/items/{test_item}.png"
    path = Path("uploads") / item_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_make_test_png(80, 80, (200, 50, 50)))

    from app.database.pool import get_pool

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE items SET image_url = $1 WHERE id = $2",
            item_key,
            test_item,
        )
        await conn.execute(
            "UPDATE outfits SET preview_image_key = NULL WHERE id = $1",
            test_outfit,
        )

    first = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    assert first.status_code == 200

    # Clear cache so second call would regenerate
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE outfits SET preview_image_key = NULL WHERE id = $1",
            test_outfit,
        )

    second = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    assert second.status_code == 429


@pytest.mark.asyncio
async def test_visualize_outfit_not_found(client, auth_headers, clean_db):
    resp = await client.post(
        "/outfits/00000000-0000-0000-0000-000000000000/visualize",
        headers=auth_headers,
    )
    assert resp.status_code == 400 or resp.status_code == 404
