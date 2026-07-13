"""Vision tagging for clothing items via the AI provider abstraction."""

import asyncio
import json
import logging

from app.services.ai_provider import Role, vision
from app.utils.llm_json import extract_json
from app.utils.prompt_loader import load_prompt

logger = logging.getLogger(__name__)

VISION_PROMPT = load_prompt("vision_tag")


async def tag_item(image_bytes: bytes) -> dict:
    """Send image to vision model for tagging. Auto-failover across providers."""
    delays = [3, 8]
    last_error = None

    for attempt in range(3):
        try:
            result = await vision(Role.VISION, image_bytes, VISION_PROMPT,
                                  mime="image/png")
            content = extract_json(result.text)
            tags = json.loads(content)
            logger.info(
                f"Vision tagging via {result.provider}: "
                f"{tags.get('category')}/{tags.get('sub_category')} "
                f"(confidence: {tags.get('confidence', 0)})"
            )
            return tags
        except Exception as e:
            last_error = e
            logger.warning(f"Vision tagging attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(delays[attempt])

    raise RuntimeError(f"Vision tagging failed: {last_error}")
