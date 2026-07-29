# DrapeAI — Coding Standards

Rules for all code in this monorepo. Read before writing code.

> **Last updated:** 2026-07-14  
> **Handbook:** [../README.md](../README.md)

**Companions:**
- [CODING-RULES-HANDBOOK.md](CODING-RULES-HANDBOOK.md) — day-to-day checklist
- [AGENTS.md](AGENTS.md) — architecture invariants for agents
- [../coding_standards.md](../coding_standards.md) — longer shared standards (legacy deep dive)
- [../backend/coding_standards.md](../backend/coding_standards.md) — Python/FastAPI detail
- [../frontend/coding_standards.md](../frontend/coding_standards.md) — Dart/Flutter detail
- [../instructions/](../instructions/) — task profiles

---

## Critical Rules

### 1. No emojis

Never use emoji in code, UI copy, comments, logs, or commit messages. Use Material Icons (Flutter) or Lucide/MUI-style icons (admin).

### 2. Light theme only

Follow `AppColors` / `AppTheme`. No dark mode toggle. No neon purple “AI default” looks unless the existing design system already uses that accent intentionally (`indigo` accent is OK — see palette in `docs/coding_standards.md`).

### 3. Security first

- Parameterized SQL only
- Ownership: `user_id` on every user-scoped query
- Validate uploads (type, size, magic bytes)
- Never log secrets or full JWTs
- Generic 500 messages to clients; details in server logs

### 4. User identity from auth context

```python
# CORRECT — user from verified JWT dependency
async def get_item(item_id: UUID, user: User = Depends(get_current_user)):
    ...

# WRONG — client-supplied user id for authz
async def get_item(item_id: UUID, user_id: UUID):
    ...
```

### 5. Async I/O (API)

Use `asyncpg`, `httpx.AsyncClient`, ARQ for long jobs. Do not block the event loop with CPU-heavy vision sync work without offloading (worker / thread as the codebase already does).

### 6. Feature modules (Flutter)

Keep features under `lib/features/<name>/` with clear data / presentation / providers split. Shared chrome stays in `lib/core/`.

### 7. Provider abstraction for AI / try-on

Add provider calls through existing service layers (`ai_provider`, `image_gen_provider`, `vision_tagger`, etc.). Do not scatter raw OpenAI/RunPod clients in routers.

### 8. Migrations

- Prefer incremental SQL under `api/db/migrations/` / Alembic as used by the repo
- Never drop columns/tables without a rollback note in the PR
- Seed/demo data must be idempotent where possible

### 9. Tests

- Backend: pytest-asyncio for routes and critical services
- Flutter: widget tests for screens that change UX behaviour
- Prefer updating an existing test file over adding duplicates

### 10. Docs with behaviour changes

Update the matching page under `docs/` (API reference, try-on worker, session lessons, etc.).

### 11. Secrets

No live keys in git. `.env` / Firebase private material stay local. Document new vars in `.env.example` and [../local-development/ENV-VARS.md](../local-development/ENV-VARS.md).

### 12. Scope discipline

Match local style. No drive-by refactors. No unrelated files in the same change.

---

## Language quick rules

| Stack | Do | Don't |
|-------|-----|-------|
| Python | async, Pydantic, parameterized SQL, `logging`, `httpx` | `print` for app logs, SQL f-strings, sync HTTP in async handlers |
| Dart | Riverpod, GoRouter, `AppColors`, Dio + auth interceptor | emoji UI, hard-coded secrets, swallowing errors silently |
| React admin | Call admin APIs, typed client helpers | Direct DB, embed API keys |

---

## Before merge (self-check)

Ownership test path covered · auth returns 401/403 · no secrets in diff · linters/tests for touched areas · docs updated if API/ops changed · human review for auth / migrations / spend-heavy try-on.
