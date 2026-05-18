# DrapeAI -- System Architecture

> Last updated: April 2026

---

## Table of Contents

- [High-Level Architecture](#high-level-architecture)
- [Service Boundaries](#service-boundaries)
- [Data Flow](#data-flow)
- [Infrastructure Topology](#infrastructure-topology)
- [Request Flow](#request-flow)
- [Auth Architecture](#auth-architecture)
- [AI Layer Architecture](#ai-layer-architecture)
- [Storage Architecture](#storage-architecture)
- [Caching Strategy](#caching-strategy)
- [Push Notification Flow](#push-notification-flow)

---

## High-Level Architecture

```
+-------------------+       HTTPS        +-------------------+
|                   | -----------------> |                   |
|   Flutter App     |                    |   Nginx (TLS)     |
|   (Android/iOS)   | <---------------- |   reverse proxy    |
|                   |       JSON/SSE     |                   |
+-------------------+                    +--------+----------+
                                                  |
                                                  | :8000
                                                  v
                                         +--------+----------+
                                         |                   |
                                         |   FastAPI         |
                                         |   (uvicorn)       |
                                         |                   |
                                         +--+-----+-----+---+
                                            |     |     |
                              +-------------+     |     +-------------+
                              |                   |                   |
                              v                   v                   v
                     +--------+---+      +--------+---+      +--------+---+
                     | PostgreSQL |      | Cloudflare |      | OpenAI     |
                     | + pgvector |      | R2 Storage |      | GPT-4o     |
                     +------------+      +------------+      +------------+
                                                                    |
                                                         +----------+----------+
                                                         |                     |
                                                    Vision API          Chat Completions
                                                    (tagging)           (outfit ranking)

External APIs:
  +------------------+    +------------------+    +------------------+
  | OpenWeatherMap   |    | Firebase Auth    |    | Firebase Cloud   |
  | (weather data)   |    | (OTP + Google)   |    | Messaging (push) |
  +------------------+    +------------------+    +------------------+
```

---

## Service Boundaries

The backend is a **monolith** (single FastAPI process). No microservices. At the current scale (0 to 10,000 users), a monolith is correct. Split only when a specific service becomes a bottleneck.

### Internal modules (not separate services)

| Module | Responsibility | Key files |
|---|---|---|
| **Auth** | JWT verification, user provisioning, OTP relay | `routers/auth.py`, `dependencies.py` |
| **Items** | CRUD, image upload, trigger vision tagging | `routers/items.py`, `services/item_service.py` |
| **Vision** | Background removal, GPT-4o tagging, embedding generation | `services/vision_tagger.py`, `services/bg_remover.py` |
| **Outfits** | Rule engine, LLM ranker, shuffle, feedback | `routers/outfits.py`, `services/rule_engine.py`, `services/llm_ranker.py` |
| **Lookbooks** | Save/retrieve outfit collections | `routers/lookbooks.py` |
| **Preferences** | User style profile, onboarding quiz results | `routers/preferences.py` |
| **Weather** | Cached weather fetch per city | `services/weather.py` |
| **Storage** | R2 upload/download, signed URLs, local fallback | `utils/storage.py` |
| **Push** | FCM token registration, notification dispatch | `services/push.py` |

---

## Data Flow

### Item Upload Flow (most complex path)

```
User captures photo
        |
        v
Flutter: Photo Guide overlay checks (brightness, framing)
        |
        v
Flutter: Compress to JPEG (max 1200px width, 85% quality)
        |
        v
POST /items/upload (multipart: image + optional metadata)
        |
        v
Backend: validate_image_upload() -- MIME, magic bytes, size
        |
        v
Backend: bg_remover.remove(image_bytes)
        |  rembg runs in thread pool (CPU-bound)
        v
Backend: upload_image(user_id, item_id, processed_bytes) --> R2
        |
        v
Backend: vision_tagger.tag(image_bytes)
        |  POST to OpenAI GPT-4o Vision with structured JSON schema
        |  Retry up to 3x with exponential backoff
        v
Backend: parse tags --> Item row in PostgreSQL
        |
        v
Backend: generate_embedding(attribute_string) --> pgvector column
        |
        v
Response: { item_id, image_url, tags: {...}, confidence }
        |
        v
Flutter: show auto-tag review screen (chips, tap to edit)
        |
        v
If user edits: PATCH /items/{id} --> update tags + re-embed
```

### Outfit Generation Flow

```
User taps "Get Today's Outfits" or opens app (auto-trigger)
        |
        v
POST /outfits/generate { occasion, weather_override? }
        |
        v
Backend: check cache (user_id, date, occasion)
        |
        +-- cache hit --> return cached 3 outfits
        |
        +-- cache miss:
                |
                v
        weather.get_current(user_city) --> temp, condition, humidity
                |
                v
        rule_engine.generate_candidates(wardrobe, preferences, weather, occasion)
                |  Filter by season, occasion, formality
                |  Build combos: top + bottom + footwear + optional layers
                |  Score by color harmony + formality match + diversity
                |  Output: top 20 candidates with rule_score
                v
        llm_ranker.rank(candidates, user_profile, feedback_history)
                |  Single GPT-4o call, structured JSON output
                |  Returns: top 3 with 1-line styling reason each
                v
        Cache result for 24h
                |
                v
        Response: [ { outfit_id, items: [...], reason, score }, x3 ]
```

---

## Infrastructure Topology

### Development (your Mac)

```
VS Code
  |
  +-- Flutter app (iOS Simulator + Android Emulator)
  |     runs via: flutter run
  |
  +-- FastAPI backend
  |     runs via: uvicorn app.main:app --reload --port 8000
  |     connects to: local PostgreSQL (Docker or Homebrew)
  |     storage: local filesystem (./uploads/)
  |
  +-- PostgreSQL (Docker container or Homebrew service)
        port 5432
        with pgvector extension
```

### Production

```
Hetzner CX22 VPS (4 GB RAM, 2 vCPU, 40 GB SSD) -- EUR 4.50/mo
  |
  +-- Docker Compose
        |
        +-- nginx (port 80/443, TLS via Let's Encrypt certbot)
        |     reverse proxies to backend:8000
        |
        +-- backend (FastAPI + uvicorn, port 8000)
        |     2 uvicorn workers
        |     connects to postgres container
        |     connects to R2 via boto3
        |
        +-- postgres (PostgreSQL 16 + pgvector, port 5432)
              data volume: /var/lib/postgresql/data (persistent)

Cloudflare R2
  |
  +-- Bucket: drapeai-images
        stores: processed item photos, demo wardrobe assets

Cloudflare DNS
  |
  +-- api.drapeai.app --> Hetzner VPS IP
  +-- images.drapeai.app --> R2 custom domain (optional, or use signed URLs)

Firebase
  |
  +-- Firebase Auth (phone OTP + Google sign-in)
  +-- Firebase Cloud Messaging (push notifications)
  +-- Firebase Analytics (optional, or PostHog)
```

---

## Request Flow

Every request from the Flutter app follows this path:

```
1. Flutter: Dio sends HTTPS request with Authorization: Bearer <firebase_jwt>
2. Cloudflare DNS resolves api.drapeai.app
3. Nginx terminates TLS, proxies to backend:8000
4. FastAPI middleware: CORS check
5. FastAPI dependency: get_current_user()
   a. Extract JWT from Authorization header
   b. Verify signature against Firebase public keys (cached)
   c. Extract user_id (Firebase UID)
   d. Fetch or auto-provision user row in PostgreSQL
   e. Return User object (injected into endpoint)
6. Router handler executes business logic
7. Response returns through Nginx --> Cloudflare --> Flutter
```

---

## Auth Architecture

```
+-------------+     +----------------+     +----------------+
| Flutter App | --> | Firebase Auth  | --> | Firebase       |
| (firebase   |     | (Google/OTP)   |     | Issues JWT     |
|  auth pkg)  |     +----------------+     +-------+--------+
+------+------+                                    |
       |                                           |
       | JWT in Authorization header               |
       v                                           v
+------+------+     +----------------+     +-------+--------+
| FastAPI     | --> | Verify JWT     | --> | PostgreSQL     |
| Backend     |     | (firebase pub  |     | users table    |
|             |     |  keys, cached) |     | auto-provision |
+-------------+     +----------------+     +----------------+
```

**Key decisions:**
- Firebase Auth handles all identity (Google sign-in, phone OTP)
- Backend never stores passwords
- User row in PostgreSQL is auto-provisioned on first API call
- JWT verification uses Firebase public keys (fetched + cached for 1 hour)
- Dev mode: when `ENVIRONMENT=development`, accept a hardcoded test token

---

## AI Layer Architecture

Detailed in [AI Pipeline](ai_pipeline.md). Summary:

```
+-------------------+
| Image Upload      |
+--------+----------+
         |
         v
+--------+----------+     +-------------------+
| Background Remove |     | GPT-4o Vision     |
| (rembg, on-CPU)   | --> | (tag extraction)  |
+-------------------+     +--------+----------+
                                   |
                                   v
                          +--------+----------+
                          | Embedding Gen     |
                          | (text-embedding-  |
                          |  3-small)         |
                          +--------+----------+
                                   |
                                   v
                          +--------+----------+
                          | PostgreSQL        |
                          | (pgvector store)  |
                          +-------------------+

+-------------------+
| Outfit Request    |
+--------+----------+
         |
         v
+--------+----------+     +-------------------+
| Rule Engine       | --> | LLM Ranker        |
| (Python, determ.) |     | (GPT-4o, JSON)    |
| 20 candidates     |     | top 3 + reasons   |
+-------------------+     +-------------------+
```

---

## Storage Architecture

| Data Type | Storage | Format | Access Pattern |
|---|---|---|---|
| Item photos (processed, bg-removed) | Cloudflare R2 | PNG, ~100-300 KB each | Read-heavy; served via signed URL or CDN |
| Item metadata | PostgreSQL `items` table | JSONB columns + typed columns | Filtered queries |
| Item embeddings | PostgreSQL pgvector | vector(1536) | Cosine similarity search |
| Outfit definitions | PostgreSQL `outfits` table | Array of item_ids | Read on app open |
| User preferences | PostgreSQL `preferences` table | JSONB | Read on every outfit gen |
| Outfit cache | PostgreSQL `outfit_cache` table | JSON, TTL 24h | Key: (user_id, date, occasion) |
| Push tokens | PostgreSQL `push_tokens` table | FCM token string | Write on app launch, read on push |
| Demo wardrobe | R2 + seeded DB rows | Same as user items | Read-only, shared across users |

### Storage sizing (1,000 MAU estimate)
- Average 30 items/user x 200 KB/image = 6 MB/user
- 1,000 users = 6 GB R2 storage
- R2 free tier: 10 GB storage, 10M reads/month -- fits comfortably
- PostgreSQL: ~50 MB for 30,000 item rows with embeddings

---

## Caching Strategy

| What | Where | TTL | Invalidation |
|---|---|---|---|
| Weather per city | PostgreSQL `weather_cache` table | 1 hour | Overwritten on next fetch |
| Outfit set (user + date + occasion) | PostgreSQL `outfit_cache` table | 24 hours | Invalidated when user adds/removes items |
| Firebase JWT public keys | In-memory (Python dict) | 1 hour | Refetch on expiry |
| User preferences | In-memory (per-request from DB) | None (always fresh) | -- |

No Redis. PostgreSQL handles all caching at this scale. Add Redis only if request latency becomes an issue past 10,000 users.

---

## Push Notification Flow

```
1. Flutter app registers FCM token on launch
   POST /push/register { token, platform }

2. Backend stores token in push_tokens table

3. Daily cron (or scheduled task):
   a. For each user with a calendar outfit for today:
      - Fetch outfit details
      - Send FCM push: "Your outfit for today is ready"
   b. For users without calendar outfit:
      - Generate daily outfit (if not cached)
      - Send FCM push: "We picked 3 outfits for you today"

4. User taps notification --> deep link to Today's Outfits screen
```

Implementation: FastAPI background task or a simple cron script that runs via `docker exec` or a lightweight scheduler like `apscheduler`.

---

## Scaling Path (When Needed)

| Threshold | Action |
|---|---|
| 0 -- 5,000 users | Single Hetzner CX22. No changes needed. |
| 5,000 -- 20,000 | Upgrade to CX32 (8 GB RAM). Add 4 uvicorn workers. |
| 20,000 -- 50,000 | Move PostgreSQL to managed (Supabase/Neon). Add second backend instance behind Nginx load balancer. |
| 50,000+ | Consider Kubernetes or managed container service. Add Redis for caching. Separate vision tagging into async worker queue. |

The app is stateless (all state in PostgreSQL + R2). Horizontal scaling is straightforward.
