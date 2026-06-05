"""Tests for wardrobe analysis endpoints."""

import pytest


@pytest.mark.asyncio
async def test_gaps_empty_wardrobe(client, auth_headers, clean_db):
    """GET /wardrobe/gaps with no items returns empty gaps, doesn't crash."""
    resp = await client.get("/wardrobe/gaps", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["gaps"] == []
    assert "message" in data


@pytest.mark.asyncio
async def test_gaps_with_items(client, auth_headers, test_item, clean_db):
    """GET /wardrobe/gaps with items returns a result (may call LLM)."""
    resp = await client.get("/wardrobe/gaps", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "gaps" in data
    assert "total_items" in data
    assert data["total_items"] >= 1


@pytest.mark.asyncio
async def test_gaps_unauthorized(client):
    resp = await client.get("/wardrobe/gaps")
    assert resp.status_code == 401
