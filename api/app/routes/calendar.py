"""Calendar API — outfit-per-day tracking and planning.

Endpoints:
  GET  /calendar?month=YYYY-MM  — Outfits worn/planned per day for a month
  POST /calendar/{date}         — Assign an outfit to a date
  DELETE /calendar/{date}       — Remove outfit from a date
"""

from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from app.auth.dependencies import get_current_user
from app.database.pool import get_pool

router = APIRouter(prefix="/calendar", tags=["calendar"])


class CalendarEntry(BaseModel):
    date: str
    outfit_id: str
    item_ids: list[str]
    occasion: str | None = None


class CalendarMonth(BaseModel):
    month: str
    entries: list[CalendarEntry]
    total_days_styled: int


class AssignOutfit(BaseModel):
    outfit_id: str


@router.get("", response_model=CalendarMonth)
async def get_calendar_month(
    month: str = Query(..., regex=r"^\d{4}-\d{2}$", description="YYYY-MM"),
    user: dict = Depends(get_current_user),
):
    """Get all outfits worn/planned for a month."""
    try:
        year, mon = month.split("-")
        first_day = date(int(year), int(mon), 1)
        if int(mon) == 12:
            last_day = date(int(year) + 1, 1, 1)
        else:
            last_day = date(int(year), int(mon) + 1, 1)
    except (ValueError, IndexError):
        raise HTTPException(400, "Invalid month format. Use YYYY-MM.")

    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id::text, item_ids, occasion, worn_date
            FROM outfits
            WHERE user_id = $1
              AND worn_date >= $2
              AND worn_date < $3
            ORDER BY worn_date
            """,
            user["uid"],
            first_day,
            last_day,
        )

    import json
    entries = []
    for row in rows:
        item_ids = json.loads(row["item_ids"]) if isinstance(row["item_ids"], str) else row["item_ids"]
        entries.append(CalendarEntry(
            date=row["worn_date"].isoformat(),
            outfit_id=row["id"],
            item_ids=item_ids,
            occasion=row["occasion"],
        ))

    return CalendarMonth(
        month=month,
        entries=entries,
        total_days_styled=len(set(e.date for e in entries)),
    )


@router.post("/{day}")
async def assign_outfit_to_date(
    day: str,
    body: AssignOutfit,
    user: dict = Depends(get_current_user),
):
    """Assign an outfit to a specific date (wear or plan)."""
    try:
        target_date = date.fromisoformat(day)
    except ValueError:
        raise HTTPException(400, "Invalid date format. Use YYYY-MM-DD.")

    pool = await get_pool()
    async with pool.acquire() as conn:
        # Verify outfit belongs to user
        outfit = await conn.fetchrow(
            "SELECT id FROM outfits WHERE id = $1::uuid AND user_id = $2",
            body.outfit_id,
            user["uid"],
        )
        if not outfit:
            raise HTTPException(404, "Outfit not found.")

        # Assign the date
        await conn.execute(
            "UPDATE outfits SET worn_date = $1, is_worn = TRUE WHERE id = $2::uuid",
            target_date,
            body.outfit_id,
        )

        # Increment wear_count for all items in the outfit
        import json
        outfit_row = await conn.fetchrow(
            "SELECT item_ids FROM outfits WHERE id = $1::uuid", body.outfit_id
        )
        if outfit_row:
            item_ids = json.loads(outfit_row["item_ids"]) if isinstance(outfit_row["item_ids"], str) else outfit_row["item_ids"]
            for item_id in item_ids:
                await conn.execute(
                    """UPDATE items SET wear_count = wear_count + 1,
                       last_worn_at = NOW() WHERE id = $1::uuid""",
                    item_id,
                )

    return {"status": "assigned", "date": day, "outfit_id": body.outfit_id}


@router.delete("/{day}")
async def remove_outfit_from_date(
    day: str,
    user: dict = Depends(get_current_user),
):
    """Remove outfit assignment from a date."""
    try:
        target_date = date.fromisoformat(day)
    except ValueError:
        raise HTTPException(400, "Invalid date format. Use YYYY-MM-DD.")

    pool = await get_pool()
    async with pool.acquire() as conn:
        result = await conn.execute(
            """UPDATE outfits SET worn_date = NULL
               WHERE user_id = $1 AND worn_date = $2""",
            user["uid"],
            target_date,
        )

    return {"status": "removed", "date": day}
