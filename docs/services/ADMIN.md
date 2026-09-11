# Admin (`admin/`)

Vite + React ops console for Sugatai at `/workadmin`.

## Local

```bash
cd admin
npm install
cp .env.example .env   # optional Firebase web config
npm run dev            # http://localhost:5174/workadmin/
```

API calls proxy to `http://localhost:8000` via Vite (`/admin/*` and `/uploads/*`).
The production Worker proxies the same paths to `API_ORIGIN` so wardrobe thumbnails resolve.

In development without `VITE_FIREBASE_*`, any email/password signs in with the API `test-token`. The user must have `is_admin = true` in Postgres for data routes to succeed.

Production builds load Firebase from `admin/.env.production` (Vite). Rebuild after changing those vars:

```bash
cd admin && npm run build && npx wrangler deploy
```

Promote an admin Firebase user:

```sql
UPDATE users SET is_admin = true WHERE email = 'you@example.com';
```

## Production

Deployed as Cloudflare Worker `sugatai-admin`:

- URL: https://app.sugatai.com/workadmin/
- Proxies `/admin/*` to `API_ORIGIN` (default `https://api.sugatai.com`)

```bash
cd admin
npm run deploy
```

### Why dashboard shows API unreachable / HTTP 530

`app.sugatai.com` is only the admin UI Worker. Data requires a live FastAPI origin at `https://api.sugatai.com`.

**Permanent (Cloudflare named Tunnel — preferred):**

Named tunnel `sugatai-api` (`00bc5c5e-6195-4a3d-a014-b92c08e06845`) is configured with ingress `api.sugatai.com` → `http://127.0.0.1:8000`. On this Mac the connector runs as LaunchAgent `com.sugatai.cloudflared`.

```bash
# Keep API + DB up
docker compose -f infra/docker-compose.dev.yml up -d

# Install / restart the tunnel connector (uses TUNNEL_TOKEN or saved token file)
./scripts/setup-cloudflare-tunnel.sh
```

One-time DNS (zone DNS edit required — wrangler OAuth is zone-read only):

| Type | Name | Target | Proxy |
|------|------|--------|-------|
| CNAME | `api` | `00bc5c5e-6195-4a3d-a014-b92c08e06845.cfargotunnel.com` | Proxied |

Dashboard: Cloudflare → sugatai.com → DNS, or Zero Trust → Networks → Tunnels → sugatai-api → Public Hostname.

Do **not** attach Worker `sugatai-api` as a custom domain on `api.sugatai.com` (that overrides the tunnel CNAME).

Verify: `curl -sS https://api.sugatai.com/health`

True always-on requires the same tunnel connector + FastAPI/Postgres on a VPS (Mac sleep still takes the API offline).

**Temporary local bridge (ngrok):**

```bash
docker compose -f infra/docker-compose.dev.yml up -d
./scripts/expose-api.sh   # points temporary edge Worker ORIGIN at ngrok
```

Promote an admin:

```sql
UPDATE users SET is_admin = true WHERE email = 'you@example.com';
```

Apply migration `api/db/migrations/0016_admin_enterprise.sql` for admin notes, item flagging, and audit log.

## Console surface

| Section | Pages |
|---|---|
| Overview | Dashboard KPIs + trends |
| Users | All users (filters), user detail tabs, waitlist |
| Content | Items browser, flagged moderation |
| Insights | Analytics (cost, usage, top users) |
| Operations | Push compose, system health |

### User detail tabs

Overview · Wardrobe · Outfits · Lookbooks · Avatar & Try-on · Activity · Support (notes, grant/revoke admin, reset onboarding, suspend, delete)

## Auth

- Bearer Firebase ID token (same as mobile) + `users.is_admin`
- Dev: `test-token` maps to `test-user-001` (promote with SQL above)

## Rules

- Use the admin API in `admin/src/services/`
- Do not embed production secrets in the frontend bundle
- Prefer Recharts already in the project

See also [../ADMIN_PLATFORM_PROMPT.md](../ADMIN_PLATFORM_PROMPT.md) for product intent.
