"""Generate text embeddings for wardrobe items via the AI provider abstraction."""

import logging

from app.services.ai_provider import embed

logger = logging.getLogger(__name__)


def _build_embedding_text(tags: dict) -> str:
    parts = [
        tags.get("category", ""),
        tags.get("sub_category", ""),
        tags.get("primary_color", ""),
        tags.get("pattern", ""),
        tags.get("fabric", ""),
    ]
    parts.extend(tags.get("style_tags", []))
    parts.extend(tags.get("season_tags", []))
    if tags.get("ethnic_flag"):
        parts.append("indian ethnic")
    parts.extend(tags.get("secondary_colors", []))
    return " ".join(p for p in parts if p)


async def generate_embedding(tags: dict) -> list[float]:
    """Generate embedding from item tags. Falls back across providers."""
    text = _build_embedding_text(tags)
    logger.debug(f"Embedding text: {text}")
    vec = await embed(text)
    logger.info(f"Generated embedding: {len(vec)} dimensions")
    return vec
