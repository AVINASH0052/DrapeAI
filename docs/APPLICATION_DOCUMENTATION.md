# DrapeAI — Application Documentation

A personal AI stylist that catalogues your wardrobe, generates outfit recommendations using rules + LLMs, lets you refine them in natural language, and analyses gaps in your wardrobe. Mobile app (Flutter) + Python FastAPI backend.

---

## 1. Product Summary

DrapeAI lives at the intersection of **wardrobe management** and **personalised styling**. The user:

1. Photographs each piece of clothing → AI auto-tags it (category, color, formality, fabric, pattern, season)
2. Builds a comprehensive style profile during onboarding (name, age, gender, style goals, body type, skin undertone, budget, climate)
3. Asks the app for outfits — by occasion, time of day, or via "shuffle"
4. Refines suggestions through chat ("make this more formal", "swap to darker colors")
5. Saves favourites to **Lookbooks** (themed collections)
6. Gets AI gap analysis: "What should I buy next?" with prioritised recommendations

The system mixes rule-based outfit composition (color harmony, formality match) with LLM ranking that incorporates the user's accumulated feedback (likes / dislikes / saves) — RLHF-lite without explicit fine-tuning.

---

## 2. Technical Stack

### Mobile app (`/app`)
- **Flutter 3.41** + **Dart 3**
- **Riverpod** (state management)
- **go_router** (declarative routing)
- **Firebase Auth** (phone OTP + Google Sign-In) with `test-token` dev bypass
- **Dio** (HTTP client)
- **image_picker** (camera + gallery)
- **Instrument Serif** + **JetBrains Mono** (Google Fonts)
- Single codebase: iOS, Android, macOS, Web

### Backend (`/api`)
- **FastAPI** (Python 3.11)
- **PostgreSQL 16** + **pgvector** (embeddings stored as `vector(1536)`)
- **Multi-provider AI abstraction** — OpenAI, Anthropic, NVIDIA NIM (Kimi K2.6 primary), Groq — with automatic failover
- **Cloudflare R2** (image storage; S3-compatible)
- **Firebase Admin SDK** (token verification)
- **OpenWeather** (weather-aware suggestions)
- **Sentry** (errors)

### Infrastructure (`/infra`)
- **Docker Compose** for dev (`docker-compose.dev.yml`) and prod (`docker-compose.prod.yml`)
- **nginx** reverse proxy in prod
- Local dev: `pgvector/pgvector:pg16` + FastAPI with hot reload

---

## 3. Database Schema

11 tables, all keyed by Firebase UID (`users.id` is `TEXT`).

| Table | Purpose | Key columns |
|---|---|---|
| `users` | Auth identity from Firebase | `id`, `phone`, `email`, `display_name`, `photo_url`, `onboarding_done`, `last_login_at`, `created_at` |
| `preferences` | Comprehensive style profile (1-to-1 with users) | `user_id`, `name`, `age`, `gender`, `style_goals` (JSON), `color_preferences` (JSON), `location_city`, `climate`, `body_type`, `skin_undertone`, `height_cm`, `budget_tier`, `lifestyle` (JSON), `occasions` (JSON), `fit_preference`, `style_profile` |
| `items` | Wardrobe items (clothing pieces) | `user_id`, `image_url`, `thumbnail_url`, `category`, `sub_category`, `primary_color`, `secondary_colors`, `pattern`, `fabric`, `style_tags`, `formality` (1-5), `season_tags`, `ethnic_flag`, `confidence`, `embedding` (vector 1536), `brand`, `purchase_price`, `purchase_date`, `wear_count`, `last_worn_at`, `is_active`, `is_demo` |
| `outfits` | AI-generated outfit recommendations | `user_id`, `item_ids` (JSON), `occasion`, `weather_temp`, `weather_cond`, `generated_by` (`ai`/`shuffle`/`manual`), `rule_score`, `llm_rank`, `llm_reason`, `is_saved`, `is_worn` |
| `outfit_feedback` | RLHF signal — likes/dislikes/saves/wears/skips | `user_id`, `outfit_id`, `action` |
| `lookbooks` | Named outfit collections | `user_id`, `name`, `sort_order` |
| `lookbook_outfits` | Join: outfits in a lookbook | `lookbook_id`, `outfit_id` |
| `outfit_cache` | 24-hour memoisation keyed by user + date + occasion | `user_id`, `occasion`, `cache_date`, `result` (JSON) |
| `weather_cache` | Hourly weather per city | `city`, `temp`, `condition`, `fetched_at` |
| `push_tokens` | FCM tokens for morning notifications | `user_id`, `token`, `platform`, `is_active` |
| `analytics_daily` | Per-metric daily aggregates (cost tracking) | `date`, `metric` (e.g. `ai_cost_openai`), `value` |

