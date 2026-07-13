"""Helpers for parsing JSON out of LLM responses."""

import re

_THINK_RE = re.compile(r"<think>.*?(</think>|$)", re.DOTALL)


def strip_markdown_fence(text: str) -> str:
    """Remove a surrounding ```...``` code fence if the model wrapped its output."""
    text = text.strip()
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0].strip()
    return text


def extract_json(text: str) -> str:
    """Best-effort extraction of a JSON value from an LLM response.

    Handles reasoning models (Nemotron, DeepSeek) that emit <think>...</think>
    blocks and prose before the JSON, plus markdown fences.
    """
    text = _THINK_RE.sub("", text)
    text = strip_markdown_fence(text)
    # Slice from the first JSON opener to the matching last closer
    for opener, closer in (("[", "]"), ("{", "}")):
        start = text.find(opener)
        end = text.rfind(closer)
        if start != -1 and end > start:
            return text[start : end + 1]
    return text
