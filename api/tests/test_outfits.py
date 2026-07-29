"""Tests for outfit generation and feedback endpoints."""

import pytest
from fastapi import HTTPException

from app.services.outfit_service import _validate_outfit_base


def test_outfit_base_accepts_top_and_bottom():
    _validate_outfit_base([
        {"category": "top", "sub_category": "shirt"},
        {"category": "bottom", "sub_category": "trousers"},
    ])


def test_outfit_base_explains_missing_bottom():
    with pytest.raises(HTTPException) as exc:
        _validate_outfit_base([
            {"category": "top", "sub_category": "shirt"},
            {"category": "top", "sub_category": "t-shirt"},
        ])

    assert exc.value.status_code == 400
    assert "bottom" in exc.value.detail.lower()


@pytest.mark.asyncio
async def test_today_returns_list(client, auth_headers, clean_db):
    """GET /outfits/today returns empty list when no outfits generated today."""
    resp = await client.get("/outfits/today", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "outfits" in data
    assert isinstance(data["outfits"], list)


@pytest.mark.asyncio
async def test_today_unauthorized(client):
    resp = await client.get("/outfits/today")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_shuffle_unauthorized(client):
    resp = await client.post("/outfits/shuffle", json={"occasion": "casual"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_feedback_like(client, auth_headers, test_outfit, clean_db):
    """POST /outfits/{id}/feedback with 'like' records successfully."""
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "like"},
    )
    assert resp.status_code == 200
    assert resp.json()["recorded"] is True


@pytest.mark.asyncio
async def test_feedback_dislike(client, auth_headers, test_outfit, clean_db):
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "dislike"},
    )
    assert resp.status_code == 200
    assert resp.json()["recorded"] is True


@pytest.mark.asyncio
async def test_feedback_save(client, auth_headers, test_outfit, clean_db):
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "save"},
    )
    assert resp.status_code == 200
    assert resp.json()["recorded"] is True


@pytest.mark.asyncio
async def test_feedback_wear(client, auth_headers, test_outfit, clean_db):
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "wear"},
    )
    assert resp.status_code == 200
    assert resp.json()["recorded"] is True


@pytest.mark.asyncio
async def test_feedback_skip(client, auth_headers, test_outfit, clean_db):
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "skip"},
    )
    assert resp.status_code == 200
    assert resp.json()["recorded"] is True


@pytest.mark.asyncio
async def test_feedback_invalid_action(client, auth_headers, test_outfit, clean_db):
    """Invalid feedback action should return 422 (Pydantic validation)."""
    resp = await client.post(
        f"/outfits/{test_outfit}/feedback",
        headers=auth_headers,
        json={"action": "love"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_feedback_outfit_not_found(client, auth_headers, clean_db):
    """Feedback on non-existent outfit returns 404."""
    resp = await client.post(
        "/outfits/00000000-0000-0000-0000-000000000000/feedback",
        headers=auth_headers,
        json={"action": "like"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_feedback_unauthorized(client):
    resp = await client.post(
        "/outfits/00000000-0000-0000-0000-000000000000/feedback",
        json={"action": "like"},
    )
    assert resp.status_code == 401