`items.embedding` indexed via **IVFFlat cosine ops** for nearest-neighbour pairing queries.

---

## 4. Mobile App Features (screen-by-screen)

### 4.1 Authentication (`features/auth/`)
- **Phone OTP** flow (Firebase)
- **Google Sign-In** (also Firebase)
- **Dev bypass**: tap a "Skip for dev" button → bearer `test-token` header is attached so the backend creates/loads a test user without Firebase

### 4.2 Onboarding (`features/onboarding/`)
**9-step wizard** with orange progress bar, all written to `preferences`:

| Step | Field | UI |
|---|---|---|
| 1 | `name` | TextField |
| 2 | `age` (13–99) | Slider with large serif readout |
| 3 | `gender` | Tile grid: Women / Men / Both |
| 4 | `style_goals` (multi) | Tile grid w/ gradient icons: Minimalist, Streetwear, Classic, Ethnic, Boho, Sporty |
| 5 | `occasions` (multi) | Circular icon tiles: Casual, Work, Party, Gym, Date, Festive, Travel |
| 6 | `color_preferences` (multi) | **12 palettes** with two-tone circles + outfit example (e.g. "Beige chinos + cream tee"): Neutrals, Earth, Pastels, Bold, Mono, Jewel, Sage & Sky, Sunset, Ocean, Spice, Forest, Blush |
| 7 | `fit_preference` | Cards with silhouette icons + outfit example: Slim, Regular, Relaxed, Oversized |
| 8 | `location_city` + auto-detected `climate` (`tropical`/`subtropical`/`temperate`/`arid`/`cold`) | Search + city list + climate pill |
| 9 (optional) | `body_type`, `skin_undertone`, `height_cm`, `budget_tier`, `lifestyle` | All skippable on one screen |

### 4.3 Wardrobe (`features/wardrobe/`)
- **wardrobe_screen** — grid of all items; filters by category; tap → detail
- **camera_screen** — camera + gallery picker; uploads → AI auto-tag pipeline
- **tag_review_screen** — shown after upload; user can override AI-detected category / color / formality / fabric / season before saving
- **item_detail_screen** — image, all tags, brand, price, wear count, **"Pairs well with…"** horizontal row (top 5 items by embedding cosine + rule compatibility + co-occurrence in saved outfits)
- **gaps_screen** — AI gap analysis: prioritised list of items to buy with rationale tied to the user's lifestyle, climate, and existing wardrobe (uses Claude Sonnet 4.6 via `Role.REASON`)

### 4.4 Outfits (`features/outfits/`)
- **today_screen** — "Today's looks" — 3 outfits for current weather + default occasion. Each card: items thumbnail row, occasion chip, weather chip, LLM reason ("Why this works"), action row: 💬 Tweak, ❤️ Save, ✓ Wore it, ✕ Skip
- **shuffle_screen** — Tinder-style swipe (Hinge UI): generates random combos; swipe right to save, left to dislike
- **outfit_chat_sheet** — bottom sheet for chat refinement. Suggestion chips ("Make it more formal", "Try darker colors"). Sends current outfit + user message → backend swaps items → returns updated outfit with reason. Item thumbnails update live.

### 4.5 Lookbooks (`features/lookbooks/`)
- **lookbooks_screen** — list of user's themed collections (e.g. "Work week", "Festive 2026")
- **lookbook_detail_screen** — outfits inside a lookbook; add/remove outfits

