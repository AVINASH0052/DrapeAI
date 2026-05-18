import pytest


@pytest.mark.asyncio
async def test_verify_with_token(client, auth_headers):
    resp = await client.post("/auth/verify", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["user_id"] == "test-user-001"


@pytest.mark.asyncio
async def test_verify_without_token(client):
    resp = await client.post("/auth/verify")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_verify_bad_token(client):
    resp = await client.post(
        "/auth/verify", headers={"Authorization": "Bearer invalid"}
    )
    assert resp.status_code == 401
