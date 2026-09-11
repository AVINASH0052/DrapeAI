"""AI spend tracking and budget enforcement (multi-provider)."""

import logging
from datetime import datetime

from app.config import settings
from app.database.pool import get_pool

logger = logging.getLogger(__name__)


async def track_provider_spend(
    provider: str, model: str,
    tokens_in: int | None, tokens_out: int | None, cost_usd: float,
) -> None:
    """Record an AI call cost per provider.

    Free-tier providers (NVIDIA, Groq) may return None for token counts.
    We still record cost if non-zero; token counts are best-effort.
    """
    tokens_in = tokens_in or 0
    tokens_out = tokens_out or 0
    if cost_usd <= 0:
        return
    pool = await get_pool()
    month = datetime.utcnow().strftime("%Y-%m")
    metric = f"ai_cost_{provider}_{month}"
    async with pool.acquire() as conn:
        await conn.execute(
            """
            INSERT INTO analytics_daily (date, metric, value)
            VALUES (CURRENT_DATE, $1, $2)
            ON CONFLICT (date, metric)
            DO UPDATE SET value = analytics_daily.value + EXCLUDED.value
            """,
            metric, cost_usd,
        )


async def get_provider_spend(provider: str) -> float:
    """Sum of this month's spend for a provider."""
    pool = await get_pool()
    month = datetime.utcnow().strftime("%Y-%m")
    metric = f"ai_cost_{provider}_{month}"
    async with pool.acquire() as conn:
        total = await conn.fetchval(
            "SELECT COALESCE(SUM(value), 0) FROM analytics_daily WHERE metric = $1",
            metric,
        )
    return float(total or 0)


async def get_total_spend() -> float:
    """Sum of this month's spend across every provider."""
    pool = await get_pool()
    month = datetime.utcnow().strftime("%Y-%m")
    async with pool.acquire() as conn:
        total = await conn.fetchval(
            "SELECT COALESCE(SUM(value), 0) FROM analytics_daily "
            "WHERE metric LIKE $1",
            f"ai\\_cost\\_%\\_{month}",
        )
    return float(total or 0)


def _cap_for(provider: str) -> float:
    """Monthly USD cap for a provider.

    Unknown providers get the total ceiling rather than infinity — a provider
    nobody remembered to configure should not be the one that bills freely.
    """
    caps = {
        "openai": settings.openai_spend_cap_usd,
        "anthropic": settings.anthropic_spend_cap_usd,
        "gemini": settings.gemini_spend_cap_usd,
        "vertex": settings.vertex_spend_cap_usd,
        "cloudflare": settings.cloudflare_spend_cap_usd,
        "runpod": settings.runpod_spend_cap_usd,
        "nvidia": settings.nvidia_spend_cap_usd,
        "groq": settings.groq_spend_cap_usd,
    }
    return caps.get(provider, settings.total_spend_cap_usd)


class BudgetExceeded(Exception):
    """Monthly AI spend cap hit. Callers may fall back to a cheaper provider."""

    def __init__(self, provider: str, spent: float, cap: float):
        self.provider = provider
        self.spent = spent
        self.cap = cap
        super().__init__(f"{provider} budget exceeded: ${spent:.2f} >= ${cap:.2f}")


async def within_budget(provider: str) -> bool:
    """True if `provider` and the overall ceiling both still have headroom.

    Non-raising variant, for provider-cascade code that should try the next
    provider rather than fail the request.
    """
    cap = _cap_for(provider)
    spent = await get_provider_spend(provider)
    if spent >= cap:
        logger.error("%s budget exceeded: $%.2f >= $%.2f", provider, spent, cap)
        return False

    total = await get_total_spend()
    if total >= settings.total_spend_cap_usd:
        logger.error(
            "total AI budget exceeded: $%.2f >= $%.2f (blocking %s)",
            total, settings.total_spend_cap_usd, provider,
        )
        return False
    return True


async def check_budget(provider: str = "openai") -> None:
    """Raise 503 if monthly spend exceeds the provider's cap or the total cap."""
    if not await within_budget(provider):
        from fastapi import HTTPException
        raise HTTPException(
            status_code=503,
            detail="AI service temporarily unavailable. Please try later.",
        )
