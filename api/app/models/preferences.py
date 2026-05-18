"""User preference models for onboarding quiz."""

from typing import Optional
from pydantic import BaseModel


class PreferencesInput(BaseModel):
    # Identity
    name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None

    # Style profile
    style_goals: list[str] = []
    occasions: list[str] = []
    color_preferences: list[str] = []
    fit_preference: Optional[str] = None

    # Location / climate
    location_city: Optional[str] = None
    climate: Optional[str] = None

    # Optional body / budget / lifestyle
    body_type: Optional[str] = None
    skin_undertone: Optional[str] = None  # warm | cool | neutral
    height_cm: Optional[int] = None
    budget_tier: Optional[str] = None     # budget | mid | luxury
    lifestyle: list[str] = []

    # Legacy
    age_range: Optional[str] = None


class PreferencesResponse(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    style_goals: list[str] = []
    occasions: list[str] = []
    color_preferences: list[str] = []
    fit_preference: Optional[str] = None
    location_city: Optional[str] = None
    climate: Optional[str] = None
    body_type: Optional[str] = None
    skin_undertone: Optional[str] = None
    height_cm: Optional[int] = None
    budget_tier: Optional[str] = None
    lifestyle: list[str] = []
    style_profile: Optional[str] = None
