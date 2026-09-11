"""Item models."""

from datetime import datetime

from pydantic import BaseModel, Field, field_validator

_GARMENT_SIZES = {"xs", "s", "m", "l", "xl", "xxl", "free"}
_GARMENT_FITS = {"slim", "regular", "relaxed", "baggy", "oversized"}


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
    garment_size: str | None = Field(default=None, max_length=16)
    garment_fit: str | None = Field(default=None, max_length=16)

    @field_validator("garment_size")
    @classmethod
    def _size(cls, value: str | None) -> str | None:
        if value is None:
            return None
        size = value.strip().lower()
        if size not in _GARMENT_SIZES:
            raise ValueError("Size must be xs, s, m, l, xl, xxl, or free")
        return size

    @field_validator("garment_fit")
    @classmethod
    def _fit(cls, value: str | None) -> str | None:
        if value is None:
            return None
        fit = value.strip().lower()
        if fit not in _GARMENT_FITS:
            raise ValueError("Fit must be slim, regular, relaxed, baggy, or oversized")
        return fit
