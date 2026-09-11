#!/usr/bin/env bash
# Expose local FastAPI (localhost:8000) via ngrok and point api.sugatai.com at it.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

curl -sf http://127.0.0.1:8000/health >/dev/null || {
  echo "Local API not healthy on :8000. Start it first:"
  echo "  docker compose -f infra/docker-compose.dev.yml up -d"
  exit 1
}

pkill -f 'ngrok http' 2>/dev/null || true
sleep 1
nohup ngrok http 8000 --log=stdout > /tmp/sugatai-ngrok.log 2>&1 &
echo $! > /tmp/sugatai-ngrok.pid

for i in $(seq 1 20); do
  if curl -sf http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

NGROK_URL="$(python3 - <<'PY'
import json, urllib.request
d = json.load(urllib.request.urlopen("http://127.0.0.1:4040/api/tunnels"))
urls = [t["public_url"] for t in d.get("tunnels", []) if t.get("public_url", "").startswith("https://")]
if not urls:
    raise SystemExit("ngrok HTTPS URL not ready")
print(urls[0])
PY
)"

echo "ngrok: $NGROK_URL"

cat > api-edge/wrangler.jsonc <<EOF
{
  "name": "sugatai-api",
  "main": "src/worker.ts",
  "compatibility_date": "2026-07-29",
  "workers_dev": true,
  "vars": { "ORIGIN": "$NGROK_URL" },
  "routes": [{ "pattern": "api.sugatai.com", "custom_domain": true }]
}
EOF

(cd api-edge && npx wrangler deploy)

echo "Ready: https://api.sugatai.com/health"
echo "Admin: https://app.sugatai.com/workadmin/"
echo "Keep this machine awake; ngrok must stay running (pid $(cat /tmp/sugatai-ngrok.pid))."
