"""Tests for demo wardrobe activation."""

import pytest


@pytest.mark.asyncio
async def test_activate_demo(client, auth_headers, clean_db):
    resp = await client.post("/demo/activate", headers=auth_headers)
    assert resp.status_code == 201
    data = resp.json()
    assert data["activated"] is True
    assert data["items_added"] >= 0


@pytest.mark.asyncio
async def test_clear_demo(client, auth_headers, clean_db):
    await client.post("/demo/activate", headers=auth_headers)
    resp = await client.delete("/demo/clear", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["cleared"] is True
