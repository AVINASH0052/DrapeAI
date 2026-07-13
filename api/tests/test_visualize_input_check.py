"""Route-level tests for the try-on pre-flight input-check wiring."""

import io
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest
from PIL import Image

from app.services.tryon_input_check import InputCheckResult


def _make_test_png(w: int = 100, h: int = 150, color=(100, 150, 200)) -> bytes:
    img = Image.new("RGB", (w, h), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_upload_rejects_bad_person_photo(client, auth_headers, clean_db):
    bad_result = InputCheckResult(
        ok=False, issue="back_view", reason="This photo shows your back, not your face."
    )
    with patch(
        "app.routes.user.check_person_photo",
        new=AsyncMock(return_value=bad_result),
    ):
        resp = await client.post(
            "/me/try-on-photo",
            headers=auth_headers,
            files={"image": ("body.png", _make_test_png(), "image/png")},
        )
    assert resp.status_code == 400
    assert "back" in resp.json()["detail"].lower()

    # Rejected photo must not be persisted.
    me = await client.get("/me", headers=auth_headers)
    assert me.json()["try_on_photo_url"] is None


@pytest.mark.asyncio
async def test_upload_accepts_good_person_photo(client, auth_headers, clean_db):
    good_result = InputCheckResult(ok=True, issue="none")
    with patch(
        "app.routes.user.check_person_photo",
        new=AsyncMock(return_value=good_result),
    ):
        resp = await client.post(
            "/me/try-on-photo",
            headers=auth_headers,
            files={"image": ("body.png", _make_test_png(), "image/png")},
        )
    assert resp.status_code == 201
    assert resp.json()["uploaded"] is True


@pytest.mark.asyncio
async def test_visualize_fails_on_bad_garment_reference(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    """A garment photo that fails the pre-flight check produces a failed
    job with the specific reason, instead of a garbled generated image —
    this is the exact scenario found in manual testing (back-view blouse)."""
    from app.database.pool import get_pool

    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", _make_test_png(200, 400), "image/png")},
    )
    assert up.status_code == 201

    item_key = f"users/test-user-001/items/{test_item}.png"
    path = Path("uploads") / item_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_make_test_png(80, 80, (200, 50, 50)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE items SET image_url = $1 WHERE id = $2", item_key, test_item
        )

    bad_result = InputCheckResult(
        ok=False,
        issue="back_view",
        reason="This photo shows the back of the blouse — the front isn't visible.",
    )
    monkeypatch.setattr(
        "app.services.tryon_input_check.check_garment_photo",
        AsyncMock(return_value=bad_result),
    )
    # Force the check to actually run (bypass the "disabled in tests" default).
    from app.config import settings
    monkeypatch.setattr(settings, "tryon_input_check_enabled", True)

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "failed"
    assert "back of the blouse" in data["error"]
    # Failed pre-flight checks shouldn't burn the daily quota either.
    assert data["remaining"] == data["limit"]


@pytest.mark.asyncio
async def test_garment_check_result_is_cached_on_item(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    """Second visualize of the same item must not re-run the vision check."""
    from app.database.pool import get_pool

    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", _make_test_png(200, 400), "image/png")},
    )
    assert up.status_code == 201

    item_key = f"users/test-user-001/items/{test_item}.png"
    path = Path("uploads") / item_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_make_test_png(80, 80, (200, 50, 50)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE items SET image_url = $1 WHERE id = $2", item_key, test_item
        )

    good_result = InputCheckResult(ok=True, issue="none")
    mock_check = AsyncMock(return_value=good_result)
    monkeypatch.setattr("app.services.tryon_input_check.check_garment_photo", mock_check)
    from app.config import settings
    monkeypatch.setattr(settings, "tryon_input_check_enabled", True)

    first = await client.post(
        f"/outfits/{test_outfit}/visualize", headers=auth_headers, params={"force": True}
    )
    assert first.status_code == 200
    assert mock_check.await_count == 1

    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT tryon_ref_ok, tryon_ref_checked_key FROM items WHERE id = $1",
            test_item,
        )
    assert row["tryon_ref_ok"] is True
    assert row["tryon_ref_checked_key"] == item_key

    second = await client.post(
        f"/outfits/{test_outfit}/visualize", headers=auth_headers, params={"force": True}
    )
    assert second.status_code == 200
    # Cached — no second vision call for the same image_url.
    assert mock_check.await_count == 1
