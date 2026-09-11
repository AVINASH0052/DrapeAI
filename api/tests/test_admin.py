"""Tests for admin endpoints."""

import pytest
import pytest_asyncio

from app.database.pool import get_pool


async def _ensure_admin_schema(conn):
    await conn.execute(
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_notes TEXT"
    )
    await conn.execute(
        """
        ALTER TABLE items
            ADD COLUMN IF NOT EXISTS is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
            ADD COLUMN IF NOT EXISTS flagged_at TIMESTAMPTZ,
            ADD COLUMN IF NOT EXISTS flagged_reason TEXT
        """
    )
    await conn.execute(
        """
        CREATE TABLE IF NOT EXISTS admin_audit_log (
            id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            admin_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
            action      TEXT NOT NULL,
            target_type TEXT NOT NULL,
            target_id   TEXT,
            meta        JSONB NOT NULL DEFAULT '{}'::jsonb,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )


async def _promote_admin():
    pool = await get_pool()
    async with pool.acquire() as conn:
        await _ensure_admin_schema(conn)
        await conn.execute(
            "UPDATE users SET is_admin = TRUE WHERE id = 'test-user-001'"
        )


async def _demote_admin():
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET is_admin = FALSE, admin_notes = NULL WHERE id = 'test-user-001'"
        )


@pytest_asyncio.fixture
async def admin_headers(setup_db, auth_headers):
    await _promote_admin()
    yield auth_headers
    await _demote_admin()


@pytest.mark.asyncio
async def test_admin_stats_requires_admin(client, auth_headers):
    """GET /admin/stats with non-admin user returns 403."""
    resp = await client.get("/admin/stats", headers=auth_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_users_requires_admin(client, auth_headers):
    """GET /admin/users with non-admin user returns 403."""
    resp = await client.get("/admin/users", headers=auth_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_system_health_requires_admin(client, auth_headers):
    """GET /admin/system-health with non-admin user returns 403."""
    resp = await client.get("/admin/system-health", headers=auth_headers)
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_admin_endpoints_require_auth(client):
    """Admin endpoints without auth return 401."""
    for path in [
        "/admin/stats",
        "/admin/users",
        "/admin/system-health",
        "/admin/items",
        "/admin/waitlist",
        "/admin/analytics/overview",
        "/admin/push/segments",
    ]:
        resp = await client.get(path)
        assert resp.status_code == 401, f"Expected 401 for {path}"


@pytest.mark.asyncio
async def test_admin_stats_ok(client, admin_headers):
    resp = await client.get("/admin/stats", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "total_users" in data
    assert "ai_spend_today" in data
    assert "ai_spend_month" in data


@pytest.mark.asyncio
async def test_admin_users_list_enriched(client, admin_headers):
    resp = await client.get("/admin/users?limit=10", headers=admin_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "users" in data
    assert "total" in data
    assert isinstance(data["users"], list)


@pytest.mark.asyncio
async def test_admin_user_detail_and_patch(client, admin_headers, clean_db):
    uid = "test-user-001"
    resp = await client.get(f"/admin/users/{uid}", headers=admin_headers)
    assert resp.status_code == 200
    detail = resp.json()
    assert detail["id"] == uid
    assert "item_count" in detail

    resp = await client.patch(
        f"/admin/users/{uid}",
        headers=admin_headers,
        json={"admin_notes": "VIP support"},
    )
    assert resp.status_code == 200
    assert resp.json()["admin_notes"] == "VIP support"


@pytest.mark.asyncio
async def test_admin_reset_onboarding(client, admin_headers, clean_db):
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET onboarding_done = TRUE WHERE id = 'test-user-001'"
        )

    resp = await client.post(
        "/admin/users/test-user-001/reset-onboarding",
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["onboarding_done"] is False


@pytest.mark.asyncio
async def test_admin_user_content_endpoints(client, admin_headers, test_item, test_outfit):
    uid = "test-user-001"
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO lookbooks (user_id, name)
            VALUES ($1, 'Admin test lookbook')
            ON CONFLICT DO NOTHING
            """,
            uid,
        )

    for path in [
        f"/admin/users/{uid}/items",
        f"/admin/users/{uid}/outfits",
        f"/admin/users/{uid}/lookbooks",
        f"/admin/users/{uid}/activity",
        f"/admin/users/{uid}/try-ons",
    ]:
        resp = await client.get(path, headers=admin_headers)
        assert resp.status_code == 200, path

    lookbooks = (
        await client.get(f"/admin/users/{uid}/lookbooks", headers=admin_headers)
    ).json()["lookbooks"]
    assert any(lb.get("name") == "Admin test lookbook" for lb in lookbooks)


@pytest.mark.asyncio
async def test_admin_flag_and_list_items(client, admin_headers, test_item):
    resp = await client.post(
        f"/admin/items/{test_item}/flag",
        headers=admin_headers,
        json={"reason": "inappropriate"},
    )
    assert resp.status_code == 200
    assert resp.json()["is_flagged"] is True

    resp = await client.get("/admin/items?flagged=true", headers=admin_headers)
    assert resp.status_code == 200
    ids = [i["id"] for i in resp.json()["items"]]
    assert test_item in ids

    resp = await client.post(
        f"/admin/items/{test_item}/unflag",
        headers=admin_headers,
    )
    assert resp.status_code == 200
    assert resp.json()["is_flagged"] is False


@pytest.mark.asyncio
async def test_admin_analytics_and_waitlist(client, admin_headers):
    for path in [
        "/admin/analytics/overview",
        "/admin/analytics/costs",
        "/admin/analytics/usage",
        "/admin/analytics/top-users?metric=items",
        "/admin/waitlist",
        "/admin/push/segments",
        "/admin/system-health",
        "/admin/ai-usage",
    ]:
        resp = await client.get(path, headers=admin_headers)
        assert resp.status_code == 200, path

    health = (await client.get("/admin/system-health", headers=admin_headers)).json()
    assert "db_connected" in health
    assert "tables" in health
    assert "db_version" in health
