"""Route tests for try-on daily-usage fields, 429 payload, and quota refund."""

import io
from pathlib import Path
from unittest.mock import AsyncMock

import pytest
from PIL import Image

from tests.helpers import mark_avatar_ready


def _make_test_png(w: int = 100, h: int = 150, color=(100, 150, 200)) -> bytes:
    img = Image.new("RGB", (w, h), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


async def _prepare_user_and_item(client, auth_headers, test_item):
    """Upload try-on photo and place the item image on local storage."""
    from app.database.pool import get_pool

    up = await client.post(
        "/me/try-on-photo",
        headers=auth_headers,
        files={"image": ("body.png", _make_test_png(200, 400), "image/png")},
    )
    assert up.status_code == 202
    await mark_avatar_ready()

    item_key = f"users/test-user-001/items/{test_item}.png"
    path = Path("uploads") / item_key
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(_make_test_png(80, 80, (200, 50, 50)))

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE items SET image_url = $1 WHERE id = $2", item_key, test_item
        )


@pytest.mark.asyncio
async def test_visualize_response_includes_usage(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    from app.config import settings

    monkeypatch.setattr(settings, "tryon_daily_limit_free", 5)
    await _prepare_user_and_item(client, auth_headers, test_item)

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize", headers=auth_headers
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "completed"
    assert data["limit"] == 5
    assert data["remaining"] == 4

    # Status endpoint also carries usage
    status = await client.get(
        f"/outfits/{test_outfit}/visualize/status", headers=auth_headers
    )
    assert status.status_code == 200
    body = status.json()
    assert body["status"] == "completed"
    assert body["preview_url"]
    assert body["limit"] == 5
    assert body["remaining"] == 4


@pytest.mark.asyncio
async def test_429_payload_has_remaining_and_utc_reset(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    from app.config import settings
    from app.database.pool import get_pool

    monkeypatch.setattr(settings, "tryon_daily_limit_free", 1)
    await _prepare_user_and_item(client, auth_headers, test_item)

    first = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    assert first.status_code == 200

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE outfits SET preview_image_key = NULL WHERE id = $1", test_outfit
        )

    second = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    assert second.status_code == 429
    detail = second.json()["detail"]
    assert detail["limit"] == 1
    assert detail["remaining"] == 0
    assert detail["resets_at"].endswith("Z")
    assert "T00:00:00" in detail["resets_at"]


@pytest.mark.asyncio
async def test_stale_queued_job_marked_failed_on_poll(
    client, auth_headers, test_outfit, clean_db
):
    """A job stuck in 'queued' past the timeout is failed by the status poll."""
    from app.database.pool import get_pool

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO try_on_jobs (user_id, outfit_id, status, created_at)
            VALUES ('test-user-001', $1::uuid, 'queued', NOW() - INTERVAL '1 hour')
            RETURNING id
            """,
            test_outfit,
        )
        job_id = str(row["id"])

    resp = await client.get(
        f"/outfits/{test_outfit}/visualize/status",
        headers=auth_headers,
        params={"job_id": job_id},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "failed"
    assert body["error"] == "try_on_failed"


@pytest.mark.asyncio
async def test_failed_generation_refunds_quota(
    client, auth_headers, test_outfit, test_item, clean_db, monkeypatch
):
    """Provider failure marks the job failed and does not burn daily quota."""
    from app.config import settings

    monkeypatch.setattr(settings, "tryon_daily_limit_free", 3)
    await _prepare_user_and_item(client, auth_headers, test_item)

    monkeypatch.setattr(
        "app.services.outfit_visualizer.visualize_outfit",
        AsyncMock(side_effect=RuntimeError("provider exploded")),
    )

    resp = await client.post(
        f"/outfits/{test_outfit}/visualize",
        headers=auth_headers,
        params={"force": True},
    )
    # The route catches run_visualize_job's re-raised exception and returns
    # a clean failed-status payload instead of an unhandled 500.
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "failed"
    assert body["error"] == "try_on_failed"
    # Failed jobs are excluded from the daily count → full quota remains
    assert body["limit"] == 3
    assert body["remaining"] == 3

    # Status endpoint agrees.
    status = await client.get(
        f"/outfits/{test_outfit}/visualize/status", headers=auth_headers
    )
    assert status.status_code == 200
    assert status.json()["status"] == "failed"
