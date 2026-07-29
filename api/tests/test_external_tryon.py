"""Tests for external (shop) try-on on saved body photo."""

import io

import pytest
from PIL import Image


def _png_bytes(w=200, h=300, color=(180, 120, 90)) -> bytes:
    img = Image.new("RGB", (w, h), color)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_external_tryon_requires_body_photo(client, auth_headers, clean_db):
    files = {"reference_image": ("garment.png", _png_bytes(), "image/png")}
    resp = await client.post(
        "/try-on/external", headers=auth_headers, files=files
    )
    assert resp.status_code == 400
    assert "full-body" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_external_tryon_composite_success(client, auth_headers, clean_db, setup_db):
    from app.database.pool import get_pool
    from app.services.storage import upload_try_on_photo

    person = _png_bytes(color=(200, 160, 140))
    key = await upload_try_on_photo("test-user-001", person, "image/png")
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET try_on_photo_key = $1 WHERE id = 'test-user-001'",
            key,
        )
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS try_on_sessions (
                id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                reference_image_key TEXT NOT NULL,
                result_image_key    TEXT,
                prompt_version      TEXT NOT NULL DEFAULT 'external_tryon_v1',
                provider            TEXT,
                model               TEXT,
                method              TEXT,
                status              TEXT NOT NULL DEFAULT 'queued',
                error_message       TEXT,
                created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                completed_at        TIMESTAMPTZ
            )
            """
        )

    garment = _png_bytes(color=(40, 80, 160))
    files = {"reference_image": ("garment.png", garment, "image/png")}
    resp = await client.post(
        "/try-on/external", headers=auth_headers, files=files
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["status"] == "completed"
    assert data.get("result_url")
    assert data.get("method") in {"composite", "ai:gemini", "ai:openai", "ai:nvidia", "ai:cloudflare", "ai:runpod"} or data.get("method", "").startswith("ai:")

    session_id = data["session_id"]
    st = await client.get(f"/try-on/external/{session_id}", headers=auth_headers)
    assert st.status_code == 200
    assert st.json()["status"] == "completed"

    hist = await client.get("/try-on/history", headers=auth_headers)
    assert hist.status_code == 200
    sessions = hist.json()["sessions"]
    assert any(s["id"] == session_id for s in sessions)

    # cleanup
    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM try_on_sessions WHERE user_id = 'test-user-001'"
        )
        await conn.execute(
            "DELETE FROM try_on_jobs WHERE user_id = 'test-user-001'"
        )
