"""Weather data fetching with caching."""

import logging
from datetime import datetime, timedelta

import httpx

from app.database.pool import get_pool

logger = logging.getLogger(__name__)

WEATHER_API = "https://api.open-meteo.com/v1/forecast"

CITY_COORDS = {
    "mumbai": (19.07, 72.87),
    "delhi": (28.61, 77.23),
    "bangalore": (12.97, 77.59),
    "hyderabad": (17.38, 78.49),
    "chennai": (13.08, 80.27),
    "kolkata": (22.57, 88.36),
    "pune": (18.52, 73.85),
    "ahmedabad": (23.02, 72.57),
    "jaipur": (26.92, 75.78),
}


async def get_weather(city: str) -> dict:
    """Get current weather for a city. Uses 1-hour cache in DB."""
    city_lower = city.lower().strip()

    pool = await get_pool()
    async with pool.acquire() as conn:
        cached = await conn.fetchrow(
            """
            SELECT temp, condition, fetched_at FROM weather_cache
            WHERE city = $1 AND fetched_at > $2
            """,
            city_lower,
            datetime.utcnow() - timedelta(hours=1),
        )
        if cached:
            return {"temp": cached["temp"], "condition": cached["condition"]}

    coords = CITY_COORDS.get(city_lower)
    if not coords:
        coords = CITY_COORDS["delhi"]
        logger.warning(f"Unknown city '{city}', defaulting to Delhi coordinates")

    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.get(
                WEATHER_API,
                params={
                    "latitude": coords[0],
                    "longitude": coords[1],
                    "current_weather": True,
                },
            )
            resp.raise_for_status()
            data = resp.json()

        current = data["current_weather"]
        temp = round(current["temperature"])
        code = current.get("weathercode", 0)

        # WMO weather codes to simple conditions
        if code in (0, 1):
            condition = "clear"
        elif code in (2, 3):
            condition = "cloudy"
        elif code in (51, 53, 55, 61, 63, 65, 80, 81, 82):
            condition = "rain"
        elif code in (71, 73, 75, 77):
            condition = "snow"
        else:
            condition = "cloudy"

        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO weather_cache (city, temp, condition, fetched_at)
                VALUES ($1, $2, $3, NOW())
                ON CONFLICT (city) DO UPDATE SET temp = $2, condition = $3, fetched_at = NOW()
                """,
                city_lower,
                temp,
                condition,
            )

        return {"temp": temp, "condition": condition}

    except Exception as e:
        logger.error(f"Weather fetch failed for {city}: {e}")
        return {"temp": 25, "condition": "clear"}
