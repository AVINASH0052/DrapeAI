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
| `GEMINI` / Google AI key (as named in Settings) | Try-on secondary/fallback |
| `FIREBASE_PROJECT_ID` (+ credentials path/JSON as used) | JWT verify |
| R2 keys / bucket / endpoint | Object storage in prod |
| Redis URL | Rate limit + ARQ |
| `TRYON_PROVIDER_PRIMARY` | e.g. `runpod`, `cloudflare`, `gemini` |
| `TRYON_MODEL_PRIMARY` | Provider-specific model id |
| `TRYON_PROVIDER_SECONDARY` / models | Fallback cascade |
| `RUNPOD_API_KEY` | Serverless API |
| `RUNPOD_ENDPOINT_ID` | e.g. IDM-VTON endpoint |
| `RUNPOD_TRYON_TIMEOUT_SEC` | Sync/async wait budget |
| Spend caps (`OPENAI_SPEND_CAP_USD`, etc.) | Cost control |

Exact field names: `api/app/config.py` (`Settings`).

## Flutter

- API base URL via app config / flavors (see `app/` docs and `lib/core/constants`)
- `GoogleService-Info.plist` / `google-services.json` — **do not commit private production keys unexpectedly**; follow team policy

## RunPod worker

- Baked into template env: `ALLOW_STUB`, `IDM_ROOT`, `MODEL_DIR`, `RUNPOD_INIT_TIMEOUT`, etc.
- See [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
