import pytest
from unittest.mock import patch, AsyncMock


@pytest.mark.asyncio
async def test_list_items_empty(client, auth_headers, clean_db):
    resp = await client.get("/items", headers=auth_headers)
    assert resp.status_code == 200
    assert resp.json()["items"] == []
    assert resp.json()["total"] == 0


@pytest.mark.asyncio
async def test_list_items_unauthorized(client):
    resp = await client.get("/items")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_upload_invalid_type(client, auth_headers):
    resp = await client.post(
        "/items/upload",
        headers=auth_headers,
        files={"image": ("test.txt", b"not an image", "text/plain")},
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_get_item_not_found(client, auth_headers, clean_db):
    resp = await client.get(
        "/items/00000000-0000-0000-0000-000000000000", headers=auth_headers
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_item_name_and_notes(
    client, auth_headers, test_item, clean_db
):
    resp = await client.patch(
        f"/items/{test_item}",
        headers=auth_headers,
        json={
            "display_name": "White everyday tee",
            "notes": "Relaxed fit. Best with dark trousers.",
        },
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["display_name"] == "White everyday tee"
    assert data["notes"] == "Relaxed fit. Best with dark trousers."
