"""Shared helpers for try-on / avatar tests."""

from app.database.pool import get_pool


async def mark_avatar_ready(user_id: str = "test-user-001") -> None:
    """Mark the user's avatar prepared.

    Uploading a body photo is async (202) and avatar prep runs in the
    background, while visualize requires ``avatar_status='ready'``. Avatar
    prep itself is covered by test_avatar_analysis / test_avatar_service, so
    tests that only exercise visualize short-circuit it here instead of
    depending on background-task timing.
    """
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET avatar_status = 'ready', avatar_error = NULL WHERE id = $1",
            user_id,
        )


async def set_avatar_state(
    status: str, error: str | None = None, user_id: str = "test-user-001"
) -> None:
    """Force a specific avatar preparation state."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET avatar_status = $2, avatar_error = $3 WHERE id = $1",
            user_id,
            status,
            error,
        )
