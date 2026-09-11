# Architecture overview

> **Audience:** Engineers and agents working across this monorepo.  
> **Last updated:** 2026-08-15  
> **Product name:** Sugatai · **Repo folder:** Sugatai  
> **Deep dive:** [../architecture.md](../architecture.md) · [DRAWIO-MERMAID.md](DRAWIO-MERMAID.md)

## Packages

| Package | Stack | Owns |
|---|---|---|
| `api/` | FastAPI + asyncpg + ARQ | Auth, avatar, wardrobe, outfits, try-on, admin APIs |
| `app/` | Flutter + Riverpod | Consumer mobile UX (Sugatai) |
| `admin/` | Vite + React | Ops console at `/workadmin/` |
| `web/` | Vite + Workers | Marketing site + waitlist |
| `api-edge/` | Cloudflare Worker | Optional API edge proxy |
| `infra/` | Compose / Swarm + Nginx + Redis | Process topology |
| `infra/runpod/idm-vton-worker/` | RunPod Serverless GPU | Optional IDM-VTON try-on |
| `design-system/sugatai/` | Tokens / brand | Product visual system |

Single FastAPI monolith. Split only when a measured bottleneck forces it.

## Request path

```
Flutter / Admin / web
  → HTTPS (Nginx or Cloudflare tunnel / Workers in prod)
  → FastAPI (:8000)
       ├─ PostgreSQL (+ pgvector, 1024-dim embeddings)
       ├─ Redis (rate limit + ARQ) — required in prod; optional in local compose
       ├─ Cloudflare R2 (images) or local ./uploads in development
       ├─ Firebase Auth verify
       └─ AI providers (Gemini / Vertex / OpenAI / Anthropic / Groq / NVIDIA / Cloudflare / RunPod)
```

## Core flows

### Body-first avatar

```
Firebase login / compile-time dev entry
  → POST full-body source photo
  → avatar_status=queued
  → ARQ (or BackgroundTasks fallback):
       validate pose + visibility
       segment person to transparent PNG
       persist renderability metadata only
  → avatar_status=ready
  → Flutter Avatar Studio
```

### Wardrobe upload

```
Camera → compress → POST /items (or wardrobe upload)
  → validate image → store → ARQ: garment split / rembg + vision tag + embed
  → item ready in wardrobe
```

### Outfit recommend

```
Preferences + weather (Open-Meteo) + wardrobe
  → rule_engine (filter)
  → llm_ranker (rank + reason)
  → outfits API → Flutter Today / shuffle
```

### Try-on (“See me in this”)

```
Person + garment images
  → try_on_job / image_gen_provider cascade
       (RunPod IDM-VTON | Cloudflare | NVIDIA | Gemini | Vertex | OpenAI | composite)
  → result image stored → app displays
```

### Avatar Studio render

```
Avatar Studio selected slots
  → POST /avatar/render
  → validate item ownership + processing status + slot compatibility
  → save manual outfit
  → try_on_job / image_gen_provider pipeline
  → poll and swap completed preview into the studio
```

## Auth

Firebase issues ID tokens → Flutter Dio attaches `Authorization: Bearer` → FastAPI verifies → `user_id` for all ownership checks.

`Bearer test-token` is accepted only when `ENVIRONMENT=development`. Flutter developer entry requires `--dart-define=ENABLE_DEV_TEST_FLOW=true`.

## Detailed docs

- [DECISIONS.md](DECISIONS.md)
- [DRAWIO-MERMAID.md](DRAWIO-MERMAID.md)
- [../architecture.md](../architecture.md)
- [../backend/ai_pipeline.md](../backend/ai_pipeline.md)
- [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
- [../services/ADMIN.md](../services/ADMIN.md)
