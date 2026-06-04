"""Admin dashboard routes."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.auth.admin_auth import get_admin_user
from app.database.pool import get_pool
from app.database.queries.admin import (
    get_admin_stats,
    get_admin_stats_timeseries,
    list_admin_users,
    get_admin_user_detail,
    suspend_user,
    delete_user,
    get_ai_usage,
    get_system_health,
)
from app.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin"])


class SuspendRequest(BaseModel):
    suspended: bool


@router.get("/stats")
async def stats(user: User = Depends(get_admin_user)):
    """KPI overview for admin dashboard."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await get_admin_stats(conn)
    return data


@router.get("/stats/timeseries")
async def stats_timeseries(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    """Daily stats for charts."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await get_admin_stats_timeseries(conn, days)
    return {"days": days, "series": data}


@router.get("/users")
async def users_list(
    search: str | None = Query(None),
    onboarding: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    """Paginated user list with search."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        users, total = await list_admin_users(conn, search, onboarding, limit, offset)
    return {"users": users, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}")
async def user_detail(user_id: str, user: User = Depends(get_admin_user)):
    """Full user detail with counts and preferences."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        detail = await get_admin_user_detail(conn, user_id)
    if not detail:
        raise HTTPException(status_code=404, detail="User not found")
    return detail


@router.put("/users/{user_id}/suspend")
async def toggle_suspend(
    user_id: str,
    body: SuspendRequest,
    user: User = Depends(get_admin_user),
):
    """Toggle user suspension."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await suspend_user(conn, user_id, body.suspended)
    if not updated:
        raise HTTPException(status_code=404, detail="User not found")
    logger.info("Admin %s set suspended=%s for user %s", user.id, body.suspended, user_id)
    return updated


@router.delete("/users/{user_id}")
async def remove_user(user_id: str, user: User = Depends(get_admin_user)):
    """Hard delete a user and all related data."""
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    pool = await get_pool()
    async with pool.acquire() as conn:
        deleted = await delete_user(conn, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="User not found")
    logger.info("Admin %s deleted user %s", user.id, user_id)
    return {"deleted": True}


@router.get("/ai-usage")
async def ai_usage(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    """AI usage stats by provider per day."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await get_ai_usage(conn, days)
    return {"days": days, "usage": data}


@router.get("/system-health")
async def system_health(user: User = Depends(get_admin_user)):
    """System health check: DB connectivity + table row counts."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        health = await get_system_health(conn)
    return health
