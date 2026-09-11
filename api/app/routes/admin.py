"""Admin dashboard routes."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from app.auth.admin_auth import get_admin_user
from app.database.pool import get_pool
from app.database.queries import admin as q
from app.models.user import User
from app.routes.health import collect_readiness
from app.services.account_deletion import delete_account_data
from app.services.push_sender import send_push_to_users

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin", tags=["Admin"])


class SuspendRequest(BaseModel):
    suspended: bool


class PatchUserRequest(BaseModel):
    admin_notes: str | None = None
    is_admin: bool | None = None


class FlagItemRequest(BaseModel):
    reason: str | None = None


class PushSendRequest(BaseModel):
    segment_id: str | None = None
    user_ids: list[str] | None = None
    title: str = Field(..., min_length=1, max_length=120)
    body: str = Field(..., min_length=1, max_length=500)
    deep_link: str | None = None


@router.get("/health/readiness")
async def admin_readiness(user: User = Depends(get_admin_user)):
    """Same dependency checks as /ready, behind admin auth."""
    return await collect_readiness()


@router.get("/stats")
async def stats(user: User = Depends(get_admin_user)):
    """KPI overview for admin dashboard."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        return await q.get_admin_stats(conn)


@router.get("/stats/timeseries")
async def stats_timeseries(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    """Daily stats for charts."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await q.get_admin_stats_timeseries(conn, days)
    return {"days": days, "series": data}


@router.get("/users")
async def users_list(
    search: str | None = Query(None),
    onboarding: str | None = Query(None),
    suspended: str | None = Query(None),
    is_admin: str | None = Query(None),
    avatar_status: str | None = Query(None),
    inactive_days: int | None = Query(None, ge=1, le=365),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    """Paginated user list with search and filters."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        users, total = await q.list_admin_users(
            conn,
            search=search,
            onboarding_filter=onboarding,
            suspended=suspended,
            is_admin=is_admin,
            avatar_status=avatar_status,
            inactive_days=inactive_days,
            limit=limit,
            offset=offset,
        )
    return {"users": users, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}")
async def user_detail(user_id: str, user: User = Depends(get_admin_user)):
    """Full user detail with counts and preferences."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        detail = await q.get_admin_user_detail(conn, user_id)
    if not detail:
        raise HTTPException(status_code=404, detail="User not found")
    return detail


@router.patch("/users/{user_id}")
async def patch_user(
    user_id: str,
    body: PatchUserRequest,
    user: User = Depends(get_admin_user),
):
    """Update admin notes and/or is_admin flag."""
    if body.is_admin is False and user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot demote yourself")

    pool = await get_pool()
    async with pool.acquire() as conn:
        payload = body.model_dump(exclude_unset=True)
        updated = await q.update_admin_user(
            conn,
            user_id,
            admin_notes=payload.get("admin_notes"),
            set_admin_notes="admin_notes" in payload,
            is_admin=payload.get("is_admin"),
        )
        if not updated:
            raise HTTPException(status_code=404, detail="User not found")
        await q.write_audit(
            conn,
            user.id,
            "user.patch",
            "user",
            user_id,
            payload,
        )
    return updated


@router.post("/users/{user_id}/reset-onboarding")
async def reset_user_onboarding(user_id: str, user: User = Depends(get_admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await q.reset_onboarding(conn, user_id)
        if not updated:
            raise HTTPException(status_code=404, detail="User not found")
        await q.write_audit(conn, user.id, "user.reset_onboarding", "user", user_id)
    return updated


@router.put("/users/{user_id}/suspend")
async def toggle_suspend(
    user_id: str,
    body: SuspendRequest,
    user: User = Depends(get_admin_user),
):
    """Toggle user suspension."""
    if user_id == user.id and body.suspended:
        raise HTTPException(status_code=400, detail="Cannot suspend yourself")
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await q.suspend_user(conn, user_id, body.suspended)
        if not updated:
            raise HTTPException(status_code=404, detail="User not found")
        await q.write_audit(
            conn,
            user.id,
            "user.suspend" if body.suspended else "user.unsuspend",
            "user",
            user_id,
        )
    logger.info("Admin %s set suspended=%s for user %s", user.id, body.suspended, user_id)
    return updated


@router.delete("/users/{user_id}")
async def remove_user(user_id: str, user: User = Depends(get_admin_user)):
    """Hard delete a user and all related data."""
    if user_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot delete yourself")
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Confirm exists first
        exists = await conn.fetchval("SELECT 1 FROM users WHERE id = $1", user_id)
        if not exists:
            raise HTTPException(status_code=404, detail="User not found")
        await q.write_audit(conn, user.id, "user.delete", "user", user_id)
        deleted = await delete_account_data(conn, user_id)
        if not deleted:
            raise HTTPException(status_code=404, detail="User not found")
    logger.info("Admin %s deleted user %s", user.id, user_id)
    return {"deleted": True}


@router.get("/users/{user_id}/items")
async def user_items(
    user_id: str,
    limit: int = Query(40, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await q.list_user_items(conn, user_id, limit, offset)
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}/outfits")
async def user_outfits(
    user_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        outfits, total = await q.list_user_outfits(conn, user_id, limit, offset)
    return {"outfits": outfits, "total": total, "limit": limit, "offset": offset}


@router.get("/users/{user_id}/lookbooks")
async def user_lookbooks(user_id: str, user: User = Depends(get_admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        lookbooks = await q.list_user_lookbooks(conn, user_id)
    return {"lookbooks": lookbooks}


@router.get("/users/{user_id}/activity")
async def user_activity(
    user_id: str,
    limit: int = Query(50, ge=1, le=200),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        events = await q.list_user_activity(conn, user_id, limit)
    return {"events": events}


@router.get("/users/{user_id}/try-ons")
async def user_try_ons(
    user_id: str,
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await q.list_user_try_ons(conn, user_id, limit, offset)
    return data


@router.get("/items")
async def items_list(
    search: str | None = Query(None),
    category: str | None = Query(None),
    flagged: str | None = Query(None),
    user_id: str | None = Query(None),
    limit: int = Query(40, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await q.list_admin_items(
            conn,
            search=search,
            category=category,
            flagged=flagged,
            user_id=user_id,
            limit=limit,
            offset=offset,
        )
    return {"items": items, "total": total, "limit": limit, "offset": offset}


@router.post("/items/{item_id}/flag")
async def flag_item_route(
    item_id: str,
    body: FlagItemRequest,
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await q.flag_item(conn, item_id, True, body.reason)
        if not updated:
            raise HTTPException(status_code=404, detail="Item not found")
        await q.write_audit(
            conn,
            user.id,
            "item.flag",
            "item",
            item_id,
            {"reason": body.reason},
        )
    return updated


@router.post("/items/{item_id}/unflag")
async def unflag_item_route(item_id: str, user: User = Depends(get_admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await q.flag_item(conn, item_id, False)
        if not updated:
            raise HTTPException(status_code=404, detail="Item not found")
        await q.write_audit(conn, user.id, "item.unflag", "item", item_id)
    return updated


@router.delete("/items/{item_id}")
async def soft_delete_item_route(item_id: str, user: User = Depends(get_admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        updated = await q.soft_delete_item(conn, item_id)
        if not updated:
            raise HTTPException(status_code=404, detail="Item not found")
        await q.write_audit(conn, user.id, "item.soft_delete", "item", item_id)
    return updated


@router.get("/ai-usage")
async def ai_usage(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    """AI usage stats by provider (aggregated for charts)."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        data = await q.get_ai_usage(conn, days)
    return {"days": days, "usage": data}


