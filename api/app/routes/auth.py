"""Auth routes."""

from fastapi import APIRouter, Depends

from app.auth.dependencies import get_current_user
from app.models.user import User

router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify")
async def verify_token(user: User = Depends(get_current_user)):
    """Client calls this after Firebase login to confirm backend connectivity."""
    return {
        "user_id": user.id,
        "display_name": user.display_name,
        "onboarding_done": user.onboarding_done,
    }
