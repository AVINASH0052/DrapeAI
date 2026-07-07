"""Push notification token registration."""

from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User

router = APIRouter(prefix="/push", tags=["Push"])


class RegisterTokenRequest(BaseModel):
    token: str
    platform: Literal["android", "ios"]


@router.post("/register")
async def register_token(
    req: RegisterTokenRequest, user: User = Depends(get_current_user)
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO push_tokens (id, user_id, token, platform)
            VALUES (gen_random_uuid(), $1, $2, $3)
            ON CONFLICT (user_id, platform)
            DO UPDATE SET token = $2, updated_at = NOW()
            """,
            user.id,
            req.token,
            req.platform,
        )
    return {"registered": True}


@router.delete("/unregister")
async def unregister_token(user: User = Depends(get_current_user)):
    """Deactivate all push tokens for the current user (called on sign-out)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE push_tokens SET is_active = FALSE WHERE user_id = $1",
            user.id,
        )
    return {"unregistered": True}