@router.get("/analytics/overview")
async def analytics_overview(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        return await q.get_analytics_overview(conn, days)


@router.get("/analytics/costs")
async def analytics_costs(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        series = await q.get_analytics_costs(conn, days)
    return {"days": days, "series": series}


@router.get("/analytics/usage")
async def analytics_usage(
    days: int = Query(30, ge=1, le=365),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        series = await q.get_analytics_usage(conn, days)
    return {"days": days, "series": series}


@router.get("/analytics/top-users")
async def analytics_top_users(
    metric: str = Query("items"),
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(20, ge=1, le=100),
    user: User = Depends(get_admin_user),
):
    if metric not in ("items", "outfits", "cost"):
        raise HTTPException(
            status_code=400, detail="metric must be items, outfits, or cost"
        )
    # cost metric not tracked per-user yet — fall back to items
    use_metric = "items" if metric == "cost" else metric
    pool = await get_pool()
    async with pool.acquire() as conn:
        users = await q.get_top_users(conn, use_metric, days, limit)
    return {"metric": use_metric, "users": users}


@router.get("/waitlist")
async def waitlist(
    search: str | None = Query(None),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_admin_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        entries, total = await q.list_waitlist(conn, search, limit, offset)
    return {"entries": entries, "total": total, "limit": limit, "offset": offset}


@router.get("/push/segments")
async def push_segments(user: User = Depends(get_admin_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        segments = await q.get_push_segments(conn)
    return {"segments": segments}


@router.post("/push/send")
async def push_send(body: PushSendRequest, user: User = Depends(get_admin_user)):
    if not body.segment_id and not body.user_ids:
        raise HTTPException(
            status_code=400, detail="Provide segment_id or user_ids"
        )

    pool = await get_pool()
    async with pool.acquire() as conn:
        if body.user_ids:
            user_ids = list(dict.fromkeys(body.user_ids))
        else:
            user_ids = await q.resolve_push_segment_user_ids(conn, body.segment_id or "")
            if not user_ids and body.segment_id:
                # unknown segment returns empty; distinguish missing segment
                known = {s["id"] for s in await q.get_push_segments(conn)}
                if body.segment_id not in known:
                    raise HTTPException(status_code=400, detail="Unknown segment")

    sent = await send_push_to_users(
        user_ids,
        title=body.title,
        body=body.body,
        deep_link=body.deep_link,
    )

    pool = await get_pool()
    async with pool.acquire() as conn:
        await q.write_audit(
            conn,
            user.id,
            "push.send",
            "segment" if body.segment_id else "users",
            body.segment_id,
            {
                "title": body.title,
                "requested": len(user_ids),
                "sent": sent,
            },
        )

    return {"requested": len(user_ids), "sent": sent}


@router.get("/system-health")
async def system_health(user: User = Depends(get_admin_user)):
    """System health check: DB connectivity + table row counts."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        return await q.get_system_health(conn)
