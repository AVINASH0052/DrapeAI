# DrapeAI -- Documentation Index

> AI Outfit Assistant. Built for India. Flutter + FastAPI + GPT-4o Vision.

All project documentation lives in this folder. Read these docs before writing any code. The master plan is at [PLAN.md](../PLAN.md).

---

## Backend (`backend/`)

Everything needed to build the FastAPI + PostgreSQL + AI backend.

| Document | What It Covers |
|---|---|
| [README](backend/README.md) | Backend build order (13 phases), quick reference commands |
| [Implementation Guide](backend/implementation_guide.md) | Step-by-step code for every module: scaffold, auth, items, AI pipeline, outfits, lookbooks, push, testing |
| [Coding Standards](backend/coding_standards.md) | 12 Python/FastAPI rules: security, async, error handling, naming, testing, git |
| [Database Schema](backend/database_schema.md) | 13 PostgreSQL tables with DDL, indexes, migrations, useful queries |
| [API Reference](backend/api_reference.md) | Every endpoint: request/response, rate limits, error codes |
| [AI Pipeline](backend/ai_pipeline.md) | Upload pipeline, outfit pipeline, rule engine, LLM ranker, cost control, prompts |

## Frontend (`frontend/`)

Everything needed to build the Flutter mobile app.

| Document | What It Covers |
|---|---|
| [README](frontend/README.md) | Frontend build order (13 phases), design system tokens, quick reference commands |
| [Implementation Guide](frontend/implementation_guide.md) | Step-by-step code for every screen: scaffold, auth, onboarding, camera, wardrobe grid, outfits, shuffle, lookbooks, profile, polish |
| [Coding Standards](frontend/coding_standards.md) | 15 Dart/Flutter rules: theme, Riverpod, GoRouter, Dio, naming, testing, git |
| [UI/UX Specification](frontend/ui_ux_spec.md) | Design system, typography, spacing, component library, 12 screen specs, animations |

## Shared

| Document | What It Covers |
|---|---|
| [Market Launch Plan](MARKET_LAUNCH_PLAN.md) | Closed beta → Play Store path: blockers, phases, metrics, what not to build |
| [Architecture](architecture.md) | System topology, service boundaries, data flows, auth, caching, scaling path |
| [Deployment](deployment.md) | Hetzner setup, Docker Compose, Nginx + TLS, R2, Firebase, CI/CD, backups, monitoring |
| [Store Submission](store_submission.md) | Play Store + App Store: signing, building, screenshots, listing copy, review guidelines |
| [Project Structure](project_structure.md) | Exact folder layout for app/ + api/ + infra/, every file explained |
| [Environment Setup](environment_setup.md) | Dev machine setup: Flutter, Xcode, Android SDK, Python, PostgreSQL, VS Code config |

---

## Quick Links

- **Start here:** [Master Plan](../PLAN.md)
- **Build backend:** [Backend Implementation Guide](backend/implementation_guide.md)
- **Build frontend:** [Frontend Implementation Guide](frontend/implementation_guide.md)
- **Run locally:** [Environment Setup](environment_setup.md)
- **Deploy to production:** [Deployment](deployment.md)
- **Submit to stores:** [Store Submission](store_submission.md)