### 4.6 Profile (`features/profile/`)
- Profile header: avatar (initial gradient), name, "Free" badge, member-since
- **Style profile** card: chip row of all preferences + "Retake quiz" link to onboarding
- **Wardrobe stats**: Items, Saved, In rotation %
- **AI insights** card: "What should I buy next?" → gaps_screen
- **Preferences**: morning notification toggle, appearance, about
- **Help & legal**: terms, help
- Sign out / Delete account
- Build version footer

---

## 5. Backend API

All routes are JSON, all return camelCase via Pydantic. All authenticated endpoints require `Authorization: Bearer <Firebase ID token>` (or `test-token` in dev).

| Route group | Path | Methods |
|---|---|---|
| **Health** | `GET /health` | Liveness probe → `{status: "ok", service: "drapeai-api"}` |
| **Auth** | `POST /auth/verify` | Firebase ID token → user row (creates on first call) |
| **User** | `GET /me`, `PATCH /me` | Profile read/update |
| | `GET /me/preferences`, `PUT /me/preferences` | Preferences read/write (used by onboarding) |
| **Items** | `POST /items/upload` | Multipart image → R2 upload → AI tagging pipeline → row insert |
| | `GET /items` | List wardrobe (with filters: category, season, formality) |
| | `GET /items/{id}` | Single item |
| | `PATCH /items/{id}` | Override AI tags |
| | `DELETE /items/{id}` | Soft delete (sets `is_active = FALSE`) |
| | `GET /items/{id}/pairings?limit=5` | Top-N items that pair well (embedding + rules + history) |
| **Outfits** | `POST /outfits/generate` | Body: `{occasion, weather?}` → 3 ranked outfits (with cache) |
| | `POST /outfits/shuffle` | Random combo for swipe deck |
| | `POST /outfits/{id}/feedback` | `{action: like/dislike/save/wear/skip}` |
| | `GET /outfits/today` | Cached daily set |
| | `POST /outfits/{id}/refine` | Body: `{message}` → AI swaps items → returns updated outfit |
| **Lookbooks** | `POST /lookbooks`, `GET /lookbooks` | Create + list |
| | `GET/PATCH/DELETE /lookbooks/{id}` | CRUD |
| | `POST/DELETE /lookbooks/{id}/outfits/{outfit_id}` | Add/remove outfit |
| **Wardrobe** | `GET /wardrobe/gaps` | AI gap analysis (Claude Sonnet 4.6) |
| **Push** | `POST /push/register` | Register FCM token |
| **Demo** | `GET /demo/wardrobe` | Seeded sample wardrobe for empty accounts |

---

## 6. AI Architecture

### Multi-provider abstraction (`api/app/services/ai_provider.py`)

5 roles, each routed to an ordered list of providers with automatic failover:

| Role | Primary | Secondary | Tertiary |
|---|---|---|---|
| **VISION** (clothing tagging) | NVIDIA Kimi K2.6 (free) | OpenAI GPT-4o | — |
| **RANK** (outfit ranking) | NVIDIA Kimi K2.6 | Anthropic Haiku 4.5 | OpenAI GPT-4o-mini |
| **CHAT** (refinement, Q&A) | NVIDIA Kimi K2.6 | Groq Llama 3.3 70B | Anthropic Haiku 4.5 |
| **EMBED** (item similarity) | NVIDIA `nv-embedqa-e5-v5` | OpenAI `text-embedding-3-small` | — |
| **REASON** (gap analysis, profile generation) | NVIDIA Kimi K2.6 | Anthropic Sonnet 4.6 | OpenAI GPT-4o |

The fallback chain handles rate limits, network errors, and per-provider spend caps. Costs are tracked per provider in `analytics_daily` via `cost_tracker.track_provider_spend()`.

### Vision tagging pipeline (`api/app/services/upload_pipeline.py`)

1. Receive multipart upload
2. Strip background via `rembg` (`bg_remover.py`)
3. Send to vision model (Kimi K2.6) with structured prompt → JSON: `{category, primary_color, formality, fabric, pattern, style_tags, season_tags}`
4. Generate text embedding from concatenated tags (e.g. "navy cotton oxford shirt slim casual")
5. Upload original + thumbnail to R2
6. Insert into `items` with `confidence` score

### Outfit ranking (`api/app/services/llm_ranker.py`)

