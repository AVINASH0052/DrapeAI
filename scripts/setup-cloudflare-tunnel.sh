#!/usr/bin/env bash
# Install / refresh the named Cloudflare Tunnel for api.sugatai.com.
# Requires: cloudflared, local API on :8000, TUNNEL_TOKEN (or token file).
set -euo pipefail

TOKEN_DIR="${HOME}/Library/Application Support/sugatai"
TOKEN_FILE="${TOKEN_DIR}/tunnel.token"
PLIST="${HOME}/Library/LaunchAgents/com.sugatai.cloudflared.plist"
TUNNEL_ID="00bc5c5e-6195-4a3d-a014-b92c08e06845"
HOSTNAME="api.sugatai.com"

mkdir -p "$TOKEN_DIR"
umask 077

if [[ -n "${TUNNEL_TOKEN:-}" ]]; then
  printf '%s' "$TUNNEL_TOKEN" > "$TOKEN_FILE"
  echo "Wrote $TOKEN_FILE"
elif [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Set TUNNEL_TOKEN or create $TOKEN_FILE"
  echo "Token: Zero Trust → Networks → Tunnels → sugatai-api → Configure → copy token"
  exit 1
fi

curl -sf "http://127.0.0.1:8000/health" >/dev/null || {
  echo "Local API not healthy on :8000. Start:"
  echo "  docker compose -f infra/docker-compose.dev.yml up -d"
  exit 1
}

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.sugatai.cloudflared</string>
  <key>ProgramArguments</key>
  <array>
    <string>/opt/homebrew/bin/cloudflared</string>
    <string>tunnel</string>
    <string>--no-autoupdate</string>
    <string>run</string>
    <string>--token-file</string>
    <string>${TOKEN_FILE}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${HOME}/Library/Logs/sugatai-cloudflared.log</string>
  <key>StandardErrorPath</key>
  <string>${HOME}/Library/Logs/sugatai-cloudflared.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.sugatai.cloudflared" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/com.sugatai.cloudflared" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/com.sugatai.cloudflared"

echo "Connector running (launchd com.sugatai.cloudflared)."
echo
echo "DNS (required once): in Cloudflare → sugatai.com → DNS, add:"
echo "  Type   CNAME"
echo "  Name   api"
echo "  Target ${TUNNEL_ID}.cfargotunnel.com"
echo "  Proxy  Proxied (orange cloud)"
echo
if [[ -f "${HOME}/.cloudflared/cert.pem" ]]; then
  echo "cert.pem present — attempting DNS route via cloudflared..."
  cloudflared tunnel route dns sugatai-api "$HOSTNAME" || true
fi

echo "Verify: curl -sS https://${HOSTNAME}/health"
