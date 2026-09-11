# Sugatai — Application Documentation

A personal AI stylist that catalogues your wardrobe, generates outfit recommendations using rules + LLMs, lets you refine them in natural language, and analyses gaps in your wardrobe. Mobile app (Flutter) + Python FastAPI backend.

> Repo folder: **Sugatai**. Prefer [architecture/OVERVIEW.md](architecture/OVERVIEW.md) for the package map.

---

## 1. Product Summary

Sugatai lives at the intersection of **wardrobe management** and **personalised styling**. The user:

1. Sets up a full-body photo → private avatar base for studio renders and try-on
2. Photographs each piece of clothing → AI auto-tags it (category, color, formality, fabric, pattern, season)
3. Builds a 9-step style profile during onboarding (name, age, gender, style goals, occasions, colors, fit, city/climate; optional body/budget/lifestyle)
4. Asks the app for outfits — by occasion, weather, or via "shuffle"
5. Refines suggestions through chat ("make this more formal", "swap to darker colors")
6. Tries outfits on the avatar or a shop garment in Fitting Room
7. Saves favourites to **Lookbooks**, assigns wears on the **Calendar**, and reviews **Analytics**
8. Gets AI gap analysis: "What should I buy next?" with prioritised recommendations

The system mixes rule-based outfit composition (color harmony, formality match) with LLM ranking that incorporates the user's accumulated feedback (likes / dislikes / saves) — RLHF-lite without explicit fine-tuning.

---

## 2. Technical Stack

### Mobile app (`/app`)
- **Flutter 3.x** + **Dart 3** (package name `sugatai`, bundle `com.sugatai.sugatai`)
- **Riverpod** + **go_router** + **Dio**
- **Firebase Auth** (phone OTP + Google + Apple) with gated `test-token` dev flow
- **image_picker** (camera + gallery)
- Typography: **Syne** + **Plus Jakarta Sans** (see `design-system/sugatai/`)
- Platforms: iOS, Android (macOS target optional)

### Backend (`/api`)
- **FastAPI** (Python 3.11)
- **PostgreSQL 16** + **pgvector** (`vector(1024)`; primary embed `nvidia/nv-embedqa-e5-v5`)
- **Multi-provider AI** — Gemini / Vertex / OpenAI / Anthropic / Groq / NVIDIA / Cloudflare / RunPod
- **Cloudflare R2** (prod) or local `./uploads` (dev)
- **Firebase Admin SDK** (token verification)
- **Open-Meteo** (weather; no API key)
- **Redis + ARQ** in production
- **Sentry** (optional)

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
| `items` | Wardrobe items (clothing pieces) | `user_id`, `image_url`, `thumbnail_url`, `category`, `sub_category`, `display_name`, `notes`, `primary_color`, `secondary_colors`, `pattern`, `fabric`, `style_tags`, `formality` (1-5), `season_tags`, `ethnic_flag`, `confidence`, `processing_status`, `embedding` (vector 1024), `brand`, `purchase_price`, `purchase_date`, `wear_count`, `last_worn_at`, `is_active`, `is_demo` |
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

### 4.3 Body setup + Avatar Studio (`features/avatar/`)
- **body_setup_screen** — required after first login; full-body source photo → `avatar_status=queued` → ARQ pose/visibility check + person segment
- **avatar_studio_screen** — default home (`/studio`); dress the avatar from wardrobe slots, render via `/avatar/render`, poll until the preview lands

### 4.4 Wardrobe (`features/wardrobe/`)
- **wardrobe_screen** — grid of all items; filters by category; tap → detail
- **camera_screen** — camera + gallery picker with photo-guide overlay; uploads → AI auto-tag pipeline (tags are editable on item detail, not a separate review screen)
- **item_detail_screen** — image, all tags, brand, price, wear count, **"Pairs well with…"** horizontal row (top 5 items by embedding cosine + rule compatibility + co-occurrence in saved outfits)
- **gaps_screen** — AI gap analysis: prioritised list of items to buy with rationale tied to the user's lifestyle, climate, and existing wardrobe (`Role.REASON`)

### 4.5 Outfits (`features/outfits/`)
- **today_screen** — "Today's looks" — 3 outfits for current weather + default occasion. Each card: item thumbnails, occasion/weather chips, LLM reason, actions: Tweak, Save, Wore it, Skip
- **shuffle_screen** — swipe deck of random combos; swipe right to save, left to dislike
- **outfit_chat_sheet** — bottom sheet for chat refinement. Suggestion chips ("Make it more formal", "Try darker colors"). Sends current outfit + user message → backend swaps items → returns updated outfit with reason

### 4.6 Try-on / Fitting Room (`features/try_on/`)
- **fitting_room_screen** — try a saved outfit on the avatar or a body photo
- **try_on_home_screen** (`/fitting-room/shop`) — external / shop garment try-on
- **try_on_history_screen** — past renders

### 4.7 Lookbooks (`features/lookbooks/`)
- **lookbooks_screen** — list of user's themed collections (e.g. "Work week", "Festive 2026")
- **lookbook_detail_screen** — outfits inside a lookbook; add/remove outfits

