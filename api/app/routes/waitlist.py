"""Public early-access waitlist for the marketing site."""

import logging
import re

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from app.database.pool import get_pool

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/waitlist", tags=["Waitlist"])

_EMAIL_RE = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
_MAX_EMAIL_LEN = 254


class WaitlistJoinRequest(BaseModel):
    email: str = Field(..., min_length=3, max_length=_MAX_EMAIL_LEN)
    source: str = Field(default="landing", max_length=64)


class WaitlistJoinResponse(BaseModel):
    ok: bool = True
    already_joined: bool = False
    message: str


def _normalize_email(raw: str) -> str:
    email = (raw or "").strip().lower()
    if len(email) > _MAX_EMAIL_LEN or not _EMAIL_RE.match(email):
        raise HTTPException(status_code=400, detail="Enter a valid email address.")
    return email


@router.post("", response_model=WaitlistJoinResponse)
async def join_waitlist(body: WaitlistJoinRequest, request: Request):
    """Join the Sugatai early-access list. Idempotent for duplicate emails."""
    email = _normalize_email(body.email)
    source = (body.source or "landing").strip()[:64] or "landing"

    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow(
            """
            INSERT INTO waitlist_emails (email, source)
            VALUES ($1, $2)
            ON CONFLICT (email) DO NOTHING
            RETURNING id
            """,
            email,
            source,
        )

    already = row is None
    if already:
        logger.info("waitlist: duplicate join from %s", request.client.host if request.client else "?")
        return WaitlistJoinResponse(
            already_joined=True,
            message="You are already on the early list.",
        )

    logger.info("waitlist: new join source=%s", source)
    return WaitlistJoinResponse(
        already_joined=False,
        message="You are on the early list. We will reach out soon.",
    )
