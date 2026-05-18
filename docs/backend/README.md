# DrapeAI Backend -- Documentation Index

> FastAPI (Python 3.11) + PostgreSQL + pgvector + GPT-4o + Cloudflare R2

---

## Build Order

Follow this exact sequence. Each phase depends on the previous one.

| Phase | What to Build | Guide Section |
|---|---|---|
| 1 | Project scaffold + config + database connection | [implementation_guide.md#phase-1](implementation_guide.md#phase-1--project-scaffold) |
| 2 | Auth (Firebase JWT verification + user provisioning) | [implementation_guide.md#phase-2](implementation_guide.md#phase-2--authentication) |
| 3 | User profile + preferences (onboarding quiz) | [implementation_guide.md#phase-3](implementation_guide.md#phase-3--user-profile--preferences) |
| 4 | Storage layer (R2 upload/download + local dev fallback) | [implementation_guide.md#phase-4](implementation_guide.md#phase-4--storage-layer) |
| 5 | Items CRUD + image validation | [implementation_guide.md#phase-5](implementation_guide.md#phase-5--items-crud) |
| 6 | AI pipeline: background removal + vision tagging + embedding | [implementation_guide.md#phase-6](implementation_guide.md#phase-6--ai-upload-pipeline) |
| 7 | Rule engine (outfit candidate generation) | [implementation_guide.md#phase-7](implementation_guide.md#phase-7--rule-engine) |
| 8 | LLM ranker (outfit selection + explanations) | [implementation_guide.md#phase-8](implementation_guide.md#phase-8--llm-ranker) |
| 9 | Outfit endpoints + shuffle + feedback + caching | [implementation_guide.md#phase-9](implementation_guide.md#phase-9--outfit-endpoints) |
| 10 | Lookbooks CRUD | [implementation_guide.md#phase-10](implementation_guide.md#phase-10--lookbooks) |
| 11 | Demo wardrobe seeder | [implementation_guide.md#phase-11](implementation_guide.md#phase-11--demo-wardrobe) |
| 12 | Push notifications (FCM) | [implementation_guide.md#phase-12](implementation_guide.md#phase-12--push-notifications) |
| 13 | Testing + error monitoring | [implementation_guide.md#phase-13](implementation_guide.md#phase-13--testing) |

---

## Reference Documents

| Document | Purpose |
|---|---|
| [implementation_guide.md](implementation_guide.md) | Step-by-step HOW to build every module, file by file, with code |
| [coding_standards.md](coding_standards.md) | Python/FastAPI rules: security, async, error handling, naming |
| [database_schema.md](database_schema.md) | Full PostgreSQL DDL: all tables, indexes, migrations |
| [api_reference.md](api_reference.md) | Every endpoint: request/response shapes, validation, errors |
| [ai_pipeline.md](ai_pipeline.md) | Vision tagging, rule engine, LLM ranker, prompt templates, cost control |

---

## Quick Reference

```bash
# Run locally
cd api && source .venv/bin/activate
uvicorn app.main:app --reload --port 8000

# Run tests
pytest -v

# Run migrations
python -c "import asyncio; from app.database.migrations import run_migrations; asyncio.run(run_migrations())"

# Swagger docs
open http://localhost:8000/docs
```
