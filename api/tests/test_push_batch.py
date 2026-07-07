"""Tests for morning push batch sender."""

from contextlib import asynccontextmanager
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from app.services.push_sender import send_daily_outfit_pushes_batch


@pytest.mark.asyncio
async def test_send_daily_outfit_pushes_batch():
    conn = AsyncMock()
    conn.fetch = AsyncMock(return_value=[{"user_id": "u1"}, {"user_id": "u2"}])

    @asynccontextmanager
    async def acquire():
        yield conn

    pool = MagicMock()
    pool.acquire = acquire

    with patch("app.services.push_sender.get_pool", new_callable=AsyncMock) as mock_pool, \
         patch("app.services.push_sender.send_daily_outfit_push", new_callable=AsyncMock) as mock_send, \
         patch("app.services.push_sender._init_firebase"):
        mock_pool.return_value = pool
        mock_send.return_value = True

        count = await send_daily_outfit_pushes_batch()
        assert count == 2
        assert mock_send.await_count == 2
