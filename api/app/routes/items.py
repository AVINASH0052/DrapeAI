"""Item routes: upload, list, get, update, delete."""

import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, UploadFile, File, Query

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
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Accept a clothing photo immediately; AI tagging runs in the background."""
    file_bytes = await image.read()
    validate_image(image.content_type, file_bytes)

    from app.services.upload_pipeline import (
        accept_upload,
        enqueue_upload_job,
        run_upload_pipeline_standalone,
    )

    result = await accept_upload(user.id, file_bytes, image.content_type)
    for piece in result.get("items") or [result]:
        enqueued = await enqueue_upload_job(piece["id"], user.id)
        if not enqueued:
            background_tasks.add_task(
                run_upload_pipeline_standalone, piece["id"], user.id
            )
    return result


@router.post("/upload/batch", status_code=201)
async def upload_items_batch(
    background_tasks: BackgroundTasks,
    images: list[UploadFile] = File(...),
    user: User = Depends(get_current_user),
):
    """Upload multiple clothing photos (max 10). Each photo may become several items."""
    if not images:
        raise HTTPException(status_code=400, detail="No images provided")
    if len(images) > 10:
        raise HTTPException(status_code=400, detail="Maximum 10 images per batch")

    from app.services.upload_pipeline import (
        accept_upload,
        enqueue_upload_job,
        run_upload_pipeline_standalone,
    )

    results = []
    errors = []
    total_items = 0
    for i, image in enumerate(images):
        try:
            file_bytes = await image.read()
            validate_image(image.content_type, file_bytes)
            result = await accept_upload(user.id, file_bytes, image.content_type)
            pieces = result.get("items") or [result]
            total_items += len(pieces)
            for piece in pieces:
                enqueued = await enqueue_upload_job(piece["id"], user.id)
                if not enqueued:
                    background_tasks.add_task(
                        run_upload_pipeline_standalone, piece["id"], user.id
                    )
            results.extend(pieces)
        except HTTPException as e:
            errors.append({"index": i, "detail": e.detail})
        except Exception as e:
            errors.append({"index": i, "detail": str(e)})

    return {
        "uploaded": total_items,
        "failed": len(errors),
        "items": results,
        "errors": errors,
    }


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
    background_tasks: BackgroundTasks,
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

        background_tasks.add_task(regenerate_embedding, item_id)

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
