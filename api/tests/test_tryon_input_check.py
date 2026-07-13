"""Tests for pre-flight try-on input validation (person + garment photos)."""

from __future__ import annotations

import json
from dataclasses import dataclass
from unittest.mock import AsyncMock, patch

import pytest

from app.services.tryon_input_check import (
    InputCheckResult,
    check_garment_photo,
    check_person_photo,
)


@dataclass
class _FakeCall:
    text: str


def _mock_vision(payload: dict):
    return AsyncMock(return_value=_FakeCall(text=json.dumps(payload)))


@pytest.mark.asyncio
async def test_check_person_photo_passes_clean_front_facing():
    payload = {
        "full_body": True,
        "front_facing": True,
        "single_person": True,
        "clear": True,
        "issue": "none",
        "reason": "",
        "confidence": 0.95,
    }
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=_mock_vision(payload)):
        s.tryon_input_check_enabled = True
        result = await check_person_photo(b"fake")
    assert result.ok is True


@pytest.mark.asyncio
async def test_check_person_photo_rejects_back_view():
    payload = {
        "full_body": True,
        "front_facing": False,
        "single_person": True,
        "clear": True,
        "issue": "back_view",
        "reason": "This photo shows your back, not your face.",
        "confidence": 0.9,
    }
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=_mock_vision(payload)):
        s.tryon_input_check_enabled = True
        result = await check_person_photo(b"fake")
    assert result.ok is False
    assert result.issue == "back_view"
    assert "back" in result.reason.lower()


@pytest.mark.asyncio
async def test_check_garment_photo_rejects_back_view_like_the_live_bug():
    """Regression test for the exact failure found in manual testing: a
    garment reference shot from behind produced a garbled partial swap
    because the model had no front-view information to work from."""
    payload = {
        "front_facing": False,
        "garment_visible": True,
        "issue": "back_view",
        "reason": "This photo shows the back of the blouse — the front isn't visible.",
        "confidence": 0.88,
    }
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=_mock_vision(payload)):
        s.tryon_input_check_enabled = True
        result = await check_garment_photo(b"fake")
    assert result.ok is False
    assert result.issue == "back_view"


@pytest.mark.asyncio
async def test_check_garment_photo_passes_clean_front_view():
    payload = {
        "front_facing": True,
        "garment_visible": True,
        "issue": "none",
        "reason": "",
        "confidence": 0.9,
    }
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=_mock_vision(payload)):
        s.tryon_input_check_enabled = True
        result = await check_garment_photo(b"fake")
    assert result.ok is True


@pytest.mark.asyncio
async def test_low_confidence_does_not_block():
    """An uncertain model call shouldn't produce a false rejection."""
    payload = {
        "front_facing": False,
        "garment_visible": True,
        "issue": "back_view",
        "reason": "Might be a back view, hard to tell.",
        "confidence": 0.3,
    }
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=_mock_vision(payload)):
        s.tryon_input_check_enabled = True
        result = await check_garment_photo(b"fake")
    assert result.ok is True


@pytest.mark.asyncio
async def test_vision_call_failure_fails_open():
    """The checker being down must never block try-on entirely."""
    with patch("app.services.tryon_input_check.settings") as s, \
         patch(
             "app.services.tryon_input_check.vision",
             new=AsyncMock(side_effect=RuntimeError("provider down")),
         ):
        s.tryon_input_check_enabled = True
        result = await check_garment_photo(b"fake")
    assert result.ok is True
    assert result.checked is False


@pytest.mark.asyncio
async def test_disabled_via_settings_skips_check_entirely():
    with patch("app.services.tryon_input_check.settings") as s, \
         patch("app.services.tryon_input_check.vision", new=AsyncMock()) as mock_vision:
        s.tryon_input_check_enabled = False
        result = await check_person_photo(b"fake")
    assert result.ok is True
    assert result.checked is False
    mock_vision.assert_not_awaited()


@pytest.mark.asyncio
async def test_malformed_vision_response_fails_open():
    """Non-JSON model output must not crash the pipeline."""
    with patch("app.services.tryon_input_check.settings") as s, \
         patch(
             "app.services.tryon_input_check.vision",
             new=AsyncMock(return_value=_FakeCall(text="not json at all")),
         ):
        s.tryon_input_check_enabled = True
        result = await check_person_photo(b"fake")
    assert result.ok is True
    assert result.checked is False
