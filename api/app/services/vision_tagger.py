"""Vision tagging for clothing items via the AI provider abstraction."""

import asyncio
import json
import logging

from app.services.ai_provider import Role, vision

logger = logging.getLogger(__name__)

VISION_PROMPT = """You are a fashion item tagger for an Indian wardrobe app.

Analyze this clothing/accessory image and return a JSON object with these exact fields:

{
  "category": "top|bottom|footwear|accessory|outerwear|ethnic",
  "sub_category": "<specific type, e.g. kurta, polo, chinos, sneakers, dupatta>",
  "primary_color": "<dominant color, lowercase, e.g. navy, maroon, beige>",
  "secondary_colors": ["<other visible colors>"],
  "pattern": "solid|striped|checked|printed|floral|geometric|embroidered|abstract",
  "fabric": "<best guess: cotton, silk, polyester, denim, linen, wool, chiffon, georgette, etc>",
  "style_tags": ["<relevant style tags: casual, formal, ethnic, festive, sporty, streetwear, classic, bohemian, minimal>"],
  "formality": <1-5 integer: 1=very casual, 2=casual, 3=smart casual, 4=semi-formal, 5=formal>,
  "season_tags": ["<summer, winter, monsoon, all_season>"],
  "ethnic_flag": <true if this is Indian ethnic wear (kurta, saree, lehenga, sherwani, etc), false otherwise>,
  "confidence": <0.0-1.0 your confidence in the overall tagging>
}

Rules:
- For Indian ethnic wear: use specific sub_categories (kurta, churidar, saree, lehenga, sherwani, nehru_jacket, dupatta, mojari, kolhapuri, juttis)
- If the item is clearly a full outfit (like saree with blouse), tag the primary garment
- If unsure between two categories, pick the more specific one
- Color names should be simple (navy, not "dark navy blue")
- Return ONLY the JSON object, no markdown, no explanation
"""


def _strip_md(content: str) -> str:
    if content.startswith("```"):
        content = content.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    return content


async def tag_item(image_bytes: bytes) -> dict:
    """Send image to vision model for tagging. Auto-failover across providers."""
    delays = [3, 8]
    last_error = None

    for attempt in range(3):
        try:
            result = await vision(Role.VISION, image_bytes, VISION_PROMPT,
                                  mime="image/png")
            content = _strip_md(result.text)
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
