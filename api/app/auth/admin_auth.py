"""Admin authentication dependency."""

from fastapi import Depends, HTTPException

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User


async def get_admin_user(user: User = Depends(get_current_user)) -> User:
    """Verify the current user has admin privileges.

    Usage in any admin route:
        @router.get("/admin/stats")
        async def stats(user: User = Depends(get_admin_user)):
    """
    pool = await get_pool()
    async with pool.acquire() as conn:
        is_admin = await conn.fetchval(
            "SELECT is_admin FROM users WHERE id = $1",
            user.id,
        )

    if not is_admin:
        raise HTTPException(
            status_code=403,
            detail="Admin access required",
        )

    return user
