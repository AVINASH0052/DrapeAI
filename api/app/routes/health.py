"""Health check endpoint."""

from fastapi import APIRouter

from app.database.pool import get_pool

router = APIRouter(tags=["Health"])


@router.get("/health")
async def health_check():
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.fetchval("SELECT 1")
    return {"status": "ok", "service": "drapeai-api"}
