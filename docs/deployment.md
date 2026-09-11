# Deployment cheat sheet

> **Last updated:** 2026-09-11  
> Long form: [deployment.md](deployment.md) · Store: [store_submission.md](store_submission.md)

## CI

- `.github/workflows/ci.yml` — API pytest (Postgres + Redis), web build, admin build, `flutter analyze` + `flutter test`.
- `.github/workflows/deploy.yml` — manual deploy of a **tested SHA or tag**. It refuses to ship a commit that has no successful CI run, checks out that SHA on the server (not `git pull main`), and waits on `/ready`.

## Containers

| Unit | Context |
|---|---|
| API image | `api/Dockerfile` |
| Compose / Swarm | `infra/docker-compose.*.yml` |
| Nginx | `infra/nginx/` |
| Try-on worker | `infra/runpod/idm-vton-worker/` → Docker Hub → RunPod template |

## Prod checklist

- [ ] Secrets injected (not baked into images)
- [ ] Migrations applied
- [ ] Redis + Postgres healthy
- [ ] R2 + Firebase configured
- [ ] Try-on providers keyed; RunPod optional
- [ ] TLS via Nginx / edge
- [ ] `/health` (liveness) and `/ready` (Postgres, Redis, storage, providers) monitored
- [ ] R2 bucket private; API returns signed image URLs

## RunPod worker release

1. Build+push `YOURUSER/idm-vton-worker:vN` (`linux/amd64`)  
2. Update template `imageName`  
3. Drain workers (`workersMax: 0`) → re-enable  
4. Smoke `{"input":{"diag":true}}` then real try-on  

Details: [services/TRYON-WORKER.md](services/TRYON-WORKER.md)
