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


async def check_budget(provider: str = "openai") -> None:
    """Raise 503 if monthly spend exceeds the provider's cap."""
    total = await get_provider_spend(provider)
    cap = {
        "openai": settings.openai_spend_cap_usd,
        "anthropic": settings.anthropic_spend_cap_usd,
    }.get(provider, float("inf"))
    if total >= cap:
        logger.error(f"{provider} budget exceeded: ${total:.2f} >= ${cap}")
        from fastapi import HTTPException
        raise HTTPException(
            status_code=503,
            detail="AI service temporarily unavailable. Please try later.",
        )
