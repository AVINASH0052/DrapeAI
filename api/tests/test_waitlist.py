"""Public waitlist endpoint tests."""

import pytest


@pytest.mark.asyncio
async def test_join_waitlist_success(client):
    response = await client.post(
        "/waitlist",
        json={"email": "Early@Sugatai.com", "source": "landing"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["ok"] is True
    assert data["already_joined"] is False
    assert "early list" in data["message"].lower()


@pytest.mark.asyncio
async def test_join_waitlist_duplicate(client):
    email = "dup@sugatai.com"
    first = await client.post("/waitlist", json={"email": email})
    second = await client.post("/waitlist", json={"email": email})
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["already_joined"] is True


@pytest.mark.asyncio
async def test_join_waitlist_invalid_email(client):
    response = await client.post("/waitlist", json={"email": "not-an-email"})
    assert response.status_code == 400
