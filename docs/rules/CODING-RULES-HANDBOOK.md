# DrapeAI — Coding Rules Handbook

> **Use this while you code.** For full examples see [CODING-STANDARDS.md](CODING-STANDARDS.md).  
> **Last updated:** 2026-07-14 · Handbook: [../README.md](../README.md)

---

## How to use

| When | What to do |
|------|------------|
| Starting a task | Architecture + Before you write |
| Writing code | Per-layer checklist + language section |
| After behaviour change | Update docs |
| Before commit / PR | Pre-commit + PR checklists |
| Auth / migrations / try-on spend | Human review |

Task profiles: [../instructions/](../instructions/)

---

## Architecture (never break)

| Package | Owns |
|---------|------|
| `api/` | HTTP API, SQL, AI pipeline, ARQ workers, try-on job orchestration |
| `app/` | Mobile UX |
| `admin/` | Ops UI |
| `infra/` | Compose, Nginx, Redis, RunPod worker image |

- [ ] User isolation via Firebase JWT + `user_id` in SQL
- [ ] Monolith API — no new services without ask
- [ ] AI / try-on via service layer + Settings env
- [ ] No live secrets in git
- [ ] IDM-VTON license (NC) respected in product claims

---

## Before you write code

- [ ] Search existing routes / services / queries / widgets
- [ ] Pick a profile in [../instructions/](../instructions/)
- [ ] One logical feature per branch
- [ ] Know which package owns the change

---

## Per-layer checklist

### API route

- [ ] Auth dependency (or explicit public/demo/admin intent)
- [ ] Pydantic request/response models
- [ ] Ownership checks in queries
- [ ] Sensible status codes; no stack traces in body

### Service

- [ ] Pure(ish) business logic; routes stay thin
- [ ] Timeouts on outbound HTTP
- [ ] Spend / rate limits respected where Settings define them

### SQL / migrations

- [ ] Parameterized queries
- [ ] Indexes considered for new filters
- [ ] Migration + rollback note

### Flutter screen

- [ ] Uses theme tokens
- [ ] Loading / empty / error states
- [ ] Riverpod providers colocated under feature

### Try-on

- [ ] Goes through job/provider pipeline
- [ ] Fallback / composite behaviour understood
- [ ] Timeouts match cold-start reality for RunPod

---

## Pre-commit checklist

- [ ] No `.env` / keys staged
- [ ] No emoji added to UI/logs
- [ ] Focused tests pass for the change
- [ ] Formatting / analyzer clean on touched files

---

## PR merge checklist

- [ ] Purpose clear; screenshots for UI
- [ ] Docs updated if API or ops changed
- [ ] Linked related issue (if any)
- [ ] Human review for auth / migrations / commercial claim about try-on

---

## Documentation after code changes

| Change | Update |
|--------|--------|
| New/changed endpoint | `docs/backend/api_reference.md` |
| Schema | `docs/backend/database_schema.md` + migration files |
| Try-on / RunPod | `docs/services/TRYON-WORKER.md`, `docs/ops/SESSION-LESSONS.md` |
| New env var | `docs/local-development/ENV-VARS.md`, `.env.example` |
| Flutter UX contract | `docs/frontend/ui_ux_spec.md` if behaviour is user-visible |
