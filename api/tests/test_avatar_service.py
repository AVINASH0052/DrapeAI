"""Avatar-studio ownership, slot, and look-cache tests."""

import uuid
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.auth.firebase import verify_firebase_token
from app.services.avatar_service import (
    create_avatar_outfit,
    delete_avatar_look,
    find_or_create_avatar_outfit,
    look_fingerprint,
    parse_fingerprint_meta,
)


class FakeConnection:
    def __init__(self, rows, existing=None):
        self.rows = rows
        self.existing = existing
        self.executed = []
        self.fetchrow_calls = []

    async def fetch(self, _query, _user_id, _item_ids):
        return self.rows

    async def fetchrow(self, query, *args):
        self.fetchrow_calls.append((query, args))
        return self.existing

    async def execute(self, query, *args):
        self.executed.append((query, args))
        return "UPDATE 1"


def item_row(item_id, category="top", sub_category="t-shirt", status="ready"):
    return {
        "id": uuid.UUID(item_id),
        "category": category,
        "sub_category": sub_category,
        "processing_status": status,
    }


def test_look_fingerprint_stable_and_includes_slots():
    top = str(uuid.uuid4())
    fp1 = look_fingerprint(
        {"tops": top},
        pose="natural",
        style="studio",
        quality="hd",
        try_on_photo_key="users/u/body.jpg",
    )
    fp2 = look_fingerprint(
        {"tops": top},
        pose="natural",
        style="studio",
        quality="hd",
        try_on_photo_key="users/u/body.jpg",
    )
    assert fp1 == fp2
    assert f"tops={top}" in fp1
    assert "photo=users/u/body.jpg" in fp1

    fp_other = look_fingerprint(
        {"tops": top},
        pose="walking",
        style="studio",
        quality="hd",
        try_on_photo_key="users/u/body.jpg",
    )
    assert fp1 != fp_other


def test_parse_fingerprint_meta_roundtrip():
    top = str(uuid.uuid4())
    bottom = str(uuid.uuid4())
    fp = look_fingerprint(
        {"tops": top, "bottoms": bottom},
        pose="standing",
        style="street",
        quality="hd",
        try_on_photo_key="photo-key",
    )
    meta = parse_fingerprint_meta(fp)
    assert meta["slots"] == {"tops": top, "bottoms": bottom}
    assert meta["pose"] == "standing"
    assert meta["style"] == "street"
    assert meta["quality"] == "hd"


@pytest.mark.asyncio
async def test_avatar_render_rejects_conflicting_dress_and_top():
    conn = FakeConnection([])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(
            conn,
            "user-1",
            {"dresses": str(uuid.uuid4()), "tops": str(uuid.uuid4())},
            try_on_photo_key="photo",
        )
    assert exc.value.status_code == 400
    assert "cannot be combined" in exc.value.detail


@pytest.mark.asyncio
async def test_avatar_render_enforces_item_ownership():
    item_id = str(uuid.uuid4())
    conn = FakeConnection([])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(
            conn, "user-1", {"tops": item_id}, try_on_photo_key="photo"
        )
    assert exc.value.status_code == 404


@pytest.mark.asyncio
async def test_avatar_render_rejects_wrong_slot_and_processing_item():
    item_id = str(uuid.uuid4())
    conn = FakeConnection([item_row(item_id, category="bottom")])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(
            conn, "user-1", {"tops": item_id}, try_on_photo_key="photo"
        )
    assert exc.value.status_code == 400

    conn = FakeConnection([item_row(item_id, status="processing")])
    with pytest.raises(HTTPException) as exc:
        await create_avatar_outfit(
            conn, "user-1", {"tops": item_id}, try_on_photo_key="photo"
        )
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
        try_on_photo_key="users/u/body.jpg",
    )
    assert uuid.UUID(outfit_id)
    assert len(conn.executed) == 1
    assert "'manual'" in conn.executed[0][0]
    assert "slot_fingerprint" in conn.executed[0][0]


@pytest.mark.asyncio
async def test_find_or_create_reuses_existing_fingerprint():
    top_id = str(uuid.uuid4())
    existing_id = uuid.uuid4()
    conn = FakeConnection(
        [item_row(top_id)],
        existing={"id": existing_id, "preview_image_key": "users/u/previews/x.png"},
    )
    result = await find_or_create_avatar_outfit(
        conn,
        "user-1",
        {"tops": top_id},
        pose="natural",
        style="studio",
        quality="hd",
        try_on_photo_key="users/u/body.jpg",
    )
    assert result.outfit_id == str(existing_id)
    assert result.created is False
    assert result.has_preview is True
    assert conn.executed == []


@pytest.mark.asyncio
async def test_delete_avatar_look_is_owner_scoped():
    conn = FakeConnection([])
    outfit_id = str(uuid.uuid4())
    ok = await delete_avatar_look(conn, "user-1", outfit_id)
    assert ok is True
    sql, args = conn.executed[0]
    assert "preview_image_key = NULL" in sql
    assert "user_id = $2" in sql
    assert args[0] == outfit_id
    assert args[1] == "user-1"


@pytest.mark.asyncio
async def test_test_token_is_rejected_outside_development():
    with patch("app.auth.firebase.settings.environment", "production"):
        with pytest.raises(ValueError, match="not accepted"):
            await verify_firebase_token("test-token")
