# Sugatai landing page

Vite + React + TypeScript marketing site for `sugatai.com`.

## Deploy (Cloudflare Workers + assets)

The marketing site deploys as Worker `sugatai-web` with static assets and a
`/waitlist` API backed by KV. Custom domains: `sugatai.com`, `www.sugatai.com`.

```bash
cd web
npx wrangler login   # once
npm run deploy       # build + wrangler deploy
```

Local waitlist still proxies to FastAPI via Vite (`vite.config.ts`). On
production, the Worker handles `/waitlist`.
