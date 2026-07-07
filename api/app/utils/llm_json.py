"""Helpers for parsing JSON out of LLM responses."""


def strip_markdown_fence(text: str) -> str:
    """Remove a surrounding ```...``` code fence if the model wrapped its output."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    return text
