"""Health check endpoint."""

import time

from fastapi import APIRouter

from app.database.pool import get_pool

router = APIRouter(tags=["Health"])

_start_time = time.time()


@router.get("/health")
async def health_check():
    """Returns service health with DB connectivity and uptime."""
    db_ok = False
    db_version = None
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            db_version = await conn.fetchval("SELECT version()")
        db_ok = True
    except Exception:
        pass

    uptime_seconds = int(time.time() - _start_time)
    status = "ok" if db_ok else "degraded"

    return {
        "status": status,
        "service": "drapeai-api",
        "uptime_seconds": uptime_seconds,
        "database": {
            "connected": db_ok,
            "version": db_version.split(",")[0] if db_version else None,
        },
    }

