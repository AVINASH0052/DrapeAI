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
async def test_mark_completed_does_not_overwrite_already_failed_job(client, clean_db):
    """Regression test for a real race found in live testing: a job stuck
    processing far longer than expected got marked 'failed' (and refunded)
    by a stale-job check while the worker was genuinely still running it.
    When the worker's real result arrived ~30 min later, mark_completed
    must NOT silently flip status back to 'completed' — the client already
    saw 'failed' and may have retried; flip-flopping the same row is worse
    than leaving it as the first terminal state that was reported."""
    from app.database.pool import get_pool

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO try_on_jobs (user_id, outfit_id, status)
            VALUES ('test-user-001', NULL, 'processing')
            RETURNING id
            """,
        )
        job_id = str(row["id"])

        # Simulate the stale-job check firing first.
        won_fail = await try_on_job.mark_failed(conn, job_id, "Timed out waiting for worker")
        assert won_fail is True

        # The worker's real completion arrives late.
        won_complete = await try_on_job.mark_completed(
            conn,
            job_id,
            result_key="users/test-user-001/outfits/x/preview.png",
            method="ai:gemini",
            provider="gemini",
            model="gemini-2.5-flash-image",
        )
        assert won_complete is False

        final = await conn.fetchrow("SELECT status, error_message, result_key FROM try_on_jobs WHERE id = $1", job_id)
    assert final["status"] == "failed"
    assert final["error_message"] == "Timed out waiting for worker"
    assert final["result_key"] is None


@pytest.mark.asyncio
async def test_mark_completed_wins_when_job_still_processing(client, clean_db):
    """Normal path: nothing else touched the job, so completion succeeds."""
    from app.database.pool import get_pool

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            "INSERT INTO try_on_jobs (user_id, outfit_id, status) VALUES ('test-user-001', NULL, 'processing') RETURNING id",
        )
        job_id = str(row["id"])
        won = await try_on_job.mark_completed(
            conn, job_id, result_key="k", method="ai:gemini", provider="gemini", model="m"
        )
        assert won is True
        final = await conn.fetchrow("SELECT status FROM try_on_jobs WHERE id = $1", job_id)
    assert final["status"] == "completed"


@pytest.mark.asyncio
async def test_increment_uses_utc_date_key():
    fake = FakeRedis()
    with patch("app.services.redis_client.get_redis", new=AsyncMock(return_value=fake)):
        count = await try_on_job.increment_daily_count("u1")
    assert count == 1
    key = next(iter(fake.store))
    assert datetime.now(timezone.utc).date().isoformat() in key
