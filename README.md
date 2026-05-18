# DrapeAI

AI-powered personal stylist for India. Upload clothing items, get outfit recommendations powered by GPT-4o, and build a smart digital wardrobe.

---

## Architecture

```
DrapeAI/
├── api/                   # FastAPI backend (Python 3.11)
│   ├── app/
│   │   ├── auth/          # Firebase JWT verification
│   │   ├── database/      # asyncpg pool + SQL queries
│   │   ├── models/        # Pydantic schemas
│   │   ├── routes/        # HTTP endpoints
│   │   ├── services/      # AI pipeline, outfit logic
│   │   └── utils/         # Image validation, cost tracking
│   ├── db/
│   │   └── init.sql       # PostgreSQL schema
│   ├── tests/             # pytest-asyncio tests
│   ├── Dockerfile
│   ├── requirements.txt
│   └── .env.example
├── app/                   # Flutter mobile app
│   └── lib/
│       ├── core/          # Theme, routing, network client
│       └── features/      # auth, wardrobe, outfits, lookbooks, profile
├── infra/                 # Docker Compose + Nginx
│   ├── docker-compose.dev.yml
│   ├── docker-compose.prod.yml
│   └── nginx/nginx.conf
└── docs/                  # Design and implementation docs
```

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.41.7 + Riverpod + GoRouter |
| Backend | FastAPI + Python 3.11 |
| Database | PostgreSQL 16 + pgvector |
| Auth | Firebase Auth (phone OTP + Google) |
| AI | GPT-4o vision + text-embedding-3-small |
| Storage | Cloudflare R2 (prod), local filesystem (dev) |
| BG Removal | rembg (ONNX) |
| Weather | Open-Meteo (free, no key) |

---

## Quick Start (Development)

### Prerequisites
- Docker + Docker Compose
- Flutter 3.41.7
- Firebase project with Phone Auth + Google sign-in enabled

### 1. Backend

```bash
# Copy and fill in environment variables
cp api/.env.example api/.env

# Start DB + API
docker compose -f infra/docker-compose.dev.yml up

# API is at http://localhost:8000
# Health check: curl http://localhost:8000/health
```

### 2. Flutter App

```bash
cd app

# Install deps
flutter pub get

# Add google-services.json (Android) and GoogleService-Info.plist (iOS)
# from your Firebase console

# Run on device/emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:8000   # iOS simulator
```

### 3. Run tests

```bash
cd api
python -m pytest tests/ -v
```

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `OPENAI_API_KEY` | OpenAI API key |
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `R2_ACCOUNT_ID` | Cloudflare R2 account (production) |
| `R2_ACCESS_KEY_ID` | R2 access key |
| `R2_SECRET_ACCESS_KEY` | R2 secret key |
| `R2_BUCKET_NAME` | R2 bucket name |
| `R2_PUBLIC_URL` | R2 public base URL |
| `SENTRY_DSN` | Sentry error tracking (optional) |

See `api/.env.example` for the full list.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/health` | Health check |
| `POST` | `/auth/verify` | Verify Firebase token, provision user |
| `GET/PATCH` | `/me` | Get/update profile |
| `PUT/GET` | `/me/preferences` | Style preferences |
| `POST` | `/items/upload` | Upload clothing item (multipart) |
| `GET` | `/items` | List items with filters |
| `GET/PATCH/DELETE` | `/items/{id}` | Item CRUD |
| `POST` | `/outfits/generate` | Generate 3 AI outfits |
| `POST` | `/outfits/shuffle` | Random outfit (no LLM) |
| `POST` | `/outfits/{id}/feedback` | Like/dislike/wear/save |
| `GET` | `/outfits/today` | Today's cached outfits |
| `CRUD` | `/lookbooks` | Lookbook management |
| `POST` | `/push/register` | Register FCM token |
| `GET` | `/demo/wardrobe` | Demo wardrobe items |

---

## AI Pipeline

When a clothing item is uploaded:
1. **Background removal** — rembg strips background (~1s)
2. **Storage** — saved to R2 / local filesystem
3. **Vision tagging** — GPT-4o analyses image, returns category, color, pattern, fabric, formality, style tags (~3s, ~$0.03)
4. **Embedding** — text-embedding-3-small generates 1536-dim vector (~0.1s, ~$0.0001)

When outfits are generated:
1. Rule engine filters wardrobe and scores color/formality/ethnic combos
2. Top 20 candidates sent to GPT-4o for final ranking with reasons
3. Results cached 24h per user+occasion+date

---

## License

MIT
