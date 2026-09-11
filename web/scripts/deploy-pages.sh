#!/usr/bin/env bash
# Deploy Sugatai landing page to Cloudflare Pages.
set -euo pipefail
cd "$(dirname "$0")"

if ! npx wrangler whoami >/dev/null 2>&1; then
  echo "Not logged in to Cloudflare."
  echo "Run:  npx wrangler login"
  echo "Or export CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID."
  exit 1
fi

npm run build

PROJECT="${CF_PAGES_PROJECT:-sugatai}"

# Create project if missing (ignore error if it already exists).
npx wrangler pages project create "$PROJECT" --production-branch=main >/dev/null 2>&1 || true

# Ensure KV namespace for waitlist, then bind if wrangler.toml has a placeholder.
KV_NAME="sugatai-waitlist"
KV_LIST="$(npx wrangler kv namespace list 2>/dev/null || true)"
if ! echo "$KV_LIST" | grep -q "$KV_NAME"; then
  echo "Creating KV namespace $KV_NAME…"
  npx wrangler kv namespace create "$KV_NAME"
fi

KV_ID="$(npx wrangler kv namespace list | python3 -c '
import json,sys
data=json.load(sys.stdin)
name="'"$KV_NAME"'"
for row in data:
    if row.get("title")==name or row.get("title")==f"sugatai-{name}":
        print(row["id"]); break
' 2>/dev/null || true)"

# Fallback parse: wrangler list JSON titles are often exact name
if [[ -z "${KV_ID}" ]]; then
  KV_ID="$(npx wrangler kv namespace list | python3 -c '
import json,sys
data=json.load(sys.stdin)
for row in data:
    title=row.get("title","")
    if "waitlist" in title.lower() and "sugatai" in title.lower():
        print(row["id"]); break
' 2>/dev/null || true)"
fi

if [[ -n "${KV_ID}" ]]; then
  cat > wrangler.toml <<EOF
# Sugatai marketing site → Cloudflare Pages
name = "sugatai"
compatibility_date = "2026-01-01"
pages_build_output_dir = "dist"

[[kv_namespaces]]
binding = "WAITLIST"
id = "${KV_ID}"
EOF
  echo "Bound WAITLIST KV → ${KV_ID}"
fi

echo "Deploying to Cloudflare Pages project: ${PROJECT}"
npx wrangler pages deploy dist --project-name="$PROJECT" --commit-dirty=true
