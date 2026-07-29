# Admin (`admin/`)

Vite + React ops dashboard.

## Typical pages

Dashboard, Users, System health, Login — under `admin/src/pages/`.

## Rules

- Use the admin API + auth already in `admin/src/services/`
- Do not embed production secrets in the frontend bundle
- Prefer charts/libs already in the project (e.g. Recharts)

See also [../ADMIN_PLATFORM_PROMPT.md](../ADMIN_PLATFORM_PROMPT.md) for product intent.
