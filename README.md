# DrapeAI

AI-powered personal stylist for India. Upload clothing items, get AI outfit recommendations, track what you wear, and build a smart digital wardrobe.

---

## Architecture

```
DrapeAI/
├── api/                       # FastAPI backend (Python 3.11)
│   ├── app/
│   │   ├── auth/              # Firebase JWT verification + admin guards
│   │   ├── database/          # asyncpg pool + SQL queries
│   │   ├── middleware/        # Rate limiting (Redis), security headers
│   │   ├── models/            # Pydantic schemas
│   │   ├── routes/            # HTTP endpoints (15 routers)
│   │   ├── services/          # AI pipeline, Redis, outfit logic
│   │   └── workers/           # ARQ background tasks + cron
│   ├── db/
│   │   ├── init.sql           # PostgreSQL schema (canonical)
│   │   ├── migrations/        # Incremental SQL migrations (0002-0007)
│   │   └── alembic/           # Alembic migration framework
│   ├── tests/                 # pytest-asyncio integration tests (40+)
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── app/                       # Flutter mobile app
│   ├── lib/
│   │   ├── core/              # Theme, routing, network client
│   │   └── features/          # auth, wardrobe, outfits, lookbooks,
│   │                          # profile, calendar, analytics,
│   │                          # notifications, onboarding
│   └── test/                  # Widget tests (28+)
├── admin/                     # React admin dashboard (Vite)
│   └── src/
│       ├── pages/             # Dashboard, Users, SystemHealth, Login
│       └── services/          # API client
├── infra/                     # Docker Compose + Nginx + Redis
│   ├── docker-compose.dev.yml
│   ├── docker-compose.prod.yml
│   ├── docker-compose.swarm.yml  # Zero-downtime rolling deploys
│   ├── nginx/nginx.conf
│   └── redis/redis.conf
└── .github/workflows/         # CI/CD (test + deploy + Alembic)
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.x + Riverpod + GoRouter |
| Backend | FastAPI + Python 3.11 + asyncpg (raw SQL) |
| Database | PostgreSQL 16 + pgvector + JSONB |
| Auth | Firebase Auth (Phone OTP + Google + Apple) |
| AI | GPT-4o vision + text-embedding-3-small (1024-dim) |
| Storage | Cloudflare R2 (prod), local filesystem (dev) |
| Cache/Queue | Redis 7 (rate limiting, ARQ task broker) |
| Background | ARQ (async task queue, cron jobs) |
| Migrations | Alembic + raw SQL files |
| BG Removal | rembg (ONNX) |
| Weather | Open-Meteo (free, no key) |
| Admin | Vite + React + Recharts |
| Deploy | Docker Swarm (2 replicas, rolling update) |

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

# Start DB + Redis + API
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
# from your Firebase console

flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000   # iOS simulator
```

### 3. Admin Dashboard

```bash
cd admin
npm install
npm run dev
# Opens at http://localhost:5173, proxies API calls to :8000
```

### 4. Run Tests

```bash
# Backend (40+ integration tests)
cd api && python -m pytest tests/ -v

# Flutter (28 widget tests)
cd app && flutter test test/features/ --reporter compact
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
| `GET` | `/demo/wardrobe` | Demo wardrobe items |

---

## AI Pipeline

When a clothing item is uploaded:
1. **Background removal** — rembg strips background (~1s)
2. **Storage** — saved to R2 / local filesystem
3. **Vision tagging** — GPT-4o analyses image → category, color, pattern, fabric, formality, style tags (~3s, ~$0.03)
4. **Embedding** — text-embedding-3-small generates 1024-dim vector (~0.1s, ~$0.0001)

When outfits are generated:
1. Rule engine filters wardrobe and scores color/formality/ethnic combos
2. Top 20 candidates sent to GPT-4o for final ranking with reasons
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
