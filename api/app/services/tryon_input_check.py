"""Pre-flight validation of try-on reference photos via the vision LLM.

Catches the failure class where a garment or person photo doesn't show what
the generation model needs (e.g. a back-view garment shot) — the AI has no
information to reconstruct the front, and silently produces a garbled or
partial result instead of failing loudly. Runs before spending a generation
call, using the same vision-provider chain as wardrobe tagging.
"""

from __future__ import annotations

import json
import logging
from dataclasses import dataclass

from app.config import settings
from app.services.ai_provider import Role, vision
from app.utils.llm_json import extract_json
from app.utils.prompt_loader import load_prompt

logger = logging.getLogger(__name__)

PERSON_PROMPT = load_prompt("tryon_check_person")
GARMENT_PROMPT = load_prompt("tryon_check_garment")

# Below this confidence, don't block — an uncertain model call shouldn't
# frustrate a user with a false rejection.
_MIN_CONFIDENCE_TO_BLOCK = 0.6


@dataclass
class InputCheckResult:
    ok: bool
    issue: str = "none"
    reason: str = ""
    confidence: float = 0.0
    checked: bool = True  # False when the checker itself failed (fail-open)


class InputCheckFailed(Exception):
    def __init__(self, reason: str, issue: str = "other"):
        self.reason = reason
        self.issue = issue
        super().__init__(reason)


async def _run_check(image_bytes: bytes, prompt: str) -> dict:
    result = await vision(Role.VISION, image_bytes, prompt, mime="image/png")
    content = extract_json(result.text)
    return json.loads(content)


async def check_person_photo(image_bytes: bytes) -> InputCheckResult:
    """Validate a full-body try-on reference photo. Fails open on checker errors."""
    if not settings.tryon_input_check_enabled:
        return InputCheckResult(ok=True, checked=False)
    try:
        data = await _run_check(image_bytes, PERSON_PROMPT)
    except Exception as e:
        logger.warning(f"tryon input check (person) skipped — vision call failed: {e!r}")
        return InputCheckResult(ok=True, checked=False)

    issue = data.get("issue") or "none"
    confidence = float(data.get("confidence") or 0.0)
    passed = (
        issue == "none"
        and data.get("full_body", True)
        and data.get("front_facing", True)
        and data.get("single_person", True)
    )
    if passed or confidence < _MIN_CONFIDENCE_TO_BLOCK:
        return InputCheckResult(ok=True, issue=issue, confidence=confidence)

    reason = data.get("reason") or "This photo doesn't look like a clear front-facing full-body shot."
    return InputCheckResult(ok=False, issue=issue, reason=reason, confidence=confidence)


async def check_garment_photo(image_bytes: bytes) -> InputCheckResult:
    """Validate a wardrobe item photo used as a try-on garment reference."""
    if not settings.tryon_input_check_enabled:
        return InputCheckResult(ok=True, checked=False)
    try:
        data = await _run_check(image_bytes, GARMENT_PROMPT)
    except Exception as e:
        logger.warning(f"tryon input check (garment) skipped — vision call failed: {e!r}")
        return InputCheckResult(ok=True, checked=False)

    issue = data.get("issue") or "none"
    confidence = float(data.get("confidence") or 0.0)
    passed = (
        issue == "none"
        and data.get("front_facing", True)
        and data.get("garment_visible", True)
    )
    if passed or confidence < _MIN_CONFIDENCE_TO_BLOCK:
        return InputCheckResult(ok=True, issue=issue, confidence=confidence)

    reason = data.get("reason") or "This garment photo doesn't clearly show the front of the item."
    return InputCheckResult(ok=False, issue=issue, reason=reason, confidence=confidence)
