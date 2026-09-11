# Sugatai

AI-powered personal stylist for India. Upload clothing items, get AI outfit recommendations, track what you wear, and virtual try-on.

**Product name:** Sugatai · **Repo folder:** `Sugatai` · **API:** `https://api.sugatai.com` · **Admin:** `https://app.sugatai.com/workadmin/`

Infra identifiers may still say `drapeai` (Postgres user/db, some Docker names, `/health` `service` field). Firebase project id is `sugatai-41e84`.

## Documentation

**Start here → [docs/README.md](docs/README.md)**

| Need | Doc |
|---|---|
| Run locally | [docs/local-development/](docs/local-development/) |
| Architecture | [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) · [docs/architecture/DRAWIO-MERMAID.md](docs/architecture/DRAWIO-MERMAID.md) |
| Deploy / CI | [docs/deployment.md](docs/deployment.md) · [docs/services/ADMIN.md](docs/services/ADMIN.md) |
| Session lessons | [docs/ops/SESSION-LESSONS.md](docs/ops/SESSION-LESSONS.md) |
| Integrations | [docs/integrations/](docs/integrations/) |
| Coding rules | [docs/rules/CODING-STANDARDS.md](docs/rules/CODING-STANDARDS.md) |
| Agent invariants | [docs/rules/AGENTS.md](docs/rules/AGENTS.md) · [AGENTS.md](AGENTS.md) |

---

## Architecture

```
Sugatai/                       # repo folder
├── api/                       # FastAPI backend (Python 3.11)
│   ├── app/routes/            # 17 routers (auth, avatar, items, outfits, try_on, admin, …)
│   ├── app/services/          # AI pipeline, try-on cascade, storage
│   ├── app/workers/           # ARQ background tasks + cron
│   ├── db/init.sql + alembic/ # Schema + migrations
│   └── tests/
├── app/                       # Flutter — Sugatai (com.sugatai.sugatai)
│   └── lib/features/          # auth, avatar, wardrobe, outfits, try_on,
│                              # lookbooks, calendar, analytics, …
├── admin/                     # Vite + React ops console (/workadmin/)
├── web/                       # Marketing site + waitlist Worker
├── api-edge/                  # Optional Cloudflare API edge Worker
├── design-system/sugatai/     # Brand tokens
├── infra/                     # Compose / Swarm / Nginx / Redis / RunPod worker
└── docs/                      # Handbook
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x + Riverpod + GoRouter (Sugatai) |
| Backend | FastAPI + Python 3.11 + asyncpg (raw SQL) |
| Database | PostgreSQL 16 + pgvector (1024-dim embeddings) |
| Auth | Firebase Auth (Phone OTP + Google + Apple) |
| AI | Multi-provider cascade (Gemini / Vertex / OpenAI / Anthropic / Groq / NVIDIA / Cloudflare / RunPod) |
| Embeddings | Primary `nvidia/nv-embedqa-e5-v5` (1024-dim) |
| Storage | Cloudflare R2 (prod), local `./uploads` (dev) |
| Cache/Queue | Redis 7 in prod (rate limit + ARQ); optional locally |
| Background | ARQ workers |
| Weather | Open-Meteo (no API key) |
| Admin | Vite + React + Recharts at port **5174** `/workadmin/` |
| Edge | Cloudflare Workers / tunnel (`api.sugatai.com`) |

---

## Quick Start (Development)

### Prerequisites
- Docker + Docker Compose
- Flutter 3.x
- Node.js 18+ (for admin dashboard)
- Firebase project with Phone Auth + Google + Apple sign-in enabled

### 1. Backend

```bash
# Copy and fill in environment variables
cp api/.env.example api/.env

# Start DB + API (Redis is optional locally — API falls back to in-memory rate limits)
docker compose -f infra/docker-compose.dev.yml up

# API is at http://localhost:8000
# Docs at http://localhost:8000/docs (dev only)
# Health check: curl http://localhost:8000/health
```

### 2. Flutter App

```bash
cd app
flutter pub get

# Add google-services.json (Android) and GoogleService-Info.plist (iOS)
# for bundle id com.sugatai.sugatai from your Firebase console

flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000   # iOS simulator
```

### 3. Admin Dashboard

```bash
cd admin
npm install
npm run dev
# Opens at http://localhost:5174/workadmin/ — proxies /admin and /uploads to :8000
```

### 4. Run Tests

```bash
cd api && python -m pytest tests/ -v
cd app && flutter test
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string (default: `redis://localhost:6379`) |
| `OPENAI_API_KEY` | OpenAI API key |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `R2_ACCOUNT_ID` | Cloudflare R2 account (production) |
| `R2_ACCESS_KEY_ID` | R2 access key |
| `R2_SECRET_ACCESS_KEY` | R2 secret key |
| `R2_BUCKET_NAME` | R2 bucket name |
| `R2_PUBLIC_URL` | R2 public base URL |
| `SENTRY_DSN` | Sentry error tracking (optional) |
| `ENVIRONMENT` | `development` or `production` |

See `api/.env.example` for the full list.

---

## API Endpoints

### Core
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/auth/verify` | Verify Firebase token, provision user |
| `GET/PATCH` | `/me` | Get/update profile |
| `PUT/GET` | `/me/preferences` | Style preferences |

### Wardrobe
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/items/upload` | Upload clothing item (multipart) |
| `GET` | `/items` | List items with filters |
| `GET/PATCH/DELETE` | `/items/{id}` | Item CRUD |
| `GET` | `/wardrobe/gaps` | Wardrobe gap analysis |

### Outfits
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/outfits/generate` | Generate 3 AI outfits |
| `POST` | `/outfits/shuffle` | Random outfit (no LLM) |
| `POST` | `/outfits/{id}/feedback` | Like/dislike/wear/save/skip |
| `GET` | `/outfits/today` | Today's cached outfits |
| `CRUD` | `/lookbooks` | Lookbook management |

### Calendar & Analytics
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/calendar?month=YYYY-MM` | Monthly outfit calendar |
| `POST/DELETE` | `/calendar/{date}` | Assign/remove outfit from date |
| `GET` | `/analytics/overview` | Wardrobe stats & utilization |
| `GET` | `/analytics/wear-history` | Daily wear history |
| `GET` | `/analytics/category-breakdown` | Per-category cost-per-wear |

### Admin (requires `is_admin=TRUE`)
| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/admin/stats` | KPI dashboard metrics |
| `GET` | `/admin/stats/timeseries` | Daily stats (30d) |
| `GET` | `/admin/users` | Paginated user list |
| `PUT` | `/admin/users/{id}/suspend` | Toggle user suspension |
| `DELETE` | `/admin/users/{id}` | Delete user + cascade |
| `GET` | `/admin/ai-usage` | AI cost by provider/model |
| `GET` | `/admin/system-health` | DB, tables, uptime |

### Other
| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/push/register` | Register FCM push token |
| `GET` | `/notifications` | User notifications |

---

## AI Pipeline

When a clothing item is uploaded:
1. **Garment split** — worn outfits can become multiple pieces; otherwise rembg on the whole image
2. **Storage** — saved to R2 / local filesystem
3. **Vision tagging** — multi-provider cascade (Gemini / NVIDIA / OpenAI / …) → category, color, pattern, fabric, formality, style tags
4. **Embedding** — primary `nvidia/nv-embedqa-e5-v5` (1024-dim); OpenAI `text-embedding-3-small` is fallback

When outfits are generated:
1. Rule engine filters wardrobe and scores color/formality/ethnic combos
2. Top candidates sent to the RANK LLM for final ranking with reasons
3. Results cached 24h per user+occasion+date

---

## Database Migrations

```bash
# New databases: init.sql creates the full schema
psql -U drapeai -d drapeai -f api/db/init.sql

# Existing databases: stamp baseline + run migrations
cd api
alembic stamp 0001_baseline
alembic upgrade head

# Create a new migration
alembic revision -m "description"
```

---

## Production Deployment

```bash
# Single-server with Docker Compose
docker compose -f infra/docker-compose.prod.yml up -d

# Zero-downtime with Docker Swarm (2 replicas, rolling update)
docker stack deploy -c infra/docker-compose.swarm.yml drapeai
```

---

## License

MIT
