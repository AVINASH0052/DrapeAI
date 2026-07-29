"""Item models."""

from pydantic import BaseModel, Field
from datetime import datetime


class ItemTags(BaseModel):
    category: str
    sub_category: str
    display_name: str | None = None
    notes: str | None = None
    primary_color: str
    secondary_colors: list[str] = []
    pattern: str = "solid"
    fabric: str = "cotton"
    style_tags: list[str] = []
    formality: int = 3  # 1 (very casual) - 5 (formal)
    season_tags: list[str] = ["all_season"]
    ethnic_flag: bool = False
    confidence: float = 0.0


class ItemResponse(BaseModel):
    id: str
    image_url: str
    thumbnail_url: str | None = None
    category: str
    sub_category: str
    primary_color: str
    secondary_colors: list[str]
    pattern: str
    fabric: str
    style_tags: list[str]
    formality: int
    season_tags: list[str]
    ethnic_flag: bool
    wear_count: int = 0
    last_worn_at: datetime | None = None
    created_at: datetime
    processing_status: str = "ready"


class ItemUpdate(BaseModel):
    display_name: str | None = Field(default=None, max_length=80)
    category: str | None = None
    sub_category: str | None = None
    primary_color: str | None = None
    secondary_colors: list[str] | None = None
    pattern: str | None = None
    fabric: str | None = None
    style_tags: list[str] | None = None
    formality: int | None = None
    season_tags: list[str] | None = None
    ethnic_flag: bool | None = None
    notes: str | None = Field(default=None, max_length=500)
    purchase_price: int | None = None  # paise (INR x 100)
