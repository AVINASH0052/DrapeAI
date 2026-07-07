"""Outfit generation and feedback routes."""

from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.outfits import record_feedback, get_today_outfits
from app.database.queries.preferences import get_preferences
from app.database.queries.items import get_item
from app.models.user import User
from app.services.outfit_service import generate_outfits, shuffle_outfit
from app.services.outfit_chat import refine_outfit
from app.services.storage import get_image_url
from app.services.outfit_visualizer import visualize_outfit, get_outfit_items_from_db

router = APIRouter(prefix="/outfits", tags=["Outfits"])


class GenerateRequest(BaseModel):
    occasion: Literal["casual", "work", "party", "gym", "date", "festive", "travel"]
    weather_override: dict | None = None


class FeedbackRequest(BaseModel):
    action: Literal["like", "dislike", "save", "wear", "skip"]


class RefineRequest(BaseModel):
    message: str


@router.post("/generate")
async def generate(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await generate_outfits(user.id, req.occasion, req.weather_override)
    return result


@router.post("/shuffle")
async def shuffle(req: GenerateRequest, user: User = Depends(get_current_user)):
    result = await shuffle_outfit(user.id, req.occasion)
    return result


@router.post("/{outfit_id}/feedback")
async def submit_feedback(
    outfit_id: str,
    req: FeedbackRequest,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id FROM outfits WHERE id = $1 AND user_id = $2", outfit_id, user.id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")
        await record_feedback(conn, user.id, outfit_id, req.action)
    return {"recorded": True}


@router.get("/today")
async def today(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        outfits = await get_today_outfits(conn, user.id)
    if not outfits:
        return {"outfits": [], "cached": False}
    return {"outfits": outfits, "cached": True}


@router.post("/{outfit_id}/refine")
async def refine(
    outfit_id: str,
    req: RefineRequest,
    user: User = Depends(get_current_user),
):
    """Natural-language outfit refinement. User text → swap items from wardrobe."""
    import json

    if not req.message.strip():
        raise HTTPException(status_code=400, detail="message required")

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT item_ids FROM outfits WHERE id = $1 AND user_id = $2",
            outfit_id, user.id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")

        try:
            item_ids = json.loads(row["item_ids"])
        except (TypeError, json.JSONDecodeError):
            item_ids = []

        outfit_items = []
        for iid in item_ids:
            it = await get_item(conn, iid, user.id)
            if it:
                outfit_items.append(it)

        if not outfit_items:
            raise HTTPException(status_code=400, detail="Outfit has no items")

        prefs = await get_preferences(conn, user.id) or {}
        result = await refine_outfit(conn, user.id, outfit_items, req.message, prefs)

    return result


@router.post("/{outfit_id}/visualize")
async def visualize_outfit_preview(
    outfit_id: str,
    user: User = Depends(get_current_user),
    force: bool = Query(False, description="Regenerate even if cached"),
):
    """Generate a preview image of the user wearing this outfit."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT o.preview_image_key, u.try_on_photo_key
            FROM outfits o
            JOIN users u ON u.id = o.user_id
            WHERE o.id = $1 AND o.user_id = $2
            """,
            outfit_id,
            user.id,
        )
        if not row:
            raise HTTPException(status_code=404, detail="Outfit not found")

        if row["preview_image_key"] and not force:
            return {
                "preview_url": get_image_url(row["preview_image_key"]),
                "cached": True,
                "method": "cached",
            }

        if not row["try_on_photo_key"]:
            raise HTTPException(
                status_code=400,
                detail="Upload a full-body photo in Profile → See me in outfits first.",
            )

        items = await get_outfit_items_from_db(conn, outfit_id, user.id)
        if not items:
            raise HTTPException(status_code=400, detail="Outfit has no items")

        viz = await visualize_outfit(
            user.id,
            outfit_id,
            row["try_on_photo_key"],
            items,
        )

        await conn.execute(
            "UPDATE outfits SET preview_image_key = $1 WHERE id = $2",
            viz.preview_key,
            outfit_id,
        )

    return {
        "preview_url": get_image_url(viz.preview_key),
        "cached": False,
        "method": viz.method,
        "model": viz.model,
    }