### 4.8 Calendar, analytics, notifications
- **calendar_screen** — assign / remove an outfit per date
- **analytics_screen** — wardrobe utilisation, wear history, cost-per-wear
- **notifications_screen** — in-app notification list + FCM

### 4.9 Profile (`features/profile/`)
- Profile header: avatar (initial gradient), name, "Free" badge, member-since
- **Style profile** card: chip row of all preferences + "Retake quiz" link to onboarding
- **Wardrobe stats**: Items, Saved, In rotation %
- **AI insights** card: "What should I buy next?" → gaps_screen
- **Preferences**: morning notification toggle, appearance, about
- **Help & legal**: terms, privacy, about
- Sign out / Delete account
- Build version footer

---

## 5. Backend API

All routes are JSON, all return camelCase via Pydantic. All authenticated endpoints require `Authorization: Bearer <Firebase ID token>` (or `test-token` in dev).

| Route group | Path | Methods |
|---|---|---|
| **Health** | `GET /health` | Liveness probe → `{status, service: "drapeai-api", uptime_seconds, database}` |
| **Auth** | `POST /auth/verify` | Firebase ID token → user row (creates on first call) |
| **User** | `GET /me`, `PATCH /me` | Profile read/update |
| | `GET /me/preferences`, `PUT /me/preferences` | Preferences read/write (used by onboarding) |
| | `POST/DELETE /me/try-on-photo` | Persistent body photo for try-on |
| | `GET /me/avatar-profile` | Avatar readiness / renderability |
| **Avatar** | `POST /avatar/render`, `GET /avatar/render/{id}/status` | Studio render job |
| **Items** | `POST /items/upload` | Multipart image → store → ARQ tag + embed |
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
| **Try-on** | `POST /try-on/external`, history routes | Shop / external garment try-on |
| **Calendar** | `GET /calendar`, `POST/DELETE /calendar/{date}` | Wear calendar |
| **Analytics** | `GET /analytics/overview`, wear-history, category-breakdown | Stats |
| **Wardrobe** | `GET /wardrobe/gaps` | AI gap analysis (`Role.REASON`) |
| **Notifications** | `GET /notifications` | In-app list |
| **Push** | `POST /push/register` | Register FCM token |
| **Admin** | `/admin/*` | Ops console; requires `users.is_admin` |
| **Waitlist** | `POST /waitlist` | Marketing site sign-up (public) |

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
2. Detect garments with vision (`garment_splitter.detect_garments`) — worn outfits become multiple pieces
3. AI-extract each piece as a clean product shot via Gemini image gen (`garment_splitter.extract_garment_image`); if detection finds nothing, fall back to whole-image `rembg` (`bg_remover.py`)
4. Persist each cutout, then background-tag with vision → JSON: `{category, primary_color, formality, fabric, pattern, style_tags, season_tags}`
5. Generate text embedding from concatenated tags (e.g. "navy cotton oxford shirt slim casual")
6. Store on R2 / local uploads; `confidence` set when tagging finishes

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

- Firebase Auth provides phone OTP, Google, and Apple Sign-In on the mobile app
- The Flutter app obtains an ID token and attaches it to every API request: `Authorization: Bearer <jwt>`
- FastAPI verifies the token via Firebase Admin SDK, extracts the UID, and ensures a `users` row exists
- Dev mode: the literal string `test-token` is accepted only when `ENVIRONMENT=development` **and** Flutter is launched with `--dart-define=ENABLE_DEV_TEST_FLOW=true`

There is **no email-password auth**. `users.is_admin` gates `/admin/*`. The Vite admin console lives at `/workadmin/`.

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

# Weather — Open-Meteo, no API key
# OPENWEATHER_API_KEY is unused

# Observability
SENTRY_DSN=
```

---

## 9. Running Locally

### Backend
```bash
cd /Users/avinash/Desktop/Sugatai/infra
docker compose -f docker-compose.dev.yml up
# → API on :8000, Postgres on :5432
```

### Mobile app
```bash
cd /Users/avinash/Desktop/Sugatai/app
flutter run --dart-define=ENABLE_DEV_TEST_FLOW=true
# Wireless iPhone: also pass --dart-define=API_BASE_URL=http://<Mac-LAN-IP>:8000
# Prefer --profile on wireless iOS if debug LLDB attach dies after install
```

Do not hardcode a tunnel URL in `environment.dart`. Pass `--dart-define=DEV_TUNNEL_URL=...` or `API_BASE_URL=...` per run.

---

## 10. Current Limitations / Out-of-Scope

- **Admin UI exists** — Vite + React at `admin/` (`/workadmin/`), gated by `users.is_admin`
- **No email-password auth** — Firebase phone / Google / Apple only
- **No content moderation** — uploaded images are not screened
- **No payment / subscription** — "Free" badge on profile is cosmetic
- **No multi-tenancy** — single workspace, no teams
- **Weather** — Open-Meteo (no API key); cached per city
- **No event log / audit trail** — `analytics_daily` stores aggregated metrics, not individual events
- **IDM-VTON** — wired but non-commercial (CC BY-NC-SA 4.0); cold-start often falls back to the image-gen cascade
