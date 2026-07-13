"""User profile and preferences routes."""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.preferences import upsert_preferences, get_preferences
from app.models.user import User
from app.models.preferences import PreferencesInput, PreferencesResponse
from app.services.storage import get_image_url, upload_try_on_photo, delete_image
from app.services.tryon_input_check import check_person_photo
from app.utils.image_validation import validate_image

router = APIRouter(tags=["User"])


@router.get("/me")
async def get_profile(user: User = Depends(get_current_user)):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT try_on_photo_key FROM users WHERE id = $1", user.id
        )
    try_on_key = row["try_on_photo_key"] if row else None
    return {
        "id": user.id,
        "display_name": user.display_name,
        "email": user.email,
        "phone": user.phone,
        "photo_url": user.photo_url,
        "try_on_photo_url": get_image_url(try_on_key) if try_on_key else None,
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
        await conn.execute("DELETE FROM users WHERE id = $1", user.id)
    return {"deleted": True}


@router.post("/me/try-on-photo", status_code=201)
async def upload_try_on_photo_route(
    image: UploadFile = File(...),
    user: User = Depends(get_current_user),
):
    """Upload a full-body photo used for 'see me in this outfit' previews."""
    file_bytes = await image.read()
    validate_image(image.content_type, file_bytes)

    check = await check_person_photo(file_bytes)
    if not check.ok:
        raise HTTPException(status_code=400, detail=check.reason)

    key = await upload_try_on_photo(user.id, file_bytes, image.content_type or "image/jpeg")

    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "UPDATE users SET try_on_photo_key = $1 WHERE id = $2",
            key,
            user.id,
        )
    return {
        "try_on_photo_url": get_image_url(key),
        "uploaded": True,
    }


@router.delete("/me/try-on-photo")
async def delete_try_on_photo(user: User = Depends(get_current_user)):
    """Remove the user's try-on reference photo."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        key = await conn.fetchval(
            "SELECT try_on_photo_key FROM users WHERE id = $1", user.id
        )
        if key:
            await delete_image(key)
        await conn.execute(
            "UPDATE users SET try_on_photo_key = NULL WHERE id = $1", user.id
        )
    return {"deleted": True}
