"""Deterministic outfit generation engine.

Pipeline: filter wardrobe -> build combos -> score each -> return top 20 candidates.
No LLM calls. Pure Python logic. Fast (<100ms for 50 items).
"""

import json
import random
import logging
from itertools import product as cartesian_product

logger = logging.getLogger(__name__)

# --- Constants ---

OCCASION_FORMALITY = {
    "casual": (1, 3),
    "work": (3, 5),
    "party": (3, 5),
    "gym": (1, 2),
    "date": (3, 4),
    "festive": (4, 5),
    "travel": (1, 3),
}

WEATHER_SEASON_MAP = {
    "hot": ["summer", "all_season"],
    "warm": ["summer", "all_season"],
    "cool": ["winter", "all_season"],
    "cold": ["winter"],
    "rain": ["monsoon", "all_season"],
}

GOOD_COLOR_PAIRS = {
    ("navy", "white"), ("navy", "beige"), ("navy", "cream"),
    ("black", "white"), ("black", "grey"), ("black", "red"),
    ("maroon", "cream"), ("maroon", "gold"), ("maroon", "beige"),
    ("olive", "cream"), ("olive", "brown"), ("olive", "white"),
    ("grey", "white"), ("grey", "black"), ("grey", "navy"),
    ("brown", "cream"), ("brown", "beige"), ("brown", "white"),
    ("white", "navy"), ("white", "black"), ("white", "blue"),
    ("beige", "brown"), ("beige", "navy"), ("beige", "olive"),
    ("blue", "white"), ("blue", "grey"), ("blue", "beige"),
    ("cream", "maroon"), ("cream", "navy"), ("cream", "brown"),
}

CLASHING_PAIRS = {
    ("red", "orange"), ("red", "pink"), ("red", "green"),
    ("brown", "black"), ("navy", "black"),
    ("orange", "pink"), ("purple", "orange"),
}

ETHNIC_GOOD_COMBOS = [
    ("nehru_jacket", "shirt"), ("nehru_jacket", "t_shirt"),
    ("kurta", "jeans"), ("kurta", "chinos"),
    ("dupatta", "kurta"),
]

ETHNIC_BAD_COMBOS = [
    ("kurta", "shorts"), ("sherwani", "jeans"),
    ("saree", "sneakers"), ("lehenga", "sneakers"),
]


def _temp_to_weather(temp: int) -> str:
    if temp > 30:
        return "hot"
    elif temp > 20:
        return "warm"
    elif temp > 10:
        return "cool"
    return "cold"


def _season_tags(item: dict) -> list:
    """season_tags is a jsonb column; asyncpg returns it as a JSON string."""
    value = item.get("season_tags")
    if isinstance(value, str):
        try:
            value = json.loads(value)
        except (ValueError, TypeError):
            value = None
    return value if isinstance(value, list) and value else ["all_season"]


def filter_wardrobe(
    items: list[dict], occasion: str, weather: dict | None
) -> dict[str, list[dict]]:
    """Filter items by occasion formality, season, and weather. Group by category."""
    min_f, max_f = OCCASION_FORMALITY.get(occasion, (1, 5))

    allowed_seasons = {"all_season"}
    if weather:
        temp = weather.get("temp", 25)
        condition = weather.get("condition", "clear")
        w_key = _temp_to_weather(temp)
        allowed_seasons.update(WEATHER_SEASON_MAP.get(w_key, ["all_season"]))
        if "rain" in condition.lower():
            allowed_seasons.update(WEATHER_SEASON_MAP["rain"])

    groups: dict[str, list[dict]] = {}
    for item in items:
        if not (min_f <= item.get("formality", 3) <= max_f):
            continue
        item_seasons = set(_season_tags(item))
        if not item_seasons.intersection(allowed_seasons):
            continue
        cat = item["category"]
        groups.setdefault(cat, []).append(item)

    return groups


