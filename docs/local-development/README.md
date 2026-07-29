# Local development

**Last updated:** 2026-07-14

## Start here

1. [ENV-VARS.md](ENV-VARS.md) — required secrets  
2. [RUN-SERVICES.md](RUN-SERVICES.md) — bring stacks up  
3. [../environment_setup.md](../environment_setup.md) — machine tooling (Flutter, Xcode, Python, etc.)

## Quick path

```bash
# From repo root
cp api/.env.example api/.env   # fill keys
docker compose -f infra/docker-compose.dev.yml up -d   # if using compose

cd api && python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000

cd ../app && flutter pub get && flutter run
cd ../admin && npm install && npm run dev
```

See root [README.md](../../README.md) for the canonical quick start if compose filenames differ on your branch.

## Docs

| Topic | Link |
|---|---|
| Project layout | [../project_structure.md](../project_structure.md) |
| Backend build order | [../backend/README.md](../backend/README.md) |
| Frontend build order | [../frontend/README.md](../frontend/README.md) |
| Agent rules | [../rules/AGENTS.md](../rules/AGENTS.md) |
