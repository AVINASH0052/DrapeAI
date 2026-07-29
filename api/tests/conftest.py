"""Shared test fixtures."""

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.database.pool import init_pool, close_pool, get_pool
from app.services.ai_provider import close_http_client


# Pool and shared HTTP client are (re)created per test so they always live
# on the current test's event loop — pytest-asyncio 0.24 gives each test
# its own loop and no longer honors a custom session `event_loop` fixture.
@pytest_asyncio.fixture
async def setup_db():
    from app.config import settings

    # Keep visualize sync in tests (no ARQ worker process).
    settings.tryon_async = False
    # Never call real AI providers from tests — force PIL composite path.
    settings.tryon_provider_primary = ""
    settings.tryon_provider_secondary = ""
    settings.tryon_provider_tertiary = ""
    settings.tryon_provider_quaternary = ""
    settings.tryon_fallback_composite = True
    # Pre-flight input checks also call a real vision LLM — disable in tests.
    settings.tryon_input_check_enabled = False
    await init_pool()
    yield
    await close_pool()
    await close_http_client()


@pytest_asyncio.fixture
async def client(setup_db):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


@pytest_asyncio.fixture
async def test_item(setup_db, clean_db):
    """Insert a minimal test item and return its id."""
    import json
    import uuid

    item_id = str(uuid.uuid4())
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO items (id, user_id, image_url, category, sub_category,
                               primary_color, secondary_colors, pattern, fabric,
                               style_tags, formality, season_tags, confidence)
            VALUES ($1, 'test-user-001', 'https://example.com/test.png',
                    'top', 't-shirt', 'blue', '[]', 'solid', 'cotton',
                    '["casual"]', 3, '["all_season"]', 0.95)
            """,
            item_id,
        )
    return item_id


@pytest_asyncio.fixture
async def test_outfit(setup_db, test_item, clean_db):
    """Insert a minimal test outfit referencing test_item and return its id."""
    import json
    import uuid

    outfit_id = str(uuid.uuid4())
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO outfits (id, user_id, item_ids, occasion, generated_by)
            VALUES ($1, 'test-user-001', $2, 'casual', 'ai')
            """,
            outfit_id,
            json.dumps([test_item]),
        )
    return outfit_id


@pytest_asyncio.fixture
async def clean_db(setup_db):
    """Clean test data for test-user-001 after each test."""
    pool = await get_pool()
    async with pool.acquire() as conn:
        # Ensure Phase-1 try-on jobs table exists (dev DBs may predate migration)
        await conn.execute(
            """
            CREATE TABLE IF NOT EXISTS try_on_jobs (
                id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                outfit_id       UUID REFERENCES outfits(id) ON DELETE CASCADE,
                session_id      UUID,
                status          TEXT NOT NULL DEFAULT 'queued',
                provider        TEXT,
                model           TEXT,
                method          TEXT,
                result_key      TEXT,
                error_message   TEXT,
                created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                started_at      TIMESTAMPTZ,
                completed_at    TIMESTAMPTZ
            )
            """
        )
    yield
    pool = await get_pool()
    async with pool.acquire() as conn:
        await conn.execute(
            "DELETE FROM try_on_jobs WHERE user_id = 'test-user-001'"
        )
        await conn.execute(
            "DELETE FROM outfit_feedback WHERE user_id = 'test-user-001'"
        )
        await conn.execute(
            """
            DELETE FROM lookbook_outfits
            WHERE lookbook_id IN (
                SELECT id FROM lookbooks WHERE user_id = 'test-user-001'
            )
            """
        )
        await conn.execute(
            "DELETE FROM outfits WHERE user_id = 'test-user-001'"
        )
        await conn.execute(
            "DELETE FROM lookbooks WHERE user_id = 'test-user-001'"
        )
        await conn.execute("DELETE FROM items WHERE user_id = 'test-user-001'")
        await conn.execute(
            "DELETE FROM preferences WHERE user_id = 'test-user-001'"
        )
        await conn.execute(
            """
            UPDATE users
            SET try_on_photo_key = NULL,
                avatar_status = 'missing',
                avatar_base_key = NULL,
                avatar_profile = '{}'::jsonb,
                avatar_error = NULL,
                avatar_analyzed_at = NULL
            WHERE id = 'test-user-001'
            """
        )
