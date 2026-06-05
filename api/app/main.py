"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database.pool import init_pool, close_pool
from app.services.redis_client import init_redis, close_redis
from app.routes import health, auth, user, items, outfits, lookbooks, demo, push, wardrobe, admin, stats, weather_route, notifications, calendar, analytics
from app.services.demo_wardrobe import seed_demo_wardrobe

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

if settings.environment == "production" and settings.sentry_dsn:
    sentry_sdk.init(dsn=settings.sentry_dsn, traces_sample_rate=0.1)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_pool()
    # Redis (rate limiter, task queue broker, caching)
    try:
        await init_redis()
    except Exception as e:
        logger.warning(f"Redis unavailable — falling back to in-memory rate limiting: {e}")
    # Seed demo wardrobe (idempotent — skips if already seeded)
    try:
        from app.database.pool import get_pool
        pool = await get_pool()
        # Ensure the demo user exists
        async with pool.acquire() as conn:
            await conn.execute(
                """INSERT INTO users (id, display_name, onboarding_done)
                   VALUES ('demo-user', 'Demo User', TRUE)
                   ON CONFLICT (id) DO NOTHING""",
            )
        await seed_demo_wardrobe()
    except Exception as e:
        logger.warning(f"Demo wardrobe seeding skipped: {e}")
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
        else ["https://drapeai.app"]
    ),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate limiting (Redis-backed, falls back to in-memory)
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
app.include_router(items.router)
app.include_router(outfits.router)
app.include_router(lookbooks.router)
app.include_router(demo.router)
app.include_router(push.router)
app.include_router(wardrobe.router)
app.include_router(admin.router)
app.include_router(stats.router)
app.include_router(weather_route.router)
app.include_router(notifications.router)
app.include_router(calendar.router)
app.include_router(analytics.router)
