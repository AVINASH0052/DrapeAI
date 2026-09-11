"""Tests for notification endpoints."""

import pytest


@pytest.mark.asyncio
async def test_list_notifications(client, auth_headers, clean_db):
    """GET /notifications returns paginated list."""
    resp = await client.get("/notifications", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "notifications" in data
    assert "total" in data
    assert isinstance(data["notifications"], list)


@pytest.mark.asyncio
async def test_push_creates_in_app_notification(client, auth_headers, clean_db):
    """send_push_to_user always writes an in-app notification row."""
    from app.services.push_sender import send_push_to_user

    ok = await send_push_to_user(
        "test-user-001",
        title="Sugatai",
        body="Inbox smoke test",
        deep_link="today_outfits",
    )
    assert ok is False  # no push tokens in clean DB

    resp = await client.get("/notifications", headers=auth_headers)
    assert resp.status_code == 200
    titles = [n["title"] for n in resp.json()["notifications"]]
    assert "Sugatai" in titles
    unread = await client.get("/notifications/unread-count", headers=auth_headers)
    assert unread.json()["unread_count"] >= 1


@pytest.mark.asyncio
async def test_unread_count(client, auth_headers, clean_db):
    """GET /notifications/unread-count returns integer count."""
    resp = await client.get("/notifications/unread-count", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "unread_count" in data
    assert isinstance(data["unread_count"], int)
    assert data["unread_count"] >= 0


@pytest.mark.asyncio
async def test_mark_all_read(client, auth_headers, clean_db):
    """PUT /notifications/read-all succeeds."""
    resp = await client.put("/notifications/read-all", headers=auth_headers)
    assert resp.status_code == 200
    data = resp.json()
    assert "marked_read" in data


@pytest.mark.asyncio
async def test_mark_nonexistent_read(client, auth_headers, clean_db):
    """PUT /notifications/{id}/read with bad ID returns 404."""
    resp = await client.put(
        "/notifications/00000000-0000-0000-0000-000000000000/read",
        headers=auth_headers,
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_notifications_require_auth(client):
    """Notification endpoints without auth return 401."""
    resp = await client.get("/notifications")
    assert resp.status_code == 401
