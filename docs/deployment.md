# Deployment cheat sheet

> **Last updated:** 2026-07-14  
> Long form: [deployment.md](deployment.md) · Store: [store_submission.md](store_submission.md)

## CI

GitHub Actions under `.github/workflows/` — tests + deploy as configured on the default branch.

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
- [ ] Health endpoint monitored

## RunPod worker release

1. Build+push `YOURUSER/idm-vton-worker:vN` (`linux/amd64`)  
2. Update template `imageName`  
3. Drain workers (`workersMax: 0`) → re-enable  
4. Smoke `{"input":{"diag":true}}` then real try-on  

Details: [services/TRYON-WORKER.md](services/TRYON-WORKER.md)
