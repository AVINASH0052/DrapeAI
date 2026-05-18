"""FastAPI authentication dependencies."""

from fastapi import Depends, HTTPException, Request

from app.auth.firebase import verify_firebase_token
from app.database.pool import get_pool
from app.database.queries.users import upsert_user
from app.models.user import User


async def get_current_user(request: Request) -> User:
    """Extract and verify Firebase JWT, auto-provision user, return User.

    Usage in any route:
        @router.get("/me")
        async def get_profile(user: User = Depends(get_current_user)):
    """
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(
            status_code=401,
            detail="Missing or invalid Authorization header",
        )

    token = auth_header.split(" ", 1)[1]

    try:
        claims = await verify_firebase_token(token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await upsert_user(conn, claims)

    return user
