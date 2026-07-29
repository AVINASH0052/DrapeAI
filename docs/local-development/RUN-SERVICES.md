# Run services locally

## API

```bash
cd api
source .venv/bin/activate   # or your env manager
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

ARQ worker (if not started by the same process in your setup):

```bash
cd api && arq app.workers.settings.WorkerSettings
```

(Adjust module path if the project’s worker entry differs — check `api/app/workers/`.)

## Postgres / Redis

Prefer `infra/docker-compose.dev.yml` (or the compose file listed in root README).

## Flutter

```bash
cd app
flutter pub get
flutter run
```

Point the app at `http://localhost:8000` (or your LAN IP on a physical device).

## Admin

```bash
cd admin
npm install
npm run dev
```

## Health checks

- API: `GET /health` (or the health route registered in `api/app/routes/health.py`)
- Swagger: `http://localhost:8000/docs` when debug/docs enabled

## Tests

```bash
cd api && pytest
cd app && flutter test
```
