"""Weather data route."""

from fastapi import APIRouter, Query

from app.services.weather import get_weather

router = APIRouter(tags=["Weather"])


@router.get("/weather")
async def get_current_weather(city: str = Query("delhi")):
    """Get current weather for a supported city."""
    return await get_weather(city)
