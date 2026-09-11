"""Body-first avatar studio render endpoints."""

from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.models.user import User
from app.routes.outfits import visualize_outfit_preview, visualize_outfit_status
from app.services.avatar_service import (
    delete_avatar_look,
    find_or_create_avatar_outfit,
    parse_fingerprint_meta,
)
from app.services.storage import get_image_url

router = APIRouter(prefix="/avatar", tags=["Avatar"])


class AvatarRenderRequest(BaseModel):
    slots: dict[str, str] = Field(
        min_length=1,
        description="Avatar slot names mapped to owned wardrobe item IDs.",
    )
    pose: str | None = Field(
        default="natural",
        description="standing | walking | three_quarter | natural",
    )
    style: str | None = Field(
        default="studio",
        description="studio | street | festive | editorial",
    )
    quality: str | None = Field(
        default="hd",
        description="standard | hd — inference always uses HD inputs; hd also sharpens prompt",
    )
    force: bool = Field(
        default=False,
        description="Force a fresh AI render even when a cached preview exists.",
    )


@router.post("/render")
async def render_avatar_look(
    request: AvatarRenderRequest,
    user: User = Depends(get_current_user),
):
    """Create or reuse a studio outfit and return its try-on preview.

    Same slot + pose/style/quality + body photo reuses the saved preview
    (no AI call) unless ``force=true``.
    """
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
        look = await find_or_create_avatar_outfit(
            conn,
            user.id,
            request.slots,
            pose=request.pose,
            style=request.style,
            quality=request.quality,
            try_on_photo_key=avatar["try_on_photo_key"],
        )

    # Reuse saved preview for the same look; only regenerate when forced.
    result = await visualize_outfit_preview(
        look.outfit_id, user, force=request.force
    )
    return {
        "outfit_id": look.outfit_id,
        "created": look.created,
        "fingerprint": look.fingerprint,
        **result,
    }


@router.get("/render/{outfit_id}/status")
async def get_avatar_render_status(
    outfit_id: str,
    job_id: str | None = Query(None),
    user: User = Depends(get_current_user),
):
    """Poll a render started from the avatar studio."""
    return await visualize_outfit_status(outfit_id, user, job_id)


@router.get("/history")
async def avatar_look_history(
    user: User = Depends(get_current_user),
    limit: int = Query(24, ge=1, le=50),
):
    """Recent avatar-studio looks with saved previews (newest first)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, item_ids, preview_image_key, llm_reason,
                   slot_fingerprint, created_at
            FROM outfits
            WHERE user_id = $1
              AND occasion = 'avatar studio'
              AND preview_image_key IS NOT NULL
            ORDER BY created_at DESC
            LIMIT $2
            """,
            user.id,
            limit,
        )

    looks = []
    for row in rows:
        meta = parse_fingerprint_meta(row["slot_fingerprint"])
        slots = meta["slots"]
        if not slots:
            # Legacy rows without fingerprint: expose ordered item ids only.
            try:
                item_ids = json.loads(row["item_ids"] or "[]")
            except (TypeError, json.JSONDecodeError):
                item_ids = []
            slots = {f"item_{i}": iid for i, iid in enumerate(item_ids)}
        looks.append(
            {
                "outfit_id": str(row["id"]),
                "preview_url": get_image_url(row["preview_image_key"]),
                "slots": slots,
                "pose": meta["pose"],
                "style": meta["style"],
                "quality": meta["quality"],
                "fingerprint": row["slot_fingerprint"],
                "created_at": row["created_at"].isoformat()
                if row["created_at"]
                else None,
            }
        )
    return {"looks": looks}


@router.delete("/history/{outfit_id}")
async def delete_avatar_look_route(
    outfit_id: str,
    user: User = Depends(get_current_user),
):
    """Remove a saved studio look from Previous looks."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await delete_avatar_look(conn, user.id, outfit_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Look not found")
    return {"deleted": True}
