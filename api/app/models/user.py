"""User models."""

from pydantic import BaseModel
from datetime import datetime


class User(BaseModel):
    id: str  # Firebase UID
    phone: str | None = None
    email: str | None = None
    display_name: str | None = None
    photo_url: str | None = None
    try_on_photo_key: str | None = None
    onboarding_done: bool = False
    is_admin: bool = False
    is_suspended: bool = False
    created_at: datetime | None = None
