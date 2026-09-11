import uuid

import pytest

from app.database.pool import get_pool
from app.services.account_deletion import collect_user_image_keys, delete_account_data


@pytest.mark.asyncio
async def test_delete_account_is_idempotent_and_clears_row(setup_db, clean_db, monkeypatch):
    user_id = f"del-{uuid.uuid4().hex[:12]}"
    deleted_keys: list[str] = []

    async def fake_delete(key: str) -> None:
        deleted_keys.append(key)

    async def fake_prefix(_user_id: str) -> None:
        return None

    monkeypatch.setattr("app.services.account_deletion.delete_image", fake_delete)
    monkeypatch.setattr("app.services.account_deletion.delete_user_prefix", fake_prefix)

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO users (id, email, display_name, try_on_photo_key, avatar_base_key)
            VALUES ($1, $2, 'Temp', $3, $4)
            """,
            user_id,
            f"{user_id}@example.com",
            f"users/{user_id}/try_on/photo.jpg",
            f"users/{user_id}/avatar/base.png",
        )
        keys = await collect_user_image_keys(conn, user_id)
        assert f"users/{user_id}/try_on/photo.jpg" in keys

        existed = await delete_account_data(conn, user_id)
        assert existed is True
        gone = await conn.fetchval("SELECT 1 FROM users WHERE id = $1", user_id)
        assert gone is None

        existed_again = await delete_account_data(conn, user_id)
        assert existed_again is False

    assert f"users/{user_id}/try_on/photo.jpg" in deleted_keys
    assert f"users/{user_id}/avatar/base.png" in deleted_keys
