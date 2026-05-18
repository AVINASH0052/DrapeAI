"""Lookbook CRUD routes."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.lookbooks import (
    create_lookbook,
    get_lookbooks,
    get_lookbook_with_outfits,
    rename_lookbook,
    delete_lookbook,
    add_outfit_to_lookbook,
    remove_outfit_from_lookbook,
)
from app.models.user import User

router = APIRouter(prefix="/lookbooks", tags=["Lookbooks"])


class CreateLookbookRequest(BaseModel):
    name: str


class RenameLookbookRequest(BaseModel):
    name: str


@router.post("", status_code=201)
async def create(req: CreateLookbookRequest, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await create_lookbook(conn, user.id, req.name)
    return lb


@router.get("")
async def list_all(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lbs = await get_lookbooks(conn, user.id)
    return {"lookbooks": lbs}


@router.get("/{lookbook_id}")
async def get_one(lookbook_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await get_lookbook_with_outfits(conn, lookbook_id, user.id)
    if not lb:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return lb


@router.patch("/{lookbook_id}")
async def rename(
    lookbook_id: str,
    req: RenameLookbookRequest,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lb = await rename_lookbook(conn, lookbook_id, user.id, req.name)
    if not lb:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return lb


@router.delete("/{lookbook_id}")
async def delete(lookbook_id: str, user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await delete_lookbook(conn, lookbook_id, user.id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return {"deleted": True}


@router.post("/{lookbook_id}/outfits/{outfit_id}")
async def add_outfit(
    lookbook_id: str, outfit_id: str, user: User = Depends(get_current_user)
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        added = await add_outfit_to_lookbook(conn, lookbook_id, outfit_id, user.id)
    if not added:
        raise HTTPException(status_code=404, detail="Lookbook or outfit not found")
    return {"saved": True, "lookbook_id": lookbook_id}


@router.delete("/{lookbook_id}/outfits/{outfit_id}")
async def remove_outfit(
    lookbook_id: str, outfit_id: str, user: User = Depends(get_current_user)
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        removed = await remove_outfit_from_lookbook(conn, lookbook_id, outfit_id, user.id)
    if not removed:
        raise HTTPException(status_code=404, detail="Lookbook not found")
    return {"removed": True}
