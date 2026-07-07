"""Demo wardrobe endpoint for new users."""

from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool
from app.database.queries.items import get_items
from app.models.user import User
from app.services.storage import get_image_url
from app.services.demo_activation import activate_demo_for_user, clear_demo_for_user

router = APIRouter(tags=["Demo"])

DEMO_USER_ID = "demo-user"


@router.get("/demo/wardrobe")
async def get_demo_wardrobe(user: User = Depends(get_current_user)):
    """Return the demo wardrobe. Any authenticated user can access this."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        items, total = await get_items(conn, DEMO_USER_ID, limit=50)

    for item in items:
        item["image_url"] = get_image_url(item["image_url"])

    return {"items": items, "total": total, "is_demo": True}


@router.post("/demo/activate", status_code=201)
async def activate_demo(user: User = Depends(get_current_user)):
    """Copy demo wardrobe into the current user's closet."""
    result = await activate_demo_for_user(user.id)
    return result


@router.delete("/demo/clear")
async def clear_demo(user: User = Depends(get_current_user)):
    """Remove demo items from the current user's closet."""
    return await clear_demo_for_user(user.id)
