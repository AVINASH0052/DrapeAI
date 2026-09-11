"""FastAPI application entry point."""

import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings, validate_boot_settings
from app.database.pool import init_pool, close_pool
from app.services.redis_client import init_redis, close_redis
from app.routes import admin, analytics, auth, avatar, calendar, health, items, lookbooks, notifications, outfits, push, stats, try_on, user, waitlist, wardrobe, weather_route

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

validate_boot_settings(
    settings,
    require_production=os.getenv("REQUIRE_PRODUCTION") in ("1", "true", "True"),
)

if settings.environment == "production" and settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_pool()
    # Redis is required in production (rate limits + ARQ). Development may
    # keep running with the in-memory limiter when Redis is down.
    try:
        await init_redis()
    except Exception as e:
        if settings.environment == "production":
            raise RuntimeError(
                "Redis is required in production. Rate limits and the job "
                "queue cannot degrade to in-memory on a multi-worker host."
            ) from e
        logger.warning("Redis unavailable — in-memory rate limiting (development only)")
    logger.info("DrapeAI backend started")
    yield
    from app.services.ai_provider import close_http_client
    await close_http_client()
    await close_redis()
    await close_pool()
    logger.info("DrapeAI backend stopped")


app = FastAPI(
    title="DrapeAI API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.environment == "development" else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=(
        ["*"]
        if settings.environment == "development"
        else settings.cors_origin_list
    ),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting (Redis in production; in-memory fallback only in development)
from app.middleware.rate_limiter import RateLimitMiddleware

app.add_middleware(RateLimitMiddleware)

# Security headers, request ID, body size limit
from app.middleware.security import SecurityMiddleware

app.add_middleware(SecurityMiddleware)

# Serve local uploads in dev mode
if settings.environment == "development":
    from fastapi.staticfiles import StaticFiles

    uploads_dir = Path("uploads")
    uploads_dir.mkdir(exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(uploads_dir)), name="uploads")

# Register routers
app.include_router(health.router)
app.include_router(auth.router)
app.include_router(user.router)
app.include_router(avatar.router)
app.include_router(items.router)
app.include_router(outfits.router)
app.include_router(lookbooks.router)
app.include_router(push.router)
app.include_router(wardrobe.router)
app.include_router(admin.router)
app.include_router(stats.router)
app.include_router(weather_route.router)
app.include_router(notifications.router)
app.include_router(calendar.router)
app.include_router(analytics.router)
app.include_router(try_on.router)
app.include_router(waitlist.router)
