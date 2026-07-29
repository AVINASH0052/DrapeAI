# Architecture overview

> **Audience:** Engineers and agents working across DrapeAI packages.  
> **Last updated:** 2026-07-18  
> **Deep dive:** [../architecture.md](../architecture.md)

## Packages

| Package | Stack | Owns |
|---|---|---|
| `api/` | FastAPI + asyncpg + ARQ | Auth, avatar preparation, wardrobe, outfits, try-on jobs, admin APIs |
| `app/` | Flutter + Riverpod | Consumer mobile UX |
| `admin/` | Vite + React | Internal monitoring / users |
| `infra/` | Compose / Swarm + Nginx + Redis | Process topology |
| `infra/runpod/idm-vton-worker/` | RunPod Serverless GPU | Optional IDM-VTON try-on |

Single backend process (monolith). Split only when a measured bottleneck forces it.

## Request path

```
Flutter / Admin
  → HTTPS (Nginx in prod)
  → FastAPI (:8000)
       ├─ PostgreSQL (+ pgvector)
       ├─ Redis (rate limit + ARQ)
       ├─ Cloudflare R2 (images)
       ├─ Firebase Auth verify
       └─ AI providers (OpenAI / Anthropic / Groq / NVIDIA / Gemini / Cloudflare / RunPod)
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

The first production avatar is 2.5D. The transparent image preserves the
person's visible body structure; it is not presented as an accurate 3D scan
and does not infer measurements. The private source and derived avatar base
have explicit replace/delete controls.

### Wardrobe upload

```
Camera → compress → POST /items (or wardrobe upload)
  → validate image → store → ARQ: bg remove + vision tag + embed
  → item ready in wardrobe
```

### Outfit recommend

```
Preferences + weather + wardrobe
  → rule_engine (filter)
  → llm_ranker (rank + reason)
  → outfits API → Flutter Today / shuffle
```

### Try-on (“See me in this”)

```
Person + garment images
  → try_on_job / image_gen_provider cascade
       (RunPod IDM-VTON | Cloudflare | NVIDIA | Gemini | OpenAI | composite)
  → result image stored → app displays
```

### Avatar Studio render

```
Avatar Studio selected slots
  → POST /avatar/render
  → validate item ownership + processing status + slot compatibility
  → save manual outfit
  → existing try_on_job / image_gen_provider pipeline
  → Gemini primary, configured providers and composite fallback
  → poll in-place and swap the completed preview into the studio
```

## Auth

Firebase issues ID tokens → Flutter Dio attaches `Authorization: Bearer` → FastAPI verifies → `user_id` for all ownership checks.

`Bearer test-token` is accepted only when the API runs with
`ENVIRONMENT=development`. The Flutter developer entry and token fallback are
also absent unless the build explicitly sets
`--dart-define=ENABLE_DEV_TEST_FLOW=true`.

## Detailed docs

- [DECISIONS.md](DECISIONS.md)
- [../architecture.md](../architecture.md)
- [../backend/ai_pipeline.md](../backend/ai_pipeline.md)
- [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md)