def build_candidates(
    groups: dict[str, list[dict]], occasion: str
) -> list[list[dict]]:
    """Generate outfit combos from filtered groups."""
    candidates = []

    tops = groups.get("top", [])
    bottoms = groups.get("bottom", [])
    footwear = groups.get("footwear", [])
    outerwear = groups.get("outerwear", [])
    accessories = groups.get("accessory", [])
    ethnic = groups.get("ethnic", [])

    # Standard combos: top + bottom + footwear
    if tops and bottoms:
        for t, b in cartesian_product(tops, bottoms):
            combo = [t, b]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Ethnic standalone (saree, lehenga, sherwani)
    standalone_types = {"saree", "lehenga", "sherwani", "anarkali"}
    for e in ethnic:
        if e.get("sub_category") in standalone_types:
            combo = [e]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Ethnic fusion: ethnic top + western bottom
    ethnic_tops = [
        e for e in ethnic if e.get("sub_category") in {"kurta", "nehru_jacket"}
    ]
    for et in ethnic_tops:
        for b in bottoms:
            combo = [et, b]
            if footwear:
                combo.append(random.choice(footwear))
            candidates.append(combo)

    # Augment with outerwear for top 10
    if outerwear:
        augmented = []
        for combo in candidates[:10]:
            aug = combo + [random.choice(outerwear)]
            augmented.append(aug)
        candidates.extend(augmented)

    # Augment with accessories for social occasions
    if accessories and occasion in ("party", "date", "festive", "work"):
        for combo in candidates[:5]:
            combo.append(random.choice(accessories))

    return candidates


def score_combo(combo: list[dict]) -> float:
    """Score an outfit combo 0-100. Higher is better."""
    score = 0.0

    colors = [item.get("primary_color", "unknown") for item in combo]
    formalities = [item.get("formality", 3) for item in combo]
    sub_cats = [item.get("sub_category", "") for item in combo]
    patterns = [item.get("pattern", "solid") for item in combo]
    ethnic_flags = [item.get("ethnic_flag", False) for item in combo]

    # Color harmony (40 pts)
    color_score = 20.0
    for i in range(len(colors)):
        for j in range(i + 1, len(colors)):
            pair = (colors[i], colors[j])
            pair_rev = (colors[j], colors[i])
            if pair in GOOD_COLOR_PAIRS or pair_rev in GOOD_COLOR_PAIRS:
                color_score += 10
            elif pair in CLASHING_PAIRS or pair_rev in CLASHING_PAIRS:
                color_score -= 15
            elif colors[i] == colors[j] and colors[i] not in ("black", "white", "grey"):
                color_score -= 5
    score += min(max(color_score, 0), 40)

    # Formality consistency (30 pts)
    if formalities:
        f_range = max(formalities) - min(formalities)
        if f_range <= 1:
            score += 30
        elif f_range == 2:
            score += 20
        else:
            score += 5

    # Ethnic fusion quality (20 pts)
    has_ethnic = any(ethnic_flags)
    has_western = any(not f for f in ethnic_flags)
    if has_ethnic and has_western:
        sub_pairs = [
            (sub_cats[i], sub_cats[j])
            for i in range(len(sub_cats))
            for j in range(i + 1, len(sub_cats))
        ]
        good_fusion = any(
            p in ETHNIC_GOOD_COMBOS or (p[1], p[0]) in ETHNIC_GOOD_COMBOS
            for p in sub_pairs
        )
        bad_fusion = any(
            p in ETHNIC_BAD_COMBOS or (p[1], p[0]) in ETHNIC_BAD_COMBOS
            for p in sub_pairs
        )
        if good_fusion:
            score += 20
        elif bad_fusion:
            score += 0
        else:
            score += 10
    elif has_ethnic and not has_western:
        score += 18
    else:
        score += 15

    # Pattern clash avoidance (10 pts)
    non_solid = [p for p in patterns if p != "solid"]
    if len(non_solid) == 0:
        score += 8
    elif len(non_solid) == 1:
        score += 10
    elif len(non_solid) == 2 and len(set(non_solid)) == 2:
        score += 3
    else:
        score += 0

    return round(score, 1)


def generate_candidates(
    items: list[dict],
    occasion: str,
    weather: dict | None = None,
    max_candidates: int = 20,
) -> list[dict]:
    """Main entry point. Returns up to max_candidates scored combos, sorted by score.

    Each returned dict: {"items": [...], "score": float}
    """
    groups = filter_wardrobe(items, occasion, weather)

    if not groups:
        logger.warning(f"No items match filters for occasion={occasion}")
        return []

    combos = build_candidates(groups, occasion)

    if not combos:
        logger.warning("No valid combos generated")
        return []

    scored = [{"items": combo, "score": score_combo(combo)} for combo in combos]
    scored.sort(key=lambda x: x["score"], reverse=True)
    result = scored[:max_candidates]

    logger.info(
        f"Rule engine: {len(combos)} combos -> top {len(result)} "
        f"(scores: {result[0]['score']}-{result[-1]['score']})"
    )
    return result
