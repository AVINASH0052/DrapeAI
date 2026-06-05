"""FastAPI authentication dependencies."""

import logging

from fastapi import Depends, HTTPException, Request

from app.auth.firebase import verify_firebase_token
from app.config import settings
from app.database.pool import get_pool
from app.database.queries.users import upsert_user
from app.models.user import User

logger = logging.getLogger(__name__)


async def get_current_user(request: Request) -> User:
    """Extract and verify Firebase JWT, auto-provision user, return User.

    Also enforces:
    - Suspended user blocking (403)
    - last_login_at update
    - request.state.user_id for rate limiter

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

    # Log test-token usage for audit visibility (only reachable in dev)
    if token == "test-token":
        logger.info("Dev test-token authenticated for user %s", claims.get("user_id"))

    pool = await get_pool()
    async with pool.acquire() as conn:
        user = await upsert_user(conn, claims)

        # Check if user is suspended
        is_suspended = await conn.fetchval(
            "SELECT is_suspended FROM users WHERE id = $1",
            user.id,
        )
        if is_suspended:
            raise HTTPException(
                status_code=403,
                detail="Your account has been suspended. Contact support.",
            )

        # Update last_login_at
        await conn.execute(
            "UPDATE users SET last_login_at = NOW() WHERE id = $1",
            user.id,
        )

    # Set user_id on request state for rate limiter middleware
    request.state.user_id = user.id

    return user

