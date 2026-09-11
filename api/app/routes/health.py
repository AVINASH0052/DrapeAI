"""Liveness and readiness endpoints."""

import time

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.config import settings
from app.database.pool import get_pool

router = APIRouter(tags=["Health"])

_start_time = time.time()


async def collect_readiness() -> dict:
    """Dependency checks used by /ready and admin health."""
    checks: dict[str, dict] = {}

    db_ok = False
    db_version = None
    try:
        pool = await get_pool()
        async with pool.acquire() as conn:
            db_version = await conn.fetchval("SELECT version()")
        db_ok = True
    except Exception:
        pass
    checks["database"] = {
        "ok": db_ok,
        "version": db_version.split(",")[0] if db_version else None,
    }

    redis_ok = False
    try:
        from app.services.redis_client import get_redis

        redis = await get_redis()
        await redis.ping()
        redis_ok = True
    except Exception:
        pass
    redis_required = settings.environment == "production"
    checks["redis"] = {"ok": redis_ok, "required": redis_required}

    storage_ok = settings.environment == "development" or bool(
        settings.r2_account_id
        and settings.r2_access_key_id
        and settings.r2_secret_access_key
        and settings.r2_bucket_name
    )
    checks["storage"] = {"ok": storage_ok, "required": settings.environment == "production"}

    from app.config import _has_ai_path

    provider_ok = settings.environment != "production" or _has_ai_path(settings)
    checks["providers"] = {
        "ok": provider_ok,
        "required": settings.environment == "production",
    }

    ready = db_ok
    if redis_required:
        ready = ready and redis_ok
    if settings.environment == "production":
        ready = ready and storage_ok and provider_ok

    return {
        "ready": ready,
        "service": "drapeai-api",
        "environment": settings.environment,
        "uptime_seconds": int(time.time() - _start_time),
        "checks": checks,
    }


@router.get("/health")
async def health_check():
    """Liveness: process is up. Do not use this to decide if traffic is safe."""
    return {
        "status": "ok",
        "service": "drapeai-api",
        "uptime_seconds": int(time.time() - _start_time),
    }


@router.get("/ready")
async def readiness_check():
    """Readiness: dependencies needed to serve requests. Non-2xx when not ready."""
    body = await collect_readiness()
    status = 200 if body["ready"] else 503
    return JSONResponse(status_code=status, content=body)
