"""Tests for lookbook CRUD endpoints."""

import pytest


@pytest.mark.asyncio
async def test_create_lookbook(client, auth_headers, clean_db):
    resp = await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "Summer Vibes"}
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Summer Vibes"
    assert "id" in data
    assert data["user_id"] == "test-user-001"


@pytest.mark.asyncio
async def test_list_lookbooks(client, auth_headers, clean_db):
    # Create two lookbooks first
    await client.post("/lookbooks", headers=auth_headers, json={"name": "Work Fits"})
    await client.post("/lookbooks", headers=auth_headers, json={"name": "Weekend"})

    resp = await client.get("/lookbooks", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "lookbooks" in data
    assert len(data["lookbooks"]) >= 2
    names = [lb["name"] for lb in data["lookbooks"]]
    assert "Work Fits" in names
    assert "Weekend" in names


@pytest.mark.asyncio
async def test_get_lookbook_detail(client, auth_headers, clean_db):
    # Create a lookbook
    create_resp = await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "Detail Test"}
    )
    lb_id = create_resp.json()["id"]

    resp = await client.get(f"/lookbooks/{lb_id}", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Detail Test"
    assert "outfits" in data
    assert isinstance(data["outfits"], list)


@pytest.mark.asyncio
async def test_get_lookbook_not_found(client, auth_headers, clean_db):
    resp = await client.get(
        "/lookbooks/00000000-0000-0000-0000-000000000000", headers=auth_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_lookbook(client, auth_headers, clean_db):
    # Create then delete
    create_resp = await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "To Delete"}
    )
    lb_id = create_resp.json()["id"]

    resp = await client.delete(f"/lookbooks/{lb_id}", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["deleted"] is True

    # Verify it's gone
    resp = await client.get(f"/lookbooks/{lb_id}", headers=auth_headers)
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_lookbook_not_found(client, auth_headers, clean_db):
    resp = await client.delete(
        "/lookbooks/00000000-0000-0000-0000-000000000000", headers=auth_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_duplicate_name_conflict(client, auth_headers, clean_db):
    """Creating a lookbook with a duplicate name should fail (unique constraint)."""
    await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "Unique Name"}
    )
    resp = await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "Unique Name"}
    )
    # Unique constraint violation surfaces as 500 (asyncpg UniqueViolationError)
    assert resp.status_code in (409, 500)


@pytest.mark.asyncio
async def test_rename_lookbook(client, auth_headers, clean_db):
    create_resp = await client.post(
        "/lookbooks", headers=auth_headers, json={"name": "Old Name"}
    )
    lb_id = create_resp.json()["id"]

    resp = await client.patch(
        f"/lookbooks/{lb_id}", headers=auth_headers, json={"name": "New Name"}
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "New Name"


@pytest.mark.asyncio
async def test_create_lookbook_unauthorized(client):
    resp = await client.post("/lookbooks", json={"name": "No Auth"})
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_list_lookbooks_unauthorized(client):
    resp = await client.get("/lookbooks")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_get_lookbook_unauthorized(client):
    resp = await client.get("/lookbooks/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_delete_lookbook_unauthorized(client):
    resp = await client.delete("/lookbooks/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 401
