"""Body-first avatar studio render endpoints."""

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User
from app.routes.outfits import visualize_outfit_preview, visualize_outfit_status
from app.services.avatar_service import create_avatar_outfit

router = APIRouter(prefix="/avatar", tags=["Avatar"])


class AvatarRenderRequest(BaseModel):
    slots: dict[str, str] = Field(
        min_length=1,
        description="Avatar slot names mapped to owned wardrobe item IDs.",
    )


@router.post("/render")
async def render_avatar_look(
    request: AvatarRenderRequest,
    user: User = Depends(get_current_user),
):
    """Create a manual outfit from owned items and start its try-on render."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        avatar = await conn.fetchrow(
            """
            SELECT avatar_status, try_on_photo_key
            FROM users
            WHERE id = $1
            """,
            user.id,
        )
        if not avatar or not avatar["try_on_photo_key"]:
            raise HTTPException(
                status_code=409,
                detail="Add a full-body photo before rendering a look.",
            )
        if avatar["avatar_status"] != "ready":
            raise HTTPException(
                status_code=409,
                detail="Your avatar is still being prepared. Try again shortly.",
            )
        outfit_id = await create_avatar_outfit(conn, user.id, request.slots)

    result = await visualize_outfit_preview(outfit_id, user, force=False)
    return {"outfit_id": outfit_id, **result}


@router.get("/render/{outfit_id}/status")
async def get_avatar_render_status(
    outfit_id: str,
    job_id: str | None = Query(None),
    user: User = Depends(get_current_user),
):
    """Poll a render started from the avatar studio."""
    return await visualize_outfit_status(outfit_id, user, job_id)
