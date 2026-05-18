"""FastAPI application entry point."""

import logging
from contextlib import asynccontextmanager
from pathlib import Path

import sentry_sdk
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database.pool import init_pool, close_pool
from app.routes import health, auth, user, items, outfits, lookbooks, demo, push, wardrobe

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
    logger.info("DrapeAI backend started")
    yield
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