1. **Rule engine** (`rule_engine.py`) generates ~30 candidate combos by filtering items: formality match (±1), seasonal fit, color harmony rules, no-duplicate-category
2. Each candidate gets a `rule_score`
3. Top ~10 candidates + user's last 30 feedback events (`personalization.py`) are sent to the ranker LLM with the full profile (name, age, body type, skin undertone, lifestyle, climate)
4. LLM returns ranked top 3 with a `llm_reason` for each
5. Result cached for 24h in `outfit_cache`

### Outfit chat refinement (`api/app/services/outfit_chat.py`)

1. Load current outfit + user wardrobe (filtered by formality/season)
2. Prompt CHAT model: `"Current outfit: [items]. User says: '{message}'. Available wardrobe: [id+tags]. Return JSON: {swaps: [{old_id, new_id}], reason}"`
3. Apply swaps, return updated outfit + reason
4. Stays under 3s end-to-end (free NVIDIA tier)

### Pairing (`api/app/services/pairing.py`)

Top-N for any item is a weighted sum:
- 40% pgvector cosine similarity on `embedding`
- 40% rule compatibility (color harmony + formality match) via `rule_engine.score_combo()`
- 20% co-occurrence in user's saved outfits (boost items already worn together)

### Gap analysis (`api/app/services/wardrobe_analysis.py`)

1. Aggregate wardrobe by `category × formality × season × color_group`
2. Compute "expected" distribution from `occasions × lifestyle × climate`
3. Diff → send to REASON model (Claude Sonnet 4.6 fallback) → prioritised 5 items with `{item, reason, priority (1-3), est_price_range_inr}`
4. Cached 7 days per user

---

## 7. Authentication Model

- Firebase Auth provides phone OTP and Google Sign-In on the mobile app
- The Flutter app obtains an ID token and attaches it to every API request: `Authorization: Bearer <jwt>`
- FastAPI middleware verifies the token via Firebase Admin SDK, extracts the UID, and ensures a `users` row exists
- Dev mode: the literal string `test-token` is accepted as a special bypass — backend creates/loads a `test-user` row

There is **no email-password auth** today, and **no role/admin field** on `users`. The admin platform (below) will need to introduce one.

---

## 8. Configuration & Secrets

All secrets read from `/api/.env`:

```
DATABASE_URL=postgresql://drapeai:drapeai@db:5432/drapeai

# AI providers
OPENAI_API_KEY=
ANTHROPIC_API_KEY=
NVIDIA_API_KEY=
GROQ_API_KEY=

# Spend caps (USD/month, soft)
OPENAI_SPEND_CAP_USD=15.0
ANTHROPIC_SPEND_CAP_USD=10.0

# Per-role model overrides (defaults to Kimi K2.6 everywhere)
MODEL_VISION_PRIMARY=moonshotai/kimi-k2.6
...

# Storage
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=drapeai-images
R2_PUBLIC_URL=

# Firebase
FIREBASE_PROJECT_ID=

# Weather
OPENWEATHER_API_KEY=

# Observability
SENTRY_DSN=
```

---

## 9. Running Locally

### Backend
```bash
cd /Users/avinash/Desktop/DrapeAI/infra
docker compose -f docker-compose.dev.yml up
# → API on :8000, Postgres on :5432
```

### Mobile app
```bash
cd /Users/avinash/Desktop/DrapeAI/app
flutter run -d macos                         # fastest for UI iteration
flutter run --release -d <iphone-uuid>       # for real device testing
```

For iPhone over cellular hotspot, the API must be tunnelled (e.g. `ngrok http 8000`) and the URL pasted into `app/lib/core/constants/environment.dart`.

---

## 10. Current Limitations / Out-of-Scope

- **No admin UI** — no way to inspect users, items, outfits, or costs except via direct DB queries (this doc's main motivator for the admin platform)
- **No email auth** — Firebase phone/Google only
- **No role field** on `users` — needs to be added for admin access control
- **No content moderation** — uploaded images are not screened
- **No payment / subscription** — "Free" badge on profile is cosmetic
- **No multi-tenancy** — single workspace, no teams
- **No real weather API integration in some flows** — `weather_cache` exists; some paths still default to a stub
- **No event log / audit trail** — `analytics_daily` only stores aggregated metrics, not individual events
