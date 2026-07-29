"""Avatar-studio ownership, slot, and development-token tests."""

import uuid
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.auth.firebase import verify_firebase_token
from app.services.avatar_service import create_avatar_outfit


class FakeConnection:
    def __init__(self, rows):
        self.rows = rows
        self.executed = []

    async def fetch(self, _query, _user_id, _item_ids):
        return self.rows

    async def execute(self, query, *args):
        self.executed.append((query, args))


def item_row(item_id, category="top", sub_category="t-shirt", status="ready"):
    return {
        "id": uuid.UUID(item_id),
        "category": category,
        "sub_category": sub_category,
        "processing_status": status,
    }


@pytest.mark.asyncio
async def test_avatar_render_rejects_conflicting_dress_and_top():
    conn = FakeConnection([])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(
            conn,
            "user-1",
            {"dresses": str(uuid.uuid4()), "tops": str(uuid.uuid4())},
        )
    assert exc.value.status_code == 400
    assert "cannot be combined" in exc.value.detail


@pytest.mark.asyncio
async def test_avatar_render_enforces_item_ownership():
    item_id = str(uuid.uuid4())
    conn = FakeConnection([])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(conn, "user-1", {"tops": item_id})
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_avatar_render_rejects_wrong_slot_and_processing_item():
    item_id = str(uuid.uuid4())
    conn = FakeConnection([item_row(item_id, category="bottom")])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(conn, "user-1", {"tops": item_id})
    assert exc.value.status_code == 400

    conn = FakeConnection([item_row(item_id, status="processing")])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(conn, "user-1", {"tops": item_id})
    assert exc.value.status_code == 409


@pytest.mark.asyncio
async def test_avatar_render_saves_owned_compatible_items():
    top_id = str(uuid.uuid4())
    shoe_id = str(uuid.uuid4())
    conn = FakeConnection(
        [
            item_row(top_id),
            item_row(shoe_id, category="shoes", sub_category="sneakers"),
        ]
    )
    outfit_id = await create_avatar_outfit(
        conn,
        "user-1",
        {"tops": top_id, "footwear": shoe_id},
    )
    assert uuid.UUID(outfit_id)
    assert len(conn.executed) == 1
    assert "'manual'" in conn.executed[0][0]


@pytest.mark.asyncio
async def test_test_token_is_rejected_outside_development():
    with patch("app.auth.firebase.settings.environment", "production"):
        with pytest.raises(ValueError, match="not accepted"):
            await verify_firebase_token("test-token")
