# Environment variables

Document new variables here **and** in `api/.env.example` (and Flutter/Firebase configs as needed).

> Never commit live `.env` files.

## Backend (`api/.env`)

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Postgres connection string |
| `OPENAI_API_KEY` | Vision / ranking / embeddings (as configured) |
| `ANTHROPIC_API_KEY` | Optional alternate LLM |
| `NVIDIA_API_KEY` | Optional NIM try-on / models |
| `GROQ_API_KEY` | Optional Groq |
| `GEMINI_API_KEY` | Wardrobe vision + Developer API try-on fallback |
| `GOOGLE_CLOUD_PROJECT` | Vertex AI project id (e.g. `sugatai`) |
| `GOOGLE_CLOUD_LOCATION` | Vertex region (default `us-central1`) |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account JSON (never commit) |
| `VERTEX_MODEL_IMAGE` / `VERTEX_MODEL_IMAGE_HD` | Try-on image model ids on Vertex |
| `VERTEX_SPEND_CAP_USD` | Monthly Vertex spend cap |
| `FIREBASE_PROJECT_ID` (+ credentials path/JSON as used) | JWT verify |
| R2 keys / bucket / endpoint | Object storage in prod |
| Redis URL | Rate limit + ARQ |
| `TRYON_PROVIDER_PRIMARY` | e.g. `vertex`, `runpod`, `cloudflare`, `gemini` |
| `TRYON_MODEL_PRIMARY` | Provider-specific model id |
| `TRYON_PROVIDER_SECONDARY` / `TERTIARY` / `QUATERNARY` | Fallback cascade |
| `TRYON_MODEL_*` | Matching model ids |
| `TRYON_IMAGE_QUALITY` | OpenAI edits quality (`high` default — HD) |
| `TRYON_IMAGE_SIZE` | OpenAI size (default `1024x1536`) |
| `TRYON_ENABLED` / `TRYON_ASYNC` / `TRYON_DAILY_LIMIT_FREE` | Feature + quota |
| `CLOUDFLARE_ACCOUNT_ID` / `CLOUDFLARE_API_TOKEN` | CF Workers AI try-on |
| `RUNPOD_API_KEY` / `RUNPOD_ENDPOINT_ID` | Serverless IDM-VTON |
| `RUNPOD_TRYON_TIMEOUT_SEC` | Sync/async wait budget |
| `ENVIRONMENT` | `development` \| `staging` \| `production` |
| `CORS_ORIGINS` | Comma-separated (prod) |
| `REQUIRE_PRODUCTION` | Refuse boot unless `ENVIRONMENT=production` |
| `REDIS_URL` | Rate limit + ARQ. **Required in production**; optional in local compose |
| `SIGNED_URL_TTL_SEC` | Signed R2 image URL lifetime (default 3600). Bucket stays private |
| `SENTRY_DSN` | Production error tracking (optional but recommended) |
| Spend caps (`*_SPEND_CAP_USD`, `TOTAL_SPEND_CAP_USD`) | Cost control |

Weather uses **Open-Meteo** — no `OPENWEATHER_API_KEY`.

Exact field names: `api/app/config.py` (`Settings`) and `api/.env.example`.

## Flutter

- `--dart-define=API_BASE_URL=...` and `ENABLE_DEV_TEST_FLOW` (see `app/lib/core/constants/environment.dart`)
- iOS bundle id: `com.sugatai.sugatai` — download matching `GoogleService-Info.plist` from Firebase; file is gitignored (use `*.example` templates only)

## RunPod worker

- Baked into template env: `ALLOW_STUB`, `IDM_ROOT`, `MODEL_DIR`, `RUNPOD_INIT_TIMEOUT`, etc.
- See [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
