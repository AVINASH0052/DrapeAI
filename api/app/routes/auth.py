"""Auth routes."""

from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify")
async def verify_token(user: User = Depends(get_current_user)):
    """Client calls this after Firebase login to confirm backend connectivity."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        avatar = await conn.fetchrow(
            """
            SELECT try_on_photo_key, avatar_status
            FROM users
            WHERE id = $1
            """,
            user.id,
        )
    has_body_photo = bool(avatar and avatar["try_on_photo_key"])
    return {
        "user_id": user.id,
        "display_name": user.display_name,
        "onboarding_done": user.onboarding_done,
        "has_body_photo": has_body_photo,
        "avatar_status": avatar["avatar_status"] if avatar else "missing",
    }
