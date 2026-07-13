"""Unit tests for try-on job rate limiting, quota refund, and reset times."""

from datetime import datetime, timezone
from unittest.mock import AsyncMock, patch

import pytest
from fastapi import HTTPException

from app.services import try_on_job


class FakeRedis:
    def __init__(self, initial: int | None = None):
        self.store: dict[str, int] = {}
        if initial is not None:
            self.store["_seed"] = initial
        self.set_calls: list[tuple] = []

    def _key(self):
        return next(iter(self.store), None)

    async def incr(self, key):
        self.store[key] = self.store.pop("_seed", self.store.get(key, 0)) + 1
        return self.store[key]

    async def decr(self, key):
        self.store[key] = self.store.pop("_seed", self.store.get(key, 0)) - 1
        return self.store[key]

    async def get(self, key):
        val = self.store.get("_seed", self.store.get(key))
        return None if val is None else str(val)

    async def set(self, key, value, keepttl=False):
        self.set_calls.append((key, value, keepttl))
        self.store[key] = value

    async def expire(self, key, ttl):
        return True


def test_next_utc_midnight_is_future_utc():
    stamp = try_on_job._next_utc_midnight()
    assert stamp.endswith("Z")
    parsed = datetime.fromisoformat(stamp.replace("Z", "+00:00"))
    now = datetime.now(timezone.utc)
    assert parsed > now
    assert (parsed - now).total_seconds() <= 24 * 3600
    assert parsed.hour == 0 and parsed.minute == 0 and parsed.second == 0


@pytest.mark.asyncio
async def test_check_daily_limit_429_payload():
    with patch.object(try_on_job, "_daily_count", new=AsyncMock(return_value=5)), \
         patch.object(try_on_job.settings, "tryon_daily_limit_free", 5):
        with pytest.raises(HTTPException) as exc:
            await try_on_job.check_daily_limit("u1")
    detail = exc.value.detail
    assert exc.value.status_code == 429
    assert detail["limit"] == 5
    assert detail["remaining"] == 0
    assert detail["resets_at"].endswith("Z")


@pytest.mark.asyncio
async def test_check_daily_limit_under_limit_passes():
    with patch.object(try_on_job, "_daily_count", new=AsyncMock(return_value=4)), \
         patch.object(try_on_job.settings, "tryon_daily_limit_free", 5):
        await try_on_job.check_daily_limit("u1")  # no raise


@pytest.mark.asyncio
async def test_daily_usage_remaining():
    with patch.object(try_on_job, "_daily_count", new=AsyncMock(return_value=2)), \
         patch.object(try_on_job.settings, "tryon_daily_limit_free", 5):
        usage = await try_on_job.daily_usage("u1")
    assert usage == {"limit": 5, "remaining": 3}


@pytest.mark.asyncio
async def test_daily_usage_unlimited_when_limit_disabled():
    with patch.object(try_on_job.settings, "tryon_daily_limit_free", 0):
        usage = await try_on_job.daily_usage("u1")
    assert usage == {"limit": None, "remaining": None}


@pytest.mark.asyncio
async def test_refund_decrements_redis():
    fake = FakeRedis(initial=3)
    with patch("app.services.redis_client.get_redis", new=AsyncMock(return_value=fake)):
        await try_on_job.refund_daily_count("u1")
    assert list(fake.store.values()) == [2]
    assert fake.set_calls == []


@pytest.mark.asyncio
async def test_refund_floors_at_zero():
    fake = FakeRedis(initial=0)
    with patch("app.services.redis_client.get_redis", new=AsyncMock(return_value=fake)):
        await try_on_job.refund_daily_count("u1")
    # decr took it to -1; refund must clamp back to 0 with TTL preserved
    assert fake.set_calls and fake.set_calls[0][1] == 0
    assert fake.set_calls[0][2] is True


@pytest.mark.asyncio
async def test_refund_swallows_redis_errors():
    with patch(
        "app.services.redis_client.get_redis",
        new=AsyncMock(side_effect=RuntimeError("Redis not initialized")),
    ):
        await try_on_job.refund_daily_count("u1")  # must not raise


@pytest.mark.asyncio
async def test_increment_uses_utc_date_key():
    fake = FakeRedis()
    with patch("app.services.redis_client.get_redis", new=AsyncMock(return_value=fake)):
        count = await try_on_job.increment_daily_count("u1")
    assert count == 1
    key = next(iter(fake.store))
    assert datetime.now(timezone.utc).date().isoformat() in key
