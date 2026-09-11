# Sugatai — Agent / Copilot Instructions

> **Audience:** GitHub Copilot, Claude Code, Cursor, and any AI agent generating or reviewing code in this repo.  
> **Purpose:** Keep AI-generated code aligned with Sugatai architecture, security invariants, and coding conventions.

**Last updated:** 2026-08-15

---

## 1. Project Context

**Sugatai** (repo folder: Sugatai) is an AI personal stylist for India: upload wardrobe items, get outfit recommendations, track wears, and virtual try-on. Non-technical brief: [../PRODUCT.md](../PRODUCT.md).

| Package | Stack | Responsibility |
|---|---|---|
| `api/` | Python 3.11 + FastAPI | Auth, wardrobe, outfits, lookbooks, try-on jobs, admin APIs, ARQ workers |
| `app/` | Flutter 3.x + Riverpod + GoRouter | Mobile client (Android / iOS) — product name Sugatai |
| `admin/` | Vite + React | Ops console at `/workadmin/` |
| `web/` | Vite + Workers | Marketing site + waitlist |
| `api-edge/` | Cloudflare Worker | Optional API edge proxy |
| `infra/` | Docker Compose / Swarm + Nginx + Redis | Local + prod runtime |
| `infra/runpod/idm-vton-worker/` | Docker + RunPod Serverless | Optional IDM-VTON GPU try-on |
| `design-system/sugatai/` | Brand tokens | Visual system |

**Read first:**
- [../instructions/FOLLOW-THESE.md](../instructions/FOLLOW-THESE.md)
- [../README.md](../README.md) — handbook index
- [CODING-STANDARDS.md](CODING-STANDARDS.md)
- [CODING-RULES-HANDBOOK.md](CODING-RULES-HANDBOOK.md)
- [../architecture/OVERVIEW.md](../architecture/OVERVIEW.md)

---

## 2. Architecture Invariants (do not violate)

### Monolith API
- Backend is a **single FastAPI app**. Do not invent new microservices without an explicit request.
- Background work goes through **ARQ** + Redis, not ad-hoc threads.

### User isolation
- Authenticated user comes from **Firebase JWT** verification middleware / deps — never from a client-supplied `user_id` for authorization.
- Every SELECT/UPDATE/DELETE on user data must include `user_id = $N` (ownership check). Admin routes use explicit admin guards.

### Package boundaries
- Flutter talks to the API over HTTPS JSON only.
- Admin uses the same API with admin auth — no direct DB from the browser.
- Try-on providers (Vertex, Cloudflare, NVIDIA, Gemini, OpenAI, RunPod) are abstracted in `api/app/services/image_gen_provider.py` (+ job helpers). Prefer that layer over scattering provider SDKs in routes.

### Config
- All runtime secrets and toggles via env / `api/app/config.py` (`Settings`).
- Feature flags like `TRYON_*`, `RUNPOD_*`, spend caps belong in Settings — not hardcoded in routes.

---

## 3. Security Invariants

| Rule | Enforcement |
|---|---|
| Auth on private routes | Firebase JWT verified server-side |
| Ownership | `user_id` in SQL for every user resource |
| SQL | Parameterized queries only (`$1`, `$2`, …) |
| Uploads | MIME + magic bytes + size limits |
| Secrets | Never commit `.env`; never log API keys / tokens / JWTs |
| Errors | Log internals; return generic client messages |
| PII | Avoid logging phones, full emails, or raw photos in production logs |
| Rate limits | Respect Redis middleware; do not bypass without reason |

---

## 4. Python (`api/`)

- Python 3.11+, FastAPI, async/await throughout
- Pydantic models in `app/models/`
- asyncpg for SQL (raw SQL in `app/database/queries/`)
- `httpx` for outbound HTTP (not sync `requests` in async handlers)
- `logging` module — not `print()` for application logs
- Tests: `pytest` + `pytest-asyncio` under `api/tests/`

### Forbidden
- String-concatenated SQL
- Trusting client `user_id` for authz
- Sync blocking I/O on the event loop
- Bare `except:`
- Committing secrets or real device/Firebase config with private keys

---

## 5. Dart / Flutter (`app/`)

- Feature folders under `lib/features/` with data / presentation / providers
- Theme tokens via `AppColors` / `AppTheme` — light theme only
- Riverpod for state; GoRouter for navigation; Dio for HTTP
- Material Icons only — no emoji in UI strings

### Forbidden
- Hardcoded API base URLs sprinkled outside config/constants
- Catching errors and showing raw stack traces to users
- Dark-mode-only designs / neon purple starter kits that fight the design system

---

## 6. Admin (`admin/`)

- Vite + React; call documented admin API routes only
- No embedded long-lived secrets; use login flow already established

---

## 7. Try-on / RunPod

- Prefer provider cascade via Settings (`TRYON_PROVIDER_*`, `RUNPOD_*`).
- IDM-VTON worker lives under `infra/runpod/idm-vton-worker/` — see [../services/TRYON-WORKER.md](../services/TRYON-WORKER.md).
- **License:** IDM-VTON is CC BY-NC-SA 4.0. Do not assume commercial use is OK.
- Cold starts are slow; timeouts must account for HF download + GPU queue.

---

## 8. Before you finish a task

- [ ] Ownership / auth checks in place
- [ ] No secrets in diffs
- [ ] Tests updated when behaviour changes (`api/tests/`, `app/test/`)
- [ ] Relevant `docs/` page updated if APIs or ops change
- [ ] Run focused tests rather than inventing unrelated refactors

Human review mandatory for: auth, payments (if any), migrations that rewrite data, and try-on spend / license changes.

---

## 9. When uncertain

Search existing code first (routes, services, queries). Prefer safer defaults. Flag risky assumptions with `# REVIEW NEEDED:` / `// REVIEW NEEDED:` — do not invent security or billing behaviour.
