"""Tests for calendar endpoints."""

import pytest


@pytest.mark.asyncio
async def test_calendar_month_empty(client, auth_headers, clean_db):
    resp = await client.get(
        "/calendar", headers=auth_headers, params={"month": "2026-07"}
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["month"] == "2026-07"
    assert "entries" in data


@pytest.mark.asyncio
async def test_assign_outfit_to_date(
    client, auth_headers, test_outfit, clean_db
):
    resp = await client.post(
        "/calendar/2026-07-15",
        headers=auth_headers,
        json={"outfit_id": test_outfit},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "assigned"

    month = await client.get(
        "/calendar", headers=auth_headers, params={"month": "2026-07"}
    )
    entries = month.json()["entries"]
    assert any(e["date"] == "2026-07-15" for e in entries)
