"""User profile, preferences, and body-first avatar routes."""

import json

from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, UploadFile

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.preferences import upsert_preferences, get_preferences
from app.models.user import User
from app.models.preferences import PreferencesInput, PreferencesResponse
from app.services.avatar_analysis import (
    enqueue_avatar_analysis,
    run_avatar_analysis,
    sanitize_avatar_source,
)
from app.services.storage import delete_image, get_image_url, upload_try_on_photo
from app.utils.image_validation import validate_image

router = APIRouter(tags=["User"])


@router.get("/me")
async def get_profile(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT try_on_photo_key, avatar_status, avatar_base_key,
                   avatar_profile, avatar_error, avatar_analyzed_at
            FROM users
            WHERE id = $1
            """,
            user.id,
        )
    try_on_key = row["try_on_photo_key"] if row else None
    avatar_key = row["avatar_base_key"] if row else None
    return {
        "id": user.id,
        "display_name": user.display_name,
        "email": user.email,
        "phone": user.phone,
        "photo_url": user.photo_url,
        "try_on_photo_url": get_image_url(try_on_key) if try_on_key else None,
        "avatar_status": row["avatar_status"] if row else "missing",
        "avatar_base_url": (
            get_image_url(avatar_key or try_on_key) if (avatar_key or try_on_key) else None
        ),
        "avatar_profile": row["avatar_profile"] if row else {},
        "avatar_error": row["avatar_error"] if row else None,
        "avatar_analyzed_at": row["avatar_analyzed_at"] if row else None,
        "onboarding_done": user.onboarding_done,
    }


@router.patch("/me")
async def update_profile(
    updates: dict,
    user: User = Depends(get_current_user),
):
    allowed = {"display_name", "photo_url"}
    filtered = {k: v for k, v in updates.items() if k in allowed}
    if not filtered:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    pool = await get_pool()
    async with pool.acquire() as conn:
        set_clause = ", ".join(f"{k} = ${i + 2}" for i, k in enumerate(filtered))
        values = [user.id] + list(filtered.values())
        await conn.execute(
            f"UPDATE users SET {set_clause} WHERE id = $1",
            *values,
        )
    return {"updated": True}


@router.put("/me/preferences")
async def save_preferences(
    prefs: PreferencesInput,
    user: User = Depends(get_current_user),
):
    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await upsert_preferences(conn, user.id, prefs.model_dump())
        await conn.execute(
            "UPDATE users SET onboarding_done = true WHERE id = $1", user.id
        )
    return PreferencesResponse(**result)


@router.get("/me/preferences")
async def get_user_preferences(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        prefs = await get_preferences(conn, user.id)
    if not prefs:
        raise HTTPException(
            status_code=404,
            detail="Preferences not set. Complete onboarding first.",
        )
    return PreferencesResponse(**prefs)


@router.delete("/me")
async def delete_account(user: User = Depends(get_current_user)):
    """Hard-delete the user account. CASCADE removes all related data."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT try_on_photo_key, avatar_base_key FROM users WHERE id = $1",
            user.id,
        )
        if row:
            for key in (row["try_on_photo_key"], row["avatar_base_key"]):
                if key:
                    await delete_image(key)
        await conn.execute("DELETE FROM users WHERE id = $1", user.id)
    return {"deleted": True}


@router.post("/me/try-on-photo", status_code=202)
async def upload_try_on_photo_route(
    background_tasks: BackgroundTasks,
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Save a full-body source photo and prepare its avatar asynchronously."""
    file_bytes = await image.read()
    validate_image(image.content_type, file_bytes)
    file_bytes = await sanitize_avatar_source(file_bytes)

    key = await upload_try_on_photo(user.id, file_bytes, "image/jpeg")

    pool = await get_pool()
    async with pool.acquire() as conn:
        old = await conn.fetchrow(
            "SELECT try_on_photo_key, avatar_base_key FROM users WHERE id = $1",
            user.id,
        )
        await conn.execute(
            """
            UPDATE users
            SET try_on_photo_key = $1,
                avatar_status = 'queued',
                avatar_profile = '{}'::jsonb,
                avatar_error = NULL,
                avatar_analyzed_at = NULL
            WHERE id = $2
            """,
            key,
            user.id,
        )
    if old:
        for old_key in (old["try_on_photo_key"], old["avatar_base_key"]):
            if old_key and old_key != key:
                await delete_image(old_key)

    if not await enqueue_avatar_analysis(user.id):
        background_tasks.add_task(run_avatar_analysis, user.id)

    return {
        "try_on_photo_url": get_image_url(key),
        "uploaded": True,
        "avatar_status": "queued",
    }


@router.get("/me/avatar-profile")
async def get_avatar_profile(user: User = Depends(get_current_user)):
    """Return only the authenticated user's avatar preparation state."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            SELECT avatar_status, avatar_base_key, avatar_profile,
                   avatar_error, avatar_analyzed_at, try_on_photo_key
            FROM users
            WHERE id = $1
            """,
            user.id,
        )
    if not row:
        raise HTTPException(status_code=404, detail="User not found")
    profile = row["avatar_profile"] or {}
    if isinstance(profile, str):
        profile = json.loads(profile)
    return {
        "status": row["avatar_status"],
        "avatar_base_url": (
            get_image_url(row["avatar_base_key"] or row["try_on_photo_key"])
            if (row["avatar_base_key"] or row["try_on_photo_key"])
            else None
        ),
        "source_photo_url": (
            get_image_url(row["try_on_photo_key"]) if row["try_on_photo_key"] else None
        ),
        "profile": profile,
        "error": row["avatar_error"],
        "analyzed_at": row["avatar_analyzed_at"],
    }


@router.delete("/me/try-on-photo")
async def delete_try_on_photo(user: User = Depends(get_current_user)):
    """Remove both the private source photo and its derived avatar image."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT try_on_photo_key, avatar_base_key FROM users WHERE id = $1",
            user.id,
        )
        if row:
            for key in (row["try_on_photo_key"], row["avatar_base_key"]):
                if key:
                    await delete_image(key)
        await conn.execute(
            """
            UPDATE users
            SET try_on_photo_key = NULL,
                avatar_status = 'missing',
                avatar_base_key = NULL,
                avatar_profile = '{}'::jsonb,
                avatar_error = NULL,
                avatar_analyzed_at = NULL
            WHERE id = $1
            """,
            user.id,
        )
    return {"deleted": True}
