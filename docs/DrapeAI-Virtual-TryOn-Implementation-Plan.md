# DrapeAI — Virtual Try-On Implementation Plan

> **Scope:** All work happens inside the DrapeAI monorepo (`api/`, `app/`, `admin/`, `infra/`). No separate PorsAI product or repo.
>
> **Goal:** User uploads a full-body photo once, then sees themselves wearing outfits — first from their **digital wardrobe**, later from **any outfit image** (screenshot, catalog, Instagram). Photorealistic output, fast enough for mobile, cost-controlled.

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Product Definition (DrapeAI-specific)](#2-product-definition-drapeai-specific)
3. [Current State (What Already Exists)](#3-current-state-what-already-exists)
4. [Target Architecture](#4-target-architecture)
5. [Key Design Decisions](#5-key-design-decisions)
6. [Phased Roadmap](#6-phased-roadmap)
7. [Phase 1 — Production-Quality Wardrobe Try-On (MVP)](#7-phase-1--production-quality-wardrobe-try-on-mvp)
8. [Phase 2 — External Outfit Try-On](#8-phase-2--external-outfit-try-on)
9. [Phase 3 — Quality, Speed & Monetization](#9-phase-3--quality-speed--monetization)
10. [Phase 4 — Dedicated VTON Model (Optional)](#10-phase-4--dedicated-vton-model-optional)
11. [API Specification](#11-api-specification)
12. [Database Changes](#12-database-changes)
13. [Flutter UX Plan](#13-flutter-ux-plan)
14. [Backend File Checklist](#14-backend-file-checklist)
15. [Infrastructure & Cloudflare Setup](#15-infrastructure--cloudflare-setup)
16. [Cost Model & Credits](#16-cost-model--credits)
17. [Testing Strategy](#17-testing-strategy)
18. [Risks & Mitigations](#18-risks--mitigations)
19. [Success Metrics](#19-success-metrics)
20. [Open Questions](#20-open-questions)

---

## 1. Executive Summary

DrapeAI already has **60% of virtual try-on plumbing**:

| Layer | Status |
|-------|--------|
| User full-body photo upload | ✅ `POST /me/try-on-photo` |
| Outfit visualize endpoint | ✅ `POST /outfits/{id}/visualize` |
| Multi-provider image gen | ✅ NVIDIA / OpenAI / Gemini + PIL fallback |
| R2 storage + preview cache | ✅ `outfits.preview_image_key` |
| Flutter visualize sheet | ✅ `OutfitVisualizeSheet` on outfit cards |

**What's missing for a shippable try-on product:**

1. **Primary inference provider** — add **Cloudflare Workers AI (FLUX.2 Klein 9B)** as the default fast/cheap path
2. **Better prompts & image prep** — person + garment refs tuned for wardrobe (not generic image edit)
3. **Async job flow** — generation takes 5–30s; need queue + polling, not blocking HTTP
4. **Credits / rate limits** — image gen is expensive; cap per user per day
5. **UX polish** — onboarding nudge, loading states, regenerate, history gallery
6. **(Phase 2)** External outfit image flow — person + Zara/Amazon screenshot

**Recommended approach:** Keep the **FastAPI monolith** and **Flutter app**. Add Cloudflare as a **new try-on provider** inside `image_gen_provider.py`, not a full rewrite to Cloudflare-only Workers. R2 stays as-is (already Cloudflare).

---

## 2. Product Definition (DrapeAI-specific)

### Core flows (in priority order)

#### Flow A — Wardrobe outfit try-on (Phase 1, primary)

```
User has try-on photo in profile
  → Opens Today's outfit / Shuffle / Lookbook outfit
  → Taps "See me in this"
  → Backend: person photo + wardrobe item images (from R2)
  → FLUX Klein (or fallback) generates photorealistic preview
  → Cached on outfit row; shown in full-screen sheet
```

**Differentiator vs generic try-on apps:** Outfit is composed from the user's **own tagged wardrobe**, with metadata (color, fabric, ethnic) injected into the prompt. Stylist + try-on in one app.

#### Flow B — External outfit try-on (Phase 2)

```
User uploads: person photo (or uses saved) + outfit reference image
  → Any source: Amazon, Zara, Instagram screenshot, Pinterest
  → Same inference pipeline, different prompt template
  → Result saved to try_on_history table (not tied to wardrobe outfit)
```

**Use case:** "Should I buy this?" before adding to wardrobe. Bridges shopping → wardrobe.

#### Flow C — Stylist loop (existing, enhanced)

```
Generate outfits (rule engine + LLM ranker)
  → User likes outfit
  → One-tap visualize
  → Feedback (save / wear) improves future rankings
```

Try-on becomes the **visual payoff** of the stylist, not a standalone feature.

### Non-goals (for now)

- Real-time video try-on
- AR mirror mode
- Multi-person photos
- Perfect logo/seam preservation (Phase 4 if needed)

---

## 3. Current State (What Already Exists)

### Backend

| File | Role |
|------|------|
| `api/app/routes/user.py` | `POST/DELETE /me/try-on-photo` |
| `api/app/routes/outfits.py` | `POST /outfits/{id}/visualize` with cache via `preview_image_key` |
| `api/app/services/image_gen_provider.py` | Provider failover: NVIDIA → OpenAI → Gemini |
| `api/app/services/outfit_visualizer.py` | Orchestrates AI gen + PIL composite fallback |
| `api/app/services/storage.py` | R2/local: `users/{id}/try_on/photo.*`, outfit previews |
| `api/app/config.py` | `TRYON_PROVIDER_*`, `TRYON_FALLBACK_COMPOSITE` |

**Default provider chain today:**

```
nvidia/qwen-image-edit → openai/gpt-image-1 → gemini-2.5-flash-image → PIL composite
```

### Database

```sql
users.try_on_photo_key          -- full-body reference
outfits.preview_image_key       -- generated preview per outfit
```

### Flutter

| File | Role |
|------|------|
| `profile_screen.dart` | Upload/update/delete try-on photo |
| `outfit_visualize_sheet.dart` | Full-screen preview generation |
| `outfit_card.dart` / `shuffle_screen.dart` | Entry points to visualize |
| `api_client.dart` | `uploadTryOnPhoto`, `visualizeOutfit` |

### Gaps

- No **Cloudflare / FLUX** provider
- No **async job queue** for long-running image gen (blocks request ~30–180s)
- No **credits** or per-user daily caps on visualize
- No **history** table for external try-ons
- No **image validation** on try-on photo (pose, full-body check)
- Profile copy still says "composite" — undersells AI capability
- Admin has no try-on cost dashboard beyond generic `ai-usage`

---

## 4. Target Architecture

### High-level (DrapeAI hybrid — recommended)

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter App (DrapeAI)                        │
│  Profile try-on photo │ Outfit cards │ (Phase 2) Shop try-on     │
└───────────────────────────────┬─────────────────────────────────┘
                                │ HTTPS + Firebase JWT
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     FastAPI (existing monolith)                  │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ Auth/User   │  │ Outfits      │  │ Try-on service          │ │
│  │ routes      │  │ visualize    │  │ (new: job queue)        │ │
│  └─────────────┘  └──────────────┘  └───────────┬─────────────┘ │
│                                                  │               │
│  ┌──────────────────────────────────────────────▼─────────────┐ │
│  │ image_gen_provider.py (extended)                            │ │
│  │  1. cloudflare/flux-2-klein-9b  ← NEW PRIMARY              │ │
│  │  2. nvidia/qwen-image-edit                                   │ │
│  │  3. openai/gpt-image-1                                       │ │
│  │  4. gemini-2.5-flash-image                                   │ │
│  │  5. PIL composite fallback                                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
└───────────┬─────────────────────┬───────────────────────────────┘
            │                     │
            ▼                     ▼
   ┌────────────────┐    ┌──────────────────────┐
   │ PostgreSQL     │    │ Cloudflare R2        │
   │ users, outfits │    │ person + items +     │
   │ try_on_jobs    │    │ generated previews   │
   │ try_on_history │    └──────────────────────┘
   └────────────────┘
            │
            ▼
   ┌────────────────┐    ┌──────────────────────┐
   │ Redis + ARQ    │    │ Cloudflare Workers AI │
   │ async try-on   │───▶│ FLUX.2 Klein 9B       │
   │ jobs           │    │ (REST or Worker proxy)│
   └────────────────┘    └──────────────────────┘
```

### Why not replace FastAPI with Cloudflare Worker?

| Keep FastAPI | Reason |
|--------------|--------|
| Wardrobe pipeline | Vision tagging, embeddings, rule engine, LLM ranker already here |
| Single auth model | Firebase JWT verification is centralized |
| One DB connection | Postgres + pgvector for everything |
| Admin dashboard | Already hits FastAPI `/admin/*` |
| Evolution path | Swap only inference provider later (FASHN VTON) |

**Cloudflare's role:** Inference + storage (R2), not replacement of the whole backend.

### Optional: thin Cloudflare Worker (Phase 1b)

If you want API keys fully off FastAPI and edge rate limiting:

```
FastAPI → internal HTTPS → Cloudflare Worker → Workers AI → returns PNG bytes
```

Worker handles: account ID routing, CF API token, request size limits. FastAPI still owns auth, credits, DB, R2 upload.

**Start without Worker** — call Workers AI REST API from FastAPI. Add Worker only if you need edge isolation.

---

## 5. Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Primary model | **FLUX.2 Klein 9B** (`@cf/black-forest-labs/flux-2-klein-9b`) | Fast 4-step pipeline, multi-image input, lower cost than Dev |
| Fallback model | Keep NVIDIA → OpenAI → Gemini chain | Resilience when CF quota/rate limits hit |
| Ultimate quality | **FLUX.2 Dev** or **FASHN VTON** (Phase 4) | Only if users reject Klein fidelity |
| Job model | **Async ARQ worker** | Image gen 5–30s; don't block mobile HTTP |
| Caching | Keep `outfits.preview_image_key` | Avoid re-billing; `force=true` to regenerate |
| External outfits | New `try_on_sessions` table (Phase 2) | Don't overload `outfits` table |
| Credits | Free tier: 3/day; premium: unlimited (Phase 3) | Control burn rate at launch |
| Person photo | One per user in `users.try_on_photo_key` | Simple; multi-pose later |
| Max garment refs | 4 images (FLUX Klein limit) | Full outfit: top + bottom + shoes + outerwear |

---

## 6. Phased Roadmap

```
Phase 0  Foundation audit & config          (3–5 days)
Phase 1  Wardrobe try-on MVP + FLUX Klein   (2–3 weeks)
Phase 2  External outfit try-on             (1–2 weeks)
Phase 3  Credits, polish, admin metrics     (1–2 weeks)
Phase 4  Dedicated VTON (FASHN) if needed   (2–3 weeks, conditional)
```

Dependencies:

```
Phase 0 ──▶ Phase 1 ──▶ Phase 2
                │
                └──▶ Phase 3 (can overlap with Phase 2)
                              │
                              └──▶ Phase 4 (only if quality KPI fails)
```

---

## 7. Phase 1 — Production-Quality Wardrobe Try-On (MVP)

### 7.1 Objectives

- FLUX Klein is **primary** try-on provider
- Visualize is **async** (job + poll)
- Reliable UX on Today / Shuffle / Lookbooks
- Composite fallback only when all AI providers fail
- Basic per-user rate limit (no credits UI yet)

### 7.2 Backend tasks

#### A. Add Cloudflare provider (`image_gen_provider.py`)

**New function:** `_cloudflare_tryon(person_bytes, item_bytes, prompt, model)`

```python
# Pseudocode — Workers AI image edit with multi-reference
POST https://api.cloudflare.com/client/v4/accounts/{account_id}/ai/run/{model}
Headers: Authorization: Bearer {CLOUDFLARE_API_TOKEN}
Body: multipart or JSON per CF docs for flux-2-klein-9b

Inputs:
  - image 1: person (full-body)
  - image 2–4: wardrobe item PNGs (bg-removed from upload pipeline)
Prompt: WARDROBE_TRYON_PROMPT_V1 (see below)
```

**Config additions (`config.py` + `.env.example`):**

```bash
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_API_TOKEN=          # Workers AI permission
TRYON_PROVIDER_PRIMARY=cloudflare
TRYON_MODEL_PRIMARY=@cf/black-forest-labs/flux-2-klein-9b
TRYON_PROVIDER_SECONDARY=nvidia
TRYON_MODEL_SECONDARY=qwen/qwen-image-edit
# ... rest unchanged
TRYON_DAILY_LIMIT_FREE=5
TRYON_JOB_TIMEOUT_SEC=120
```

**Update `_provider_configured()` and `_route_tryon()`** to include `cloudflare`.

#### B. Prompt templates (`api/prompts/`)

Create versioned prompts:

**`wardrobe_tryon_v1.txt`**

```
Dress the person in image 1 using the clothing garments shown in the reference images.

Wardrobe details (from user's closet):
{outfit_metadata_lines}

Requirements:
- Preserve face, hairstyle, skin tone, body shape, and pose exactly
- Replace only the clothing
- Match garment colors, patterns, and silhouette from reference images
- Photorealistic full-body fashion photo, natural lighting, neutral background
- Indian ethnic wear: respect drape and garment structure (saree, kurta, lehenga)
Do not change identity. Do not add text or watermarks.
```

**`external_tryon_v1.txt`** (stub for Phase 2)

```
Dress the person in image 1 using the outfit shown in image 2.
Preserve face, hairstyle, body shape, pose.
Keep the clothing design from image 2 as closely as possible.
Photorealistic. Do not change identity.
```

Wire via `TRYON_PROMPT_VERSION=wardrobe_v1` env var.

#### C. Async job queue (ARQ worker)

**New table:** `try_on_jobs` (see [Database Changes](#12-database-changes))

**New files:**

```
api/app/services/try_on_job.py       # enqueue, status, result
api/app/workers/try_on_worker.py     # ARQ task: run visualize_outfit
api/app/routes/try_on.py             # GET /try-on/jobs/{id} (optional unified poll)
```

**Flow change:**

```
POST /outfits/{id}/visualize
  → if cached preview && !force: return immediately
  → if job in progress: return { job_id, status: "processing" }
  → else: enqueue ARQ job, return { job_id, status: "queued" }

GET /outfits/{id}/visualize/status   OR   GET /try-on/jobs/{job_id}
  → { status, preview_url?, method?, model?, error? }
```

**Modify `outfits.py`:** HTTP handler returns in <500ms; worker calls existing `visualize_outfit()`.

#### D. Rate limiting

```python
# Redis key: tryon:daily:{user_id}:{YYYY-MM-DD}
# INCR on job enqueue; reject if > TRYON_DAILY_LIMIT_FREE
```

Return `429` with `{ "detail": "Daily try-on limit reached", "resets_at": "..." }`.

#### E. Image prep improvements

Before sending to FLUX:

1. **Person photo:** resize max 1536px long edge, JPEG 90% or PNG
2. **Garment images:** prefer bg-removed PNGs from wardrobe upload pipeline
3. **Order:** person first, then top → bottom → footwear → outerwear (by category)
4. **Skip** items without `image_url` storage key

**New helper:** `api/app/services/try_on_prep.py`

#### F. Cost tracking

Extend `cost_tracker.py`:

```python
track_provider_spend("cloudflare", "flux-2-klein-9b", estimated_usd=0.00x)
```

Log to `analytics_daily` metric `ai_cost_cloudflare_tryon`.

### 7.3 Flutter tasks (Phase 1)

| Task | File | Detail |
|------|------|--------|
| Async poll UI | `outfit_visualize_sheet.dart` | After POST, poll status every 2s; show progress ring + "Generating… ~15s" |
| Better errors | same | Handle 429 (limit), 400 (no photo), job failed |
| Onboarding nudge | `onboarding` or `today_screen` | After quiz: "Add a photo to see outfits on you" |
| Entry point clarity | `outfit_card.dart` | Button: "See me in this" with camera icon |
| Provider label | `outfit_visualize_sheet.dart` | Show "AI preview" not "Pillow composite" when method is ai:cloudflare |
| Regenerate | already has `force: true` | Expose "Regenerate" chip in sheet |

**`api_client.dart` additions:**

```dart
Future<Map<String, dynamic>> visualizeOutfitStatus(String outfitId);
// or poll job_id from visualize response
```

### 7.4 Phase 1 acceptance criteria

- [ ] User with try-on photo can visualize any outfit with ≥3 items
- [ ] FLUX Klein succeeds on ≥80% of test cases (10 diverse outfits)
- [ ] P95 time-to-preview < 25s (async, from tap to image shown)
- [ ] Cached preview loads in <1s on second open
- [ ] Fallback chain works when CF token invalid (NVIDIA/OpenAI takes over)
- [ ] Daily limit enforced; clear error in app
- [ ] Preview stored in R2 at `users/{id}/outfits/{outfit_id}/preview.png`

### 7.5 Phase 1 testing matrix

| Case | Person | Outfit | Expected |
|------|--------|--------|----------|
| Western casual | Full-body | Tee + jeans + sneakers | Correct layering |
| Ethnic | Full-body | Kurta + chinos + kolhapuri | Fusion handled |
| Saree | Full-body | Saree + blouse refs | Drape reasonable |
| No try-on photo | — | Any | 400 + app routes to profile |
| 6-item outfit | Full-body | 6 items | Top 4 by category priority sent |
| All providers down | Full-body | Any | Composite fallback OR clear error |

---

## 8. Phase 2 — External Outfit Try-On

### 8.1 Objectives

User tries on **any outfit image** without adding to wardrobe first.

### 8.2 New API

```
POST /try-on/external
  multipart: reference_image (outfit photo)
  optional: use_saved_person=true (default)
  → job_id

GET /try-on/external/{session_id}
  → { status, result_url, created_at }

GET /try-on/history?limit=20
  → list of past external try-ons
```

### 8.3 Backend

**New table:** `try_on_sessions` (see DB section)

**New route file:** `api/app/routes/try_on.py`

**Pipeline:**

```
person_bytes ← users.try_on_photo_key OR upload in same request
garment_bytes ← reference_image (single image)
prompt ← external_tryon_v1.txt
→ same image_gen_provider.generate_tryon_image() but with single ref image mode
→ upload to R2: users/{id}/try_on/sessions/{session_id}.png
```

**Rate limit:** stricter than wardrobe visualize (e.g. 2/day free) — external is higher abuse risk.

### 8.4 Flutter

**New feature folder:** `app/lib/features/try_on/`

| Screen | Purpose |
|--------|---------|
| `try_on_home_screen.dart` | "Try any outfit" — pick person (saved) + outfit image |
| `try_on_result_screen.dart` | Result + save to wardrobe? + share |
| `try_on_history_screen.dart` | Gallery of past sessions |

**Entry points:**

- Profile → "Try an outfit from a photo"
- Optional: share extension (iOS/Android) — later

### 8.5 Phase 2 acceptance criteria

- [ ] User can upload Zara/Amazon screenshot and see themselves in outfit
- [ ] Session history persists 30 days
- [ ] Option: "Add these items to wardrobe" (manual follow-up, not auto-tag)

---

## 9. Phase 3 — Quality, Speed & Monetization

### 9.1 Credits & subscription hooks

**DB:**

```sql
users.try_on_credits_remaining INT DEFAULT 0
users.try_on_credits_reset_at TIMESTAMPTZ
-- or separate subscriptions table later
```

**Logic:**

| Tier | Wardrobe visualize/day | External/day |
|------|------------------------|--------------|
| Free | 3 | 1 |
| Premium (future) | Unlimited | 10 |

**Flutter:** Paywall sheet when 429 received.

### 9.2 Quality tier (user-selectable)

```
Settings → Try-on quality: Fast (Klein) | Best (FLUX Dev or gpt-image-1 high)
```

Maps to different provider/model in job payload.

### 9.3 UX polish

- Blurhash / skeleton while loading
- Side-by-side: wardrobe items strip + generated preview
- Share image to Instagram/WhatsApp
- Push notification when job completes (if user left screen)

### 9.4 Admin dashboard

**New admin page:** `admin/src/pages/TryOnMetrics.tsx`

- Generations per day
- Success rate by provider
- Avg latency
- Cost by provider (CF vs OpenAI vs NVIDIA)
- Top failure reasons

**API:** extend `GET /admin/ai-usage` with `metric=try_on`.

### 9.5 Background replacement & upscaling (stretch)

Optional post-process pipeline:

```
FLUX output → background unify (white/studio) → optional upscale (CF or Real-ESRGAN on worker)
```

Lower priority than core try-on reliability.

---

## 10. Phase 4 — Dedicated VTON Model (Optional)

**Trigger:** <70% user satisfaction on garment fidelity in in-app survey OR support tickets about "wrong print/color".

### Architecture (unchanged frontend/API)

```
image_gen_provider.py
  1. fashn_vton (RunPod GPU)     ← NEW primary for quality tier
  2. cloudflare/flux-2-klein-9b  ← fast tier
  3. ... existing fallbacks
```

**RunPod pod:**

- Model: FASHN VTON or IDM-VTON
- Input: person image + flat garment image (may need garment extraction pre-step)
- FastAPI calls RunPod serverless endpoint; same job queue

**No Flutter changes** — only `method` and `model` in API response change.

---

## 11. API Specification

### Existing (modify)

#### `POST /outfits/{outfit_id}/visualize?force=false`

**New response (async):**

```json
{
  "job_id": "uuid",
  "status": "queued",
  "cached": false
}
```

**Cached hit (unchanged):**

```json
{
  "preview_url": "https://...",
  "cached": true,
  "method": "cached"
}
```

#### `GET /outfits/{outfit_id}/visualize/status`

```json
{
  "job_id": "uuid",
  "status": "queued | processing | completed | failed",
  "preview_url": "https://...",
  "method": "ai:cloudflare",
  "model": "@cf/black-forest-labs/flux-2-klein-9b",
  "error": null,
  "progress_pct": 60
}
```

### New (Phase 2)

#### `POST /try-on/external`

```
multipart/form-data:
  reference_image: file (required)
  person_image: file (optional if try_on_photo_key set)
```

Response: `{ "session_id": "uuid", "job_id": "uuid", "status": "queued" }`

#### `GET /try-on/history`

```json
{
  "sessions": [
    {
      "id": "uuid",
      "result_url": "https://...",
      "reference_url": "https://...",
      "method": "ai:cloudflare",
      "created_at": "2026-07-10T12:00:00Z"
    }
  ]
}
```

### Existing (unchanged)

- `POST /me/try-on-photo`
- `DELETE /me/try-on-photo`
- `GET /me` (includes `try_on_photo_url`)

---

## 12. Database Changes

### Migration `0009_try_on_jobs.sql`

```sql
-- Async job tracking for outfit visualization
CREATE TABLE IF NOT EXISTS try_on_jobs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    outfit_id       UUID REFERENCES outfits(id) ON DELETE CASCADE,
    session_id      UUID,                    -- Phase 2 external sessions
    status          TEXT NOT NULL DEFAULT 'queued',  -- queued|processing|completed|failed
    provider        TEXT,
    model           TEXT,
    method          TEXT,                    -- ai:cloudflare | composite | etc.
    result_key      TEXT,                    -- R2 key
    error_message   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at      TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ
);

CREATE INDEX idx_try_on_jobs_user_created ON try_on_jobs(user_id, created_at DESC);
CREATE INDEX idx_try_on_jobs_outfit ON try_on_jobs(outfit_id) WHERE outfit_id IS NOT NULL;
```

### Migration `0010_try_on_sessions.sql` (Phase 2)

```sql
CREATE TABLE IF NOT EXISTS try_on_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reference_image_key TEXT NOT NULL,
    result_image_key    TEXT,
    prompt_version      TEXT NOT NULL DEFAULT 'external_v1',
    provider            TEXT,
    model               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_try_on_sessions_user ON try_on_sessions(user_id, created_at DESC);
```

### Migration `0011_try_on_credits.sql` (Phase 3)

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS try_on_daily_count INT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS try_on_daily_reset_date DATE;
```

(Redis is preferred for daily counters; DB columns are backup/audit.)

---

## 13. Flutter UX Plan

### User journey map

```
┌─────────────────────────────────────────────────────────────┐
│ ONBOARDING (step 10 — new optional step)                     │
│ "Add a full-body photo" [Skip] [Add photo]                   │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ TODAY'S OUTFITS                                              │
│  Outfit card → [See me in this]                              │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ VISUALIZE SHEET                                              │
│  Loading: animated silhouette + "Styling you…"               │
│  Success: full-screen preview + item strip + [Regenerate]    │
│  Error: no photo → CTA to Profile                            │
│         limit → "Come back tomorrow" / upgrade CTA           │
└─────────────────────────────────────────────────────────────┘
```

### Profile section copy (update)

**Before:** "We'll composite outfits from clothes you already own."

**After:** "See AI-generated photos of you wearing outfits from your wardrobe. Add one full-body photo — plain background, head to toe."

### New widgets

| Widget | Purpose |
|--------|---------|
| `TryOnProgressIndicator` | Reusable polling + progress |
| `TryOnPhotoGuide` | Overlay: full-body, good lighting, arms visible |
| `TryOnLimitBanner` | "2 of 3 try-ons left today" |

### Navigation (Phase 2)

Add to `go_router`:

```
/try-on              → TryOnHomeScreen
/try-on/history      → TryOnHistoryScreen
/try-on/:sessionId   → TryOnResultScreen
```

---

## 14. Backend File Checklist

### Phase 1 — create/modify

| Action | File |
|--------|------|
| **Modify** | `api/app/services/image_gen_provider.py` — add `_cloudflare_tryon` |
| **Modify** | `api/app/config.py` — Cloudflare settings |
| **Modify** | `api/.env.example` |
| **Create** | `api/prompts/wardrobe_tryon_v1.txt` |
| **Create** | `api/app/services/try_on_prep.py` |
| **Create** | `api/app/services/try_on_job.py` |
| **Create** | `api/app/workers/try_on_worker.py` |
| **Modify** | `api/app/routes/outfits.py` — async visualize |
| **Modify** | `api/app/workers/settings.py` — register ARQ task |
| **Modify** | `api/app/services/cost_tracker.py` — cloudflare metric |
| **Create** | `api/db/migrations/0009_try_on_jobs.sql` |
| **Create** | `api/tests/test_cloudflare_tryon.py` |
| **Modify** | `api/tests/test_image_gen_provider.py` |

### Phase 2 — create

| Action | File |
|--------|------|
| **Create** | `api/app/routes/try_on.py` |
| **Create** | `api/prompts/external_tryon_v1.txt` |
| **Create** | `api/db/migrations/0010_try_on_sessions.sql` |

### Phase 3 — create

| Action | File |
|--------|------|
| **Create** | `admin/src/pages/TryOnMetrics.tsx` |
| **Modify** | `api/app/routes/admin.py` |

---

## 15. Infrastructure & Cloudflare Setup

### Prerequisites

1. Cloudflare account with **Workers AI** enabled
2. R2 bucket already configured (`drapeai-images`)
3. API token with permissions: `Workers AI:Read`, `Account:Read`

### Environment variables (production)

```bash
# Existing R2 (unchanged)
R2_ACCOUNT_ID=...
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_BUCKET_NAME=drapeai-images
R2_PUBLIC_URL=https://images.drapeai.com

# New — Workers AI
CLOUDFLARE_ACCOUNT_ID=...        # same as R2 account ID typically
CLOUDFLARE_API_TOKEN=...         # scoped token, not Global API Key

# Try-on routing
TRYON_PROVIDER_PRIMARY=cloudflare
TRYON_MODEL_PRIMARY=@cf/black-forest-labs/flux-2-klein-9b
TRYON_DAILY_LIMIT_FREE=5
```

### Workers AI call pattern (from FastAPI)

```python
url = (
    f"https://api.cloudflare.com/client/v4/accounts/"
    f"{settings.cloudflare_account_id}/ai/run/{model_id}"
)
# Multipart: prompt + input images per CF FLUX Klein docs
# Parse response bytes or base64 → PNG
```

**Note:** Verify exact request format against current [Cloudflare Workers AI FLUX Klein docs](https://developers.cloudflare.com/workers-ai/models/) at implementation time — multipart field names change between models.

### Docker / deploy

No new containers for Phase 1. ARQ worker process already in `docker-compose.prod.yml` — add `try_on_worker` task to existing worker container.

### Optional Worker (`infra/cloudflare/try-on-worker/`)

```
infra/cloudflare/
  try-on-worker/
    wrangler.toml
    src/index.ts        # validates internal secret, calls AI, returns image
```

Deploy separately via `wrangler deploy`. FastAPI sends `X-Internal-Secret` header.

---

## 16. Cost Model & Credits

### Estimated cost per generation

| Provider | Model | Est. cost | Latency |
|----------|-------|-----------|---------|
| Cloudflare | FLUX.2 Klein 9B | ~$0.01–0.03 | 5–15s |
| Cloudflare | FLUX.2 Dev | ~$0.05–0.10 | 15–30s |
| OpenAI | gpt-image-1 medium | ~$0.04–0.08 | 10–20s |
| NVIDIA | qwen-image-edit | free tier / variable | 10–30s |
| PIL composite | — | $0 | <1s |

### Monthly burn (illustrative)

| MAU | Visualizes/user/month | Klein cost | Total |
|-----|----------------------|------------|-------|
| 100 | 10 | $0.02 | ~$20 |
| 1,000 | 10 | $0.02 | ~$200 |
| 10,000 | 10 | $0.02 | ~$2,000 |

**Caching** (`preview_image_key`) cuts repeat cost to zero for same outfit.

### Launch controls

1. `TRYON_DAILY_LIMIT_FREE=3`
2. Cache aggressively
3. Klein primary, Dev only on explicit "Best quality"
4. Admin alert when daily CF spend > threshold

---

## 17. Testing Strategy

### Unit tests

- `build_tryon_prompt()` includes ethnic metadata
- `_cloudflare_tryon` mocked HTTP returns PNG
- Provider failover: CF fails → NVIDIA succeeds
- Rate limit: 6th request returns 429

### Integration tests

- Full job: enqueue → worker → `preview_image_key` set on outfit
- Cached path: second visualize returns without job

### Manual QA (device)

- iOS + Android: large images, slow network, background app during poll
- Dark skin tone + ethnic wear (bias check)
- Regenerate doesn't leak previous image flash

### Load test

- 10 concurrent visualize jobs — ARQ worker pool size 3–5
- Redis queue depth monitoring

---

## 18. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| FLUX doesn't preserve garment details | High | Phase 4 FASHN; prompt tuning; use bg-removed item PNGs |
| CF Workers AI rate limits | Medium | Multi-provider failover; queue backoff |
| Long generation times | Medium | Async jobs + push notification; set expectations in UI |
| Abuse (external try-on) | Medium | Stricter limits; image moderation (Phase 3) |
| Try-on photo privacy concerns | High | Clear privacy copy; delete photo API; no training on user images |
| Cost overrun at viral growth | High | Daily caps; admin kill switch `TRYON_ENABLED=false` |
| Identity drift (face changes) | High | Strong prompt; user report + regenerate; consider face-lock post-process later |

---

## 19. Success Metrics

### Phase 1 launch KPIs (30 days)

| Metric | Target |
|--------|--------|
| Try-on photo upload rate | ≥40% of active users |
| Visualize tap-through (outfit card → sheet) | ≥25% |
| Job success rate (AI, not composite) | ≥85% |
| P95 time queued → completed | <30s |
| User-reported satisfaction (in-app thumbs) | ≥70% positive |
| Cost per MAU | <₹50/month |

### Phase 2 KPIs

| Metric | Target |
|--------|--------|
| External try-on sessions / week | ≥20% of visualize volume |
| Conversion: external → wardrobe upload | ≥10% |

---

## 20. Open Questions — RESOLVED (July 2026 implementation)

1. **Async vs sync for MVP?** — ✅ Async via ARQ, with automatic sync fallback when Redis/worker is unavailable (`TRYON_ASYNC` toggles). Verified end-to-end.
2. **Cloudflare call path** — ✅ Direct from FastAPI (no thin Worker). Multipart format verified against CF docs: `input_image_0…3`, max 4 images, **all inputs must be < 512×512** (confirmed platform constraint — bounds Klein input fidelity; strengthens the Phase 4 case if quality KPIs miss).
3. **Free tier limits** — ✅ Default 5/day in code, 3/day in prod `.env` (`TRYON_DAILY_LIMIT_FREE`). Failed jobs refund quota; resets at UTC midnight.
4. **Composite fallback** — ✅ Kept enabled (`TRYON_FALLBACK_COMPOSITE=true`) as last resort after all AI providers.
5. **Onboarding step** — ✅ Optional: dismissible "See outfits on you" nudge on Today screen (hidden once photo exists or dismissed; persisted).
6. **Subscription** — ✅ Deferred to Phase 3. API already returns `limit`/`remaining` on visualize + status + 429 for the paywall UI later.

### Implementation deltas vs original plan

- Worker task registered in existing `app/workers/tasks.py` (no separate `try_on_worker.py`); ARQ job name must be the **full dotted path** `app.workers.tasks.process_try_on`.
- Jobs stuck in `queued`/`processing` beyond 2× `TRYON_JOB_TIMEOUT_SEC` are auto-failed on status poll and refunded.
- **Phase 4 arrived early:** RunPod Serverless IDM-VTON worker (`infra/runpod/idm-vton-worker/`, endpoint `drapeai-idm-vton`) is wired as `TRYON_PROVIDER_PRIMARY=runpod` in dev `.env`, with Gemini secondary and composite fallback.

---

## Appendix A — Provider priority (recommended final state)

```
Primary:   cloudflare / @cf/black-forest-labs/flux-2-klein-9b
Secondary: nvidia     / qwen/qwen-image-edit
Tertiary:  openai     / gpt-image-1
Quaternary: gemini   / gemini-2.5-flash-image
Fallback:  PIL composite (dev only or TRYON_FALLBACK_COMPOSITE=true)
```

## Appendix B — R2 key layout

```
users/{user_id}/try_on/photo.jpg              # person reference
users/{user_id}/items/{item_id}.png           # wardrobe (bg-removed)
users/{user_id}/outfits/{outfit_id}/preview.png
users/{user_id}/try_on/sessions/{session_id}.png
users/{user_id}/try_on/sessions/{session_id}_ref.jpg
```

## Appendix C — Relationship to existing DrapeAI AI stack

Virtual try-on is **one consumer** of image generation. It does **not** replace:

- Vision LLM tagging on upload
- Embedding generation (pgvector)
- Rule engine + LLM ranker for outfit suggestions
- Outfit chat refinement (text LLM)
- Wardrobe gap analysis (reason LLM)

Try-on is the **visual layer** on top of the stylist core.

---

*Document version: 1.0 — DrapeAI repo only. Last updated: July 2026.*
