# Backend (`api/`)

Python 3.11 + FastAPI monolith.

## Layout

| Path | Role |
|---|---|
| `app/routes/` | HTTP routers |
| `app/services/` | Business logic + AI + storage + try-on |
| `app/database/` | Pool + SQL query modules |
| `app/models/` | Pydantic schemas |
| `app/auth/` | Firebase JWT + admin guards |
| `app/middleware/` | Rate limit, security headers |
| `app/workers/` | ARQ tasks / cron |
| `db/` | `init.sql`, migrations, Alembic |
| `tests/` | pytest-asyncio |

## Deep dives

- [../backend/README.md](../backend/README.md)
- [../backend/api_reference.md](../backend/api_reference.md)
- [../backend/ai_pipeline.md](../backend/ai_pipeline.md)
- [../backend/database_schema.md](../backend/database_schema.md)
- [../backend/coding_standards.md](../backend/coding_standards.md)

## Invariants

User ownership in SQL · async I/O · Settings-driven providers · no secrets in repo.
