"""Notification routes: list, read, mark-all-read, unread count."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.notifications import (
    get_notifications,
    get_unread_count,
    mark_notification_read,
    mark_all_read,
)
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("")
async def list_notifications(
    limit: int = Query(30, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_user),
):
    """Get paginated notifications for the current user."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await get_notifications(conn, user.id, limit, offset)
    return {"notifications": items, "total": total, "limit": limit, "offset": offset}


@router.get("/unread-count")
async def unread_notification_count(user: User = Depends(get_current_user)):
    """Get count of unread notifications (for badge display)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        count = await get_unread_count(conn, user.id)
    return {"unread_count": count}


@router.put("/{notification_id}/read")
async def read_notification(
    notification_id: str,
    user: User = Depends(get_current_user),
):
    """Mark a single notification as read."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        found = await mark_notification_read(conn, notification_id, user.id)
    if not found:
        raise HTTPException(status_code=404, detail="Notification not found")
    return {"read": True}


@router.put("/read-all")
async def read_all_notifications(user: User = Depends(get_current_user)):
    """Mark all notifications as read."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        count = await mark_all_read(conn, user.id)
    return {"marked_read": count}
