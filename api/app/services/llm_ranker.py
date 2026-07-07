"""LLM-based outfit ranking with personalization from feedback history.

Routes to Role.RANK in the AI provider abstraction (default: Claude Haiku
primary, GPT-4o-mini secondary, NVIDIA Llama-3.3 free tertiary).
"""

import asyncio
import json
import logging

from app.services.ai_provider import Role, chat
from app.services.personalization import format_feedback_for_prompt
from app.utils.llm_json import strip_markdown_fence

logger = logging.getLogger(__name__)

RANKER_PROMPT_TEMPLATE = """You are a personal stylist for an Indian user.

User profile:
- Name: {name}
- Age: {age}
- Gender: {gender}
- Body type: {body_type}
- Skin undertone: {skin_undertone}
- Style goals: {style_goals}
- Color preferences: {color_preferences}
- Fit preference: {fit_preference}
- Lifestyle: {lifestyle}
- Budget tier: {budget_tier}

Occasion: {occasion}
Weather: {weather_desc}

{feedback_section}

Here are {n} outfit candidates (scored by a rule engine). Pick the best 3 and explain why.

Candidates:
{candidates_text}

Return a JSON array of exactly 3 objects:
[
  {{
    "index": <0-based index of the candidate>,
    "reason": "<1-2 sentence styling explanation tailored to this user, no emojis>"
  }}
]

Rules:
- Pick outfits that look cohesive AND match the user's documented preferences/feedback patterns
- Prefer variety (don't pick 3 similar outfits)
- Consider Indian fashion context (ethnic fusion is good when done right)
- Tailor language to the user (mention skin tone, body type, or lifestyle if relevant)
- Keep reasons concise (1-2 sentences), practical, and emoji-free
- Return ONLY the JSON array, no markdown
"""


def _format_candidates(candidates: list[dict]) -> str:
    lines = []
    for i, c in enumerate(candidates):
        items_desc = ", ".join(
            f"{it.get('sub_category', it.get('category', '?'))} ({it.get('primary_color', '?')})"
            for it in c["items"]
        )
        lines.append(f"[{i}] Score: {c['score']} | {items_desc}")
    return "\n".join(lines)


async def rank_outfits(
    candidates: list[dict],
    preferences: dict,
    occasion: str,
    weather: dict | None = None,
    feedback: list[dict] | None = None,
) -> list[dict]:
    """Rank outfit candidates via LLM. Returns top 3 with reasons.

    The `feedback` argument is a list of prior outfit_feedback events from
    personalization.get_recent_feedback(); it is rendered into the prompt.
    """
    weather_desc = "Unknown"
    if weather:
        weather_desc = f"{weather.get('temp', '?')}C, {weather.get('condition', 'clear')}"

    feedback_section = format_feedback_for_prompt(feedback or [])

    prompt = RANKER_PROMPT_TEMPLATE.format(
        name=preferences.get("name") or "the user",
        age=preferences.get("age") or "unknown",
        gender=preferences.get("gender") or "unknown",
        body_type=preferences.get("body_type") or "unspecified",
        skin_undertone=preferences.get("skin_undertone") or "unspecified",
        style_goals=", ".join(preferences.get("style_goals", [])) or "varied",
        color_preferences=", ".join(preferences.get("color_preferences", [])) or "open",
        fit_preference=preferences.get("fit_preference") or "regular",
        lifestyle=", ".join(preferences.get("lifestyle", [])) or "unspecified",
        budget_tier=preferences.get("budget_tier") or "mid",
        occasion=occasion,
        weather_desc=weather_desc,
        feedback_section=feedback_section,
        n=len(candidates),
        candidates_text=_format_candidates(candidates),
    )

    delays = [3, 8]
    last_error = None

    for attempt in range(3):
        try:
            result = await chat(Role.RANK, prompt, max_tokens=500, temp=0.3)
            content = strip_markdown_fence(result.text)
            picks = json.loads(content)

            output = []
            for pick in picks[:3]:
                idx = pick.get("index", -1)
                if 0 <= idx < len(candidates):
                    candidate = candidates[idx]
                    output.append({
                        "items": candidate["items"],
                        "reason": pick.get("reason"),
                        "rule_score": candidate["score"],
                    })

            if not output:
                raise ValueError("LLM returned no valid picks")

            logger.info(
                f"Ranker via {result.provider}/{result.model}: "
                f"indices={[p.get('index') for p in picks[:3]]}"
            )
            return output

        except Exception as e:
            last_error = e
            logger.warning(f"Ranker attempt {attempt + 1} failed: {e}")
            if attempt < 2:
                await asyncio.sleep(delays[attempt])

    # Final fallback: top 3 from rule engine
    logger.error(f"Ranker failed: {last_error}. Using rule-engine fallback.")
    return [
        {"items": c["items"], "reason": None, "rule_score": c["score"]}
        for c in candidates[:3]
    ]
