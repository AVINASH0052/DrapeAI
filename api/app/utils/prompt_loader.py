"""Load versioned prompt templates from api/prompts/."""

from functools import lru_cache
from pathlib import Path

_PROMPTS_DIR = Path(__file__).resolve().parents[2] / "prompts"


@lru_cache(maxsize=16)
def load_prompt(name: str) -> str:
    """Load a prompt file by stem name (e.g. 'vision_tag', 'outfit_rank')."""
    path = _PROMPTS_DIR / f"{name}.md"
    if not path.exists():
        raise FileNotFoundError(f"Prompt not found: {path}")
    return path.read_text(encoding="utf-8").strip()
