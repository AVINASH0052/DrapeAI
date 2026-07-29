# Profile: API generation

Use when adding or changing FastAPI routes / services.

## Do

1. Put routers in `api/app/routes/`; register in `main.py` / router `__init__`.
2. Keep handlers thin — business logic in `app/services/`.
3. Use Pydantic models in `app/models/`.
4. SQL in `app/database/queries/` with `$1…` params + `user_id` ownership.
5. Auth: `Depends(get_current_user)` (or explicit public/admin dependency).
6. Outbound HTTP via `httpx` async; honor Settings timeouts and spend caps.
7. Update [../backend/api_reference.md](../backend/api_reference.md) when the public contract changes.

## Don’t

- Trust client-supplied `user_id` for authorization
- Call OpenAI/RunPod directly from a route if a service wrapper exists
- Return raw exception strings to clients
