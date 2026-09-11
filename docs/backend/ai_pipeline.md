# Sugatai -- AI Pipeline

> **Partial sync.** Live cascade and roles: [../APPLICATION_DOCUMENTATION.md](../APPLICATION_DOCUMENTATION.md) §6 and `api/app/services/ai_provider.py`. Primary embed is `nvidia/nv-embedqa-e5-v5` (1024-dim), not OpenAI-only 1536.

Detailed specification for every AI component: vision tagging, background removal, embedding generation, rule engine, LLM ranker, and caching.

---

## Table of Contents

- [Pipeline Overview](#pipeline-overview)
- [1. Background Removal](#1-background-removal)
- [2. Vision Tagging (GPT-4o)](#2-vision-tagging-gpt-4o)
- [3. Embedding Generation](#3-embedding-generation)
- [4. Rule Engine (Outfit Candidate Generation)](#4-rule-engine-outfit-candidate-generation)
- [5. LLM Ranker (Outfit Selection)](#5-llm-ranker-outfit-selection)
- [6. Shuffle Engine](#6-shuffle-engine)
- [7. Caching Strategy](#7-caching-strategy)
- [8. Cost Control](#8-cost-control)
- [9. Prompt Templates](#9-prompt-templates)
- [10. Data Moat Collection](#10-data-moat-collection)

---

## Pipeline Overview

Two separate pipelines, triggered at different times:

```
UPLOAD PIPELINE (triggered on each item upload)
  Photo --> bg_remove --> vision_tag --> embed --> store

OUTFIT PIPELINE (triggered on user request)
  wardrobe + prefs + weather + feedback --> rule_engine --> llm_ranker --> cache --> respond
```

---

## 1. Garment split + product extract (upload)

**Primary path:** vision detect (`prompts/garment_detect.md`) + Gemini image extract
(`prompts/garment_extract.md`, model `TRYON_MODEL_PRIMARY`) via `garment_splitter.py`.
A worn t-shirt + pants photo becomes two catalog-style wardrobe images with no person.

**Fallback:** if detection finds no garments (or AI extract fails for all pieces),
whole-image `rembg` background removal still runs (`bg_remover.py`).

## 1b. Background Removal (fallback / legacy)

**Library:** `rembg` (open source, runs locally, no API cost)

**Process:**
```python
from rembg import remove
from PIL import Image
import io

async def remove_background(image_bytes: bytes) -> bytes:
    """Remove background from clothing photo. Returns PNG with transparent bg."""
    loop = asyncio.get_running_loop()
    # rembg is CPU-bound, run in thread pool
    result = await loop.run_in_executor(None, remove, image_bytes)

    # Convert to PNG with white background (for consistent display)
    img = Image.open(io.BytesIO(result)).convert("RGBA")
    white_bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    white_bg.paste(img, mask=img.split()[3])
    output = io.BytesIO()
    white_bg.convert("RGB").save(output, format="PNG", optimize=True)
    return output.getvalue()
```

**Performance:** ~2-4 seconds per image on a 2-core VPS. Acceptable for upload flow.

**Fallback:** If rembg produces poor results (detected by user editing), consider upgrading to `remove.bg` API ($0.10/image) as a paid fallback.

**Thumbnail generation:** After bg removal, also create a 200x200px thumbnail for grid display.
```python
thumb = img.resize((200, 200), Image.LANCZOS)
```

---

## 2. Vision Tagging (GPT-4o)

**Model:** `gpt-4o` (Vision) -- single API call per item, structured JSON output.

**Why GPT-4o over alternatives:**
- Best accuracy on Indian ethnic wear (tested: correctly identifies kurta vs sherwani vs nehru jacket)
- Structured JSON output mode (no regex parsing)
- Handles poor lighting and wrinkled clothes better than CLIP-based alternatives
- ~$0.03 per image (acceptable at scale)

### Prompt Template

```python
VISION_TAG_PROMPT = """You are a fashion item tagger for an Indian wardrobe management app.

Analyze this clothing item photo and return a JSON object with these exact fields:

{
  "category": "top|bottom|outerwear|footwear|accessory|ethnic|full_body",
  "sub_category": "specific type (e.g., kurta, tshirt, jeans, saree, sneakers)",
  "primary_color": "dominant color name (e.g., navy, white, maroon, beige)",
  "secondary_colors": ["list of other visible colors"],
  "pattern": "solid|striped|checked|floral|printed|embroidered|paisley|geometric",
  "fabric": "best guess: cotton|denim|silk|polyester|linen|wool|chiffon|georgette|velvet|leather|synthetic",
  "style_tags": ["list from: casual, formal, sporty, ethnic, fusion, streetwear, bohemian, minimalist, festive, workwear"],
  "formality": 1-5 integer (1=very casual like gym wear, 3=smart casual, 5=very formal like sherwani/suit),
  "season_tags": ["from: summer, winter, monsoon, all_season"],
  "ethnic_flag": true if this is Indian ethnic wear (saree, kurta, lehenga, sherwani, dhoti, salwar, dupatta, anarkali, nehru_jacket),
  "confidence": 0.0-1.0 your confidence in the overall tagging
}

Rules:
- For Indian ethnic wear, be specific: distinguish kurta from sherwani from nehru jacket.
- If the item is a saree or lehenga, category must be "ethnic" not "full_body".
- Dupatta is an accessory with ethnic_flag=true.
- Color names should be common English: navy, maroon, olive, cream, not "dark blue" or "reddish brown".
- If you cannot determine fabric, use "synthetic" as default.
- Return ONLY the JSON object, no other text."""
```

### API Call

```python
import httpx
import json

async def tag_item(image_bytes: bytes) -> dict:
    """Tag a clothing item using GPT-4o Vision. Returns parsed tag dict."""
    import base64
    b64_image = base64.b64encode(image_bytes).decode("utf-8")

    payload = {
        "model": "gpt-4o",
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": VISION_TAG_PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/png;base64,{b64_image}",
                            "detail": "low"  # low detail = cheaper, sufficient for clothing
                        }
                    }
                ]
            }
        ],
        "response_format": {"type": "json_object"},
        "max_tokens": 300,
        "temperature": 0.1  # low temperature for consistent tagging
    }

    async with httpx.AsyncClient(timeout=30) as client:
        for attempt in range(3):
            try:
                response = await client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
                    json=payload,
                )
                response.raise_for_status()
                content = response.json()["choices"][0]["message"]["content"]
                tags = json.loads(content)
                validate_tags(tags)  # schema validation
                return tags
            except Exception as e:
                logger.warning(f"Vision tag attempt {attempt + 1} failed: {e}")
                if attempt < 2:
                    await asyncio.sleep(RETRY_DELAYS[attempt])
                else:
                    raise

def validate_tags(tags: dict) -> None:
    """Validate tag schema. Raises ValueError on invalid tags."""
    required = ["category", "sub_category", "primary_color", "formality", "ethnic_flag"]
    for field in required:
        if field not in tags:
            raise ValueError(f"Missing required field: {field}")
    if tags["category"] not in VALID_CATEGORIES:
        raise ValueError(f"Invalid category: {tags['category']}")
    if not 1 <= tags["formality"] <= 5:
        raise ValueError(f"Formality must be 1-5, got: {tags['formality']}")
```

**Cost per image:** ~$0.03 (low detail mode + structured output + 300 max tokens)

---

## 3. Embedding Generation

**Model:** OpenAI `text-embedding-3-small` -- 1536 dimensions, $0.00002 per 1K tokens.

**Input:** A text string built from the item's tags:
```python
def build_embedding_text(tags: dict) -> str:
    """Build text string from tags for embedding generation."""
    parts = [
        tags["category"],
        tags["sub_category"],
        tags["primary_color"],
        tags.get("pattern", "solid"),
        tags.get("fabric", ""),
        " ".join(tags.get("style_tags", [])),
        f"formality {tags['formality']}",
        " ".join(tags.get("season_tags", [])),
        "ethnic" if tags.get("ethnic_flag") else "western",
    ]
    return " ".join(filter(None, parts))
    # Example: "top kurta navy embroidered cotton ethnic festive formality 4 all_season ethnic"
```

**API call:**
```python
async def generate_embedding(text: str) -> list[float]:
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            "https://api.openai.com/v1/embeddings",
            headers={"Authorization": f"Bearer {OPENAI_API_KEY}"},
            json={"model": "text-embedding-3-small", "input": text},
        )
        return response.json()["data"][0]["embedding"]
```

**Usage:** Stored in pgvector column. Used for:
- Finding similar items (gap analysis in V2)
- Duplicate detection (before upload)
- Grouping items for outfit diversity

---

## 4. Rule Engine (Outfit Candidate Generation)

The rule engine is deterministic Python code. No LLM. No randomness. It generates the candidate pool that the LLM ranker selects from.

### Input
```python
@dataclass
class OutfitRequest:
    wardrobe: list[Item]          # all active items
    preferences: UserPreferences  # from onboarding quiz
    weather: Weather              # temp, condition
    occasion: str                 # casual, work, party, etc.
    feedback_history: list[Feedback]  # recent likes/dislikes
```

### Step 1: Filter

Remove items that do not match the occasion + weather + season:

```python
def filter_wardrobe(items: list[Item], occasion: str, weather: Weather) -> list[Item]:
    filtered = []
    for item in items:
        # Season filter
        season = get_season(weather.temp)
        if season not in item.season_tags and "all_season" not in item.season_tags:
            continue

        # Occasion-formality filter
        formality_range = OCCASION_FORMALITY[occasion]  # e.g., casual = (1, 3), work = (3, 5)
        if not (formality_range[0] <= item.formality <= formality_range[1]):
            continue

        # Weather filter
        if weather.temp > 30 and item.category == "outerwear" and item.sub_category != "light_jacket":
            continue
        if weather.condition == "rain" and item.fabric == "silk":
            continue

        filtered.append(item)
    return filtered

OCCASION_FORMALITY = {
    "casual":  (1, 3),
    "work":    (3, 5),
    "party":   (2, 4),
    "gym":     (1, 2),
    "date":    (3, 4),
    "festive": (3, 5),
    "travel":  (1, 3),
}
```

### Step 2: Build Combinations

```python
def build_candidates(filtered: list[Item], occasion: str) -> list[OutfitCandidate]:
    tops = [i for i in filtered if i.category in ("top", "ethnic") and i.sub_category not in STANDALONE_ETHNIC]
    bottoms = [i for i in filtered if i.category == "bottom"]
    footwear = [i for i in filtered if i.category == "footwear"]
    outerwear = [i for i in filtered if i.category == "outerwear"]
    accessories = [i for i in filtered if i.category == "accessory"]
    standalone = [i for i in filtered if i.category == "ethnic" and i.sub_category in STANDALONE_ETHNIC]
    full_body = [i for i in filtered if i.category == "full_body"]

    candidates = []

    # Standard combos: top + bottom + footwear
    for top in tops:
        for bottom in bottoms:
            for shoe in footwear:
                score = score_combo(top, bottom, shoe, None, occasion)
                if score > MINIMUM_SCORE:
                    candidates.append(OutfitCandidate(
                        items=[top, bottom, shoe],
                        rule_score=score,
                    ))

    # Full body + footwear
    for fb in full_body:
        for shoe in footwear:
            score = score_combo(fb, None, shoe, None, occasion)
            if score > MINIMUM_SCORE:
                candidates.append(OutfitCandidate(items=[fb, shoe], rule_score=score))

    # Standalone ethnic (saree, lehenga) + footwear
    for eth in standalone:
        for shoe in footwear:
            score = score_combo(eth, None, shoe, None, occasion)
            if score > MINIMUM_SCORE:
                candidates.append(OutfitCandidate(items=[eth, shoe], rule_score=score))

    # Add optional outerwear/accessories to top candidates
    candidates.sort(key=lambda c: c.rule_score, reverse=True)
    for c in candidates[:50]:
        augment_with_layers(c, outerwear, accessories, occasion)

    # Return top 20 by score
    candidates.sort(key=lambda c: c.rule_score, reverse=True)
    return candidates[:20]

STANDALONE_ETHNIC = {"saree", "lehenga", "sherwani"}
MINIMUM_SCORE = 40  # out of 100
```

### Step 3: Scoring

```python
def score_combo(top: Item, bottom: Item | None, shoe: Item, outerwear: Item | None, occasion: str) -> float:
    score = 50.0  # base score

    # Color harmony (+/- 20 points)
    score += color_harmony_score(
        top.primary_color,
        bottom.primary_color if bottom else None,
        shoe.primary_color,
    )

    # Formality consistency (+/- 15 points)
    formalities = [i.formality for i in [top, bottom, shoe] if i]
    spread = max(formalities) - min(formalities)
    score += max(0, 15 - (spread * 7))

    # Ethnic fusion rules (+/- 10 points)
    score += ethnic_fusion_score(top, bottom, shoe)

    # Pattern clash (-10 points if too many patterns)
    patterns = [i.pattern for i in [top, bottom] if i and i.pattern != "solid"]
    if len(patterns) > 1:
        score -= 10

    # Diversity bonus (+5 if items not recently worn together)
    # (based on feedback_history, checked externally)

    return max(0, min(100, score))

def color_harmony_score(color1: str, color2: str | None, color3: str) -> float:
    """Score color combination. Returns -20 to +20."""
    colors = [c for c in [color1, color2, color3] if c]

    # Neutral anchors always work
    neutrals = {"black", "white", "navy", "grey", "beige", "cream", "khaki"}
    neutral_count = sum(1 for c in colors if c in neutrals)
    if neutral_count >= len(colors) - 1:
        return 15  # at most 1 non-neutral = safe

    # Complementary pairs
    GOOD_PAIRS = {
        frozenset({"navy", "white"}): 20,
        frozenset({"navy", "beige"}): 18,
        frozenset({"black", "white"}): 18,
        frozenset({"olive", "cream"}): 16,
        frozenset({"maroon", "beige"}): 16,
        frozenset({"navy", "maroon"}): 14,
        frozenset({"blue", "white"}): 18,
        frozenset({"brown", "beige"}): 16,
    }
    for pair, bonus in GOOD_PAIRS.items():
        if pair.issubset(set(colors)):
            return bonus

    # Monochrome bonus
    if len(set(colors)) == 1:
        return 10

    # Clashing colors
    CLASHING = [
        frozenset({"red", "green"}),
        frozenset({"red", "orange"}),
        frozenset({"pink", "red"}),
    ]
    for clash in CLASHING:
        if clash.issubset(set(colors)):
            return -15

    return 0  # unknown = neutral score

def ethnic_fusion_score(top: Item, bottom: Item | None, shoe: Item) -> float:
    """Score ethnic-western fusion combinations."""
    if not top.ethnic_flag:
        return 0

    # Good fusions
    if top.sub_category == "kurta" and bottom and bottom.sub_category in ("jeans", "chinos", "palazzo"):
        return 10  # kurta + jeans/chinos = good fusion
    if top.sub_category == "kurta" and shoe.sub_category in ("sneakers", "loafers", "kolhapuri"):
        return 8

    # Bad fusions
    if top.sub_category == "sherwani" and bottom and bottom.sub_category == "jeans":
        return -15  # sherwani + jeans = no
    if top.sub_category == "sherwani" and shoe.sub_category == "sneakers":
        return -10  # sherwani + sneakers = no

    return 0
```

---

## 5. LLM Ranker (Outfit Selection)

After the rule engine produces 20 candidates, GPT-4o ranks them down to the top 3 and provides styling explanations.

### Prompt Template

```python
LLM_RANKER_PROMPT = """You are a personal stylist for an Indian user. Given outfit candidates from their wardrobe, select the 3 best outfits and explain why.

USER PROFILE:
{user_profile_json}

WEATHER: {temp}C, {condition}

OCCASION: {occasion}

RECENT FEEDBACK (last 10):
{feedback_summary}

CANDIDATES (each is a list of items):
{candidates_json}

Return a JSON object:
{{
  "selected": [
    {{
      "candidate_index": 0,
      "reason": "One sentence explaining why this outfit works for the occasion and user's style."
    }},
    {{
      "candidate_index": 3,
      "reason": "..."
    }},
    {{
      "candidate_index": 7,
      "reason": "..."
    }}
  ]
}}

Rules:
- Select exactly 3 candidates by their index.
- Each reason must be 1 sentence, max 20 words.
- Prioritize variety: don't pick 3 outfits that look the same.
- If user recently disliked a color combo, avoid it.
- For festive/date occasions, lean slightly more formal.
- Mention specific items by color and type in the reason.
- Return ONLY the JSON object."""
```

### API Call

```python
async def rank_outfits(
    candidates: list[OutfitCandidate],
    user_profile: dict,
    weather: dict,
    occasion: str,
    feedback_history: list[dict],
) -> list[RankedOutfit]:
    # Build feedback summary (last 10 actions)
    feedback_summary = "\n".join(
        f"- {'Liked' if f['action'] == 'like' else 'Disliked'}: {f['description']}"
        for f in feedback_history[:10]
    )

    # Build candidates JSON (compact, only relevant fields)
    candidates_json = json.dumps([
        {
            "index": i,
            "items": [
                {"category": it.category, "sub_category": it.sub_category,
                 "color": it.primary_color, "pattern": it.pattern,
                 "formality": it.formality, "ethnic": it.ethnic_flag}
                for it in c.items
            ],
            "rule_score": c.rule_score,
        }
        for i, c in enumerate(candidates)
    ], indent=None)

    prompt = LLM_RANKER_PROMPT.format(
        user_profile_json=json.dumps(user_profile),
        temp=weather["temp"],
        condition=weather["condition"],
        occasion=occasion,
        feedback_summary=feedback_summary or "No feedback yet.",
        candidates_json=candidates_json,
    )

    payload = {
        "model": "gpt-4o",
        "messages": [{"role": "user", "content": prompt}],
        "response_format": {"type": "json_object"},
        "max_tokens": 200,
        "temperature": 0.3,
    }

    response = await call_with_retry(openai_chat, payload)
    result = json.loads(response["choices"][0]["message"]["content"])

    # Validate: must have exactly 3 selections with valid indices
    if len(result["selected"]) != 3:
        raise ValueError("LLM returned != 3 selections")
    for sel in result["selected"]:
        if sel["candidate_index"] >= len(candidates):
            raise ValueError(f"Invalid candidate index: {sel['candidate_index']}")

    return [
        RankedOutfit(
            items=candidates[sel["candidate_index"]].items,
            rule_score=candidates[sel["candidate_index"]].rule_score,
            llm_rank=rank + 1,
            llm_reason=sel["reason"],
        )
        for rank, sel in enumerate(result["selected"])
    ]
```

**Cost per generation:** ~$0.01 (200 max tokens, structured output, input ~800 tokens)
**Total per user per day:** ~$0.04 (one generation of 3 outfits + one cache hit for subsequent checks)

---

## 6. Shuffle Engine

Shuffle does NOT use the LLM. It uses only the rule engine + randomness.

```python
async def shuffle_outfit(user_id: str, occasion: str) -> Outfit:
    wardrobe = await get_user_items(user_id)
    weather = await get_weather(user_city)
    filtered = filter_wardrobe(wardrobe, occasion, weather)

    # Build one random valid combo
    import random
    tops = [i for i in filtered if i.category in ("top", "ethnic")]
    bottoms = [i for i in filtered if i.category == "bottom"]
    footwear = [i for i in filtered if i.category == "footwear"]

    for _ in range(50):  # max attempts
        top = random.choice(tops) if tops else None
        bottom = random.choice(bottoms) if bottoms else None
        shoe = random.choice(footwear) if footwear else None

        if not top or not shoe:
            break

        score = score_combo(top, bottom, shoe, None, occasion)
        if score >= MINIMUM_SCORE:
            return Outfit(
                items=[i for i in [top, bottom, shoe] if i],
                rule_score=score,
                generated_by="shuffle",
            )

    # Fallback: return best scoring combo from rule engine
    candidates = build_candidates(filtered, occasion)
    if candidates:
        c = random.choice(candidates[:5])
        return Outfit(items=c.items, rule_score=c.rule_score, generated_by="shuffle")

    raise HTTPException(status_code=400, detail="Not enough items to create an outfit")
```

---

## 7. Caching Strategy

### Outfit cache
- Key: `(user_id, date, occasion)`
- TTL: 24 hours
- Invalidation: when user adds/removes/edits an item
- Storage: `outfit_cache` PostgreSQL table

```python
async def get_or_generate_outfits(user_id: str, occasion: str) -> list[Outfit]:
    today = date.today()

    # Check cache
    cached = await get_outfit_cache(user_id, today, occasion)
    if cached:
        return cached

    # Generate fresh
    outfits = await generate_outfits(user_id, occasion)

    # Store in cache
    await set_outfit_cache(user_id, today, occasion, outfits, ttl_hours=24)

    return outfits
```

### Weather cache
- Key: `city`
- TTL: 1 hour
- Storage: `weather_cache` PostgreSQL table

### Vision tag cache
- Not cached -- each upload is unique. But results are persisted in the `items` table.

---

## 8. Cost Control

### Monthly budget limits

```python
# In settings.py
OPENAI_MONTHLY_BUDGET_USD = float(os.getenv("OPENAI_SPEND_CAP", "20"))

# Track daily spend
async def check_spend_limit():
    today_spend = await get_today_openai_spend()
    daily_limit = OPENAI_MONTHLY_BUDGET_USD / 30
    if today_spend >= daily_limit:
        logger.warning(f"Daily OpenAI spend limit reached: ${today_spend:.2f}")
        raise HTTPException(status_code=503, detail="AI service temporarily unavailable. Try again tomorrow.")
```

### Cost breakdown per 1,000 MAU

| Operation | Volume | Unit Cost | Monthly |
|---|---|---|---|
| Vision tagging | 30 items/user x 1000 (one-time) | $0.03/item | $900 one-time, then ~$150/mo (new items) |
| Outfit generation | 1 gen/user/day x 1000 x 30 | $0.01/gen | $300/mo |
| Embeddings | 30 items/user x 1000 | $0.00002/1K tokens | ~$1/mo |
| **Total AI cost** | | | **~$450/mo (~Rs 37,000)** |

At 100 MAU (launch): ~$45/mo (~Rs 3,700). Very manageable.

### Cost reduction strategies
1. `detail: "low"` on Vision calls (saves ~60% vs high detail)
2. 24h outfit cache (user gets 1 AI generation per occasion per day)
3. Shuffle uses rule engine only (zero AI cost)
4. Batch vision calls where possible (batch upload)
5. Embeddings are cheap enough to not worry about

---

## 9. Prompt Templates

All prompts are stored as versioned text files in `api/prompts/`:

```
api/prompts/
  vision_tag_v1.txt      -- item tagging prompt
  outfit_rank_v1.txt     -- outfit ranking prompt
  chat_stylist_v1.txt    -- V2: chat stylist system prompt
  color_analysis_v1.txt  -- V2: color analysis prompt
```

Version in filename. Never overwrite -- create v2 alongside v1. Switch via env var:
```python
VISION_PROMPT_VERSION = os.getenv("VISION_PROMPT_VERSION", "v1")
```

---

## 10. Data Moat Collection

From day 1, collect structured data that powers future features:

### outfit_feedback table
Every like, dislike, save, wear, skip is logged. This feeds:
- LLM ranker context (recent 10 actions)
- Future: fine-tuned preference model
- Future: collaborative filtering (users with similar preferences)

### rejection_pairs (derived)
Weekly batch job:
```python
async def compute_rejection_pairs(user_id: str):
    """Find item pairs that the user repeatedly rejects together."""
    disliked = await get_disliked_outfits(user_id, last_30_days=True)
    pair_counts = Counter()
    for outfit in disliked:
        for pair in combinations(outfit.item_ids, 2):
            pair_counts[frozenset(pair)] += 1
    # Store pairs with count >= 3
    for pair, count in pair_counts.items():
        if count >= 3:
            await store_rejection_pair(user_id, list(pair), count)
```

### wear_log enrichment
- Each wear increments `items.wear_count` and updates `items.last_worn_at`
- Enables: cost-per-wear, utilisation %, "you haven't worn this in 30 days" nudges

### Embedding space analysis (future)
- Cluster user wardrobe embeddings to identify style patterns
- Detect gaps: "you have many formal tops but no casual bottoms"
- Power V3 shopping advisor: recommend items that fill gaps in embedding space
