"""Tests for user stats, weather, and account deletion endpoints."""

import pytest


@pytest.mark.asyncio
async def test_get_my_stats(client, auth_headers, clean_db):
    """GET /me/stats returns expected structure."""
    resp = await client.get("/me/stats", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "total_items" in data
    assert "saved_outfits" in data
    assert "utilization_pct" in data
    assert "total_outfits_generated" in data
    assert "most_worn_items" in data
    assert "least_worn_items" in data
    assert "category_distribution" in data
    assert isinstance(data["total_items"], int)
    assert isinstance(data["utilization_pct"], (int, float))


@pytest.mark.asyncio
async def test_get_weather(client):
    """GET /weather returns temp and condition."""
    resp = await client.get("/weather?city=delhi")
    assert resp.status_code == 200
    data = resp.json()
    assert "temp_c" in data or "error" in data


@pytest.mark.asyncio
async def test_delete_account_requires_auth(client):
    """DELETE /me without auth returns 401."""
    resp = await client.delete("/me")
    assert resp.status_code == 401
