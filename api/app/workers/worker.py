"""ARQ worker configuration.

Run with:  arq app.workers.worker.WorkerSettings
Or via Docker Compose 'worker' service.
"""

import logging

from arq import cron
from arq.connections import RedisSettings

from app.config import settings

logging.basicConfig(
    level=settings.log_level,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)


async def startup(ctx: dict) -> None:
    """Worker startup — initialize DB pool."""
    from app.database.pool import init_pool
    await init_pool()
    logger.info("ARQ worker started — DB pool initialized")


async def shutdown(ctx: dict) -> None:
    """Worker shutdown — close DB pool."""
    from app.database.pool import close_pool
    await close_pool()
    logger.info("ARQ worker stopped — DB pool closed")


def _parse_redis_url() -> RedisSettings:
    """Parse redis_url into ARQ RedisSettings."""
    from urllib.parse import urlparse
    parsed = urlparse(settings.redis_url)
    return RedisSettings(
        host=parsed.hostname or "localhost",
        port=parsed.port or 6379,
        database=int(parsed.path.lstrip("/") or 0),
        password=parsed.password,
    )


class WorkerSettings:
    """ARQ worker settings — functions, cron jobs, concurrency."""

    # Task functions the worker can execute
    functions = [
        "app.workers.tasks.process_upload",
        "app.workers.tasks.regenerate_embedding",
    ]

    # Scheduled cron jobs
    cron_jobs = [
        # Daily outfit push at 7:30 AM IST (2:00 AM UTC)
        cron("app.workers.tasks.send_daily_push", hour=2, minute=0),
    ]

    # Worker config
    on_startup = startup
    on_shutdown = shutdown
    redis_settings = _parse_redis_url()
    max_jobs = 5        # Concurrent task limit
    job_timeout = 300   # 5 min max per task
    keep_result = 3600  # Keep results for 1 hour
    health_check_interval = 30
