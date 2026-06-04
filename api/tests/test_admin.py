"""Tests for admin endpoints."""

import pytest


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
    for path in ["/admin/stats", "/admin/users", "/admin/system-health"]:
        resp = await client.get(path)
        assert resp.status_code == 401, f"Expected 401 for {path}"
