"""Item routes: upload, list, get, update, delete."""

import logging

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.items import get_items, get_item, update_item, soft_delete_item
from app.models.user import User
from app.models.item import ItemUpdate
from app.services.pairing import get_pairings
from app.services.storage import get_image_url
from app.utils.image_validation import validate_image

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/items", tags=["Items"])


@router.post("/upload", status_code=201)
async def upload_item(
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Upload a clothing item. Backend: remove background, tag with GPT-4o, store."""
    file_bytes = await image.read()
    validate_image(image.content_type, file_bytes)

    from app.services.upload_pipeline import process_upload

    result = await process_upload(user.id, file_bytes, image.content_type)
    return result


@router.get("")
async def list_items(
    category: str | None = Query(None),
    color: str | None = Query(None),
    season: str | None = Query(None),
    ethnic: bool | None = Query(None),
    search: str | None = Query(None),
    sort: str = Query("newest"),
    limit: int = Query(50, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await get_items(
            conn, user.id, category, color, season, ethnic, search, sort, limit, offset
        )

    for item in items:
        item["image_url"] = get_image_url(item["image_url"])

    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/{item_id}")
async def get_single_item(item_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await get_item(conn, item_id, user.id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    item["image_url"] = get_image_url(item["image_url"])
    return item


@router.patch("/{item_id}")
async def update_single_item(
    item_id: str,
    updates: ItemUpdate,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        item = await update_item(conn, item_id, user.id, updates.model_dump(exclude_none=True))
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")

    # Invalidate outfit cache when tags change
    if any(
        getattr(updates, field) is not None
        for field in ("category", "primary_color", "formality", "season_tags")
    ):
        from app.database.queries.outfit_cache import invalidate_user_cache
        async with pool.acquire() as conn:
            await invalidate_user_cache(conn, user.id)

    # Re-generate embedding if descriptive tags changed
    if updates.category or updates.primary_color:
        from app.services.upload_pipeline import regenerate_embedding
        import asyncio

        asyncio.create_task(regenerate_embedding(item_id))

    item["image_url"] = get_image_url(item["image_url"])
    return item


@router.delete("/{item_id}")
async def delete_single_item(item_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await soft_delete_item(conn, item_id, user.id)
        if deleted:
            from app.database.queries.outfit_cache import invalidate_user_cache
            await invalidate_user_cache(conn, user.id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"deleted": True}


@router.get("/{item_id}/pairings")
async def list_pairings(
    item_id: str,
    limit: int = Query(5, ge=1, le=10),
    user: User = Depends(get_current_user),
):
    """Top wardrobe items that pair with this one (embedding + rules + history)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        pairings = await get_pairings(conn, item_id, user.id, limit=limit)
    return {"pairings": pairings}
