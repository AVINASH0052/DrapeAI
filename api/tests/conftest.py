"""Shared test fixtures."""

import asyncio
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.database.pool import init_pool, close_pool, get_pool


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(scope="session")
async def setup_db():
    await init_pool()
    yield
    await close_pool()


@pytest_asyncio.fixture
async def client(setup_db):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def auth_headers():
    return {"Authorization": "Bearer test-token"}


@pytest_asyncio.fixture
async def clean_db(setup_db):
    """Clean test data for test-user-001 after each test."""
    yield
    pool = await get_pool()
    async with pool.acquire() as conn:
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
