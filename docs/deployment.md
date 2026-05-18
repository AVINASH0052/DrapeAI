# DrapeAI -- Deployment Guide

From local dev machine to production server to users downloading from the store. Every step.

---

## Table of Contents

- [1. Production Infrastructure](#1-production-infrastructure)
- [2. Domain and DNS](#2-domain-and-dns)
- [3. Hetzner VPS Setup](#3-hetzner-vps-setup)
- [4. Docker Compose Production](#4-docker-compose-production)
- [5. Nginx + TLS Configuration](#5-nginx--tls-configuration)
- [6. Cloudflare R2 Setup](#6-cloudflare-r2-setup)
- [7. Firebase Setup](#7-firebase-setup)
- [8. CI/CD Pipeline](#8-cicd-pipeline)
- [9. Database Backup](#9-database-backup)
- [10. Monitoring and Alerting](#10-monitoring-and-alerting)
- [11. Scaling Playbook](#11-scaling-playbook)
- [12. Rollback Procedure](#12-rollback-procedure)
- [13. Environment Variables (Complete)](#13-environment-variables-complete)

---

## 1. Production Infrastructure

```
Total monthly cost at launch (~100 users):

Hetzner CX22 VPS          EUR 4.50     (~Rs 420)
Cloudflare R2              Free tier    (~Rs 0)
Domain (drapeai.app)       ~Rs 800/yr   (~Rs 67/mo)
OpenAI API                              (~Rs 3,000)
Firebase Auth + FCM        Free tier    (~Rs 0)
-----------------------------------------------
Total:                                  ~Rs 3,500/mo
```

---

## 2. Domain and DNS

### Purchase domain

Buy `drapeai.app` (or similar) from Cloudflare Registrar, Google Domains, or Namecheap.

### DNS records (Cloudflare DNS, free)

```
Type    Name              Content           Proxy
A       api               <hetzner_ip>      DNS only (grey cloud)
A       @                 <hetzner_ip>      DNS only
CNAME   images            <r2_custom_domain> Proxied (orange cloud)
CNAME   www               drapeai.app       Proxied
```

Note: `api` subdomain must be DNS-only (grey cloud) so that the TLS certificate is handled by your Nginx + Let's Encrypt, not Cloudflare. Otherwise you get SSL mismatch errors.

---

## 3. Hetzner VPS Setup

### Order server

1. Go to https://www.hetzner.com/cloud
2. Create project "DrapeAI"
3. Order CX22: 2 vCPU, 4 GB RAM, 40 GB SSD, Ubuntu 24.04
4. Add SSH key during creation

### Initial server setup

```bash
# SSH in
ssh root@<hetzner_ip>

# Update system
apt update && apt upgrade -y

# Create app user (never run as root in production)
adduser drapeai --disabled-password
usermod -aG sudo drapeai
mkdir -p /home/drapeai/.ssh
cp /root/.ssh/authorized_keys /home/drapeai/.ssh/
chown -R drapeai:drapeai /home/drapeai/.ssh

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker drapeai

# Install Docker Compose plugin
apt install docker-compose-plugin -y

# Install certbot for TLS
apt install certbot python3-certbot-nginx -y

# Firewall
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# Reboot
reboot
```

### Deploy directory structure

```bash
# As drapeai user
su - drapeai
mkdir -p /home/drapeai/app
mkdir -p /home/drapeai/app/data/postgres
mkdir -p /home/drapeai/app/data/uploads
mkdir -p /home/drapeai/app/nginx
mkdir -p /home/drapeai/app/certbot
```

---

## 4. Docker Compose Production

File: `/home/drapeai/app/docker-compose.prod.yml`

```yaml
version: "3.9"

services:
  backend:
    build:
      context: ./api
      dockerfile: Dockerfile
    container_name: drapeai-backend
    restart: unless-stopped
    ports:
      - "127.0.0.1:8000:8000"
    environment:
      - ENVIRONMENT=production
      - DATABASE_URL=postgresql://drapeai:${DB_PASSWORD}@postgres:5432/drapeai
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - OPENAI_SPEND_CAP=${OPENAI_SPEND_CAP}
      - R2_ACCOUNT_ID=${R2_ACCOUNT_ID}
      - R2_ACCESS_KEY_ID=${R2_ACCESS_KEY_ID}
      - R2_SECRET_ACCESS_KEY=${R2_SECRET_ACCESS_KEY}
      - R2_BUCKET_NAME=${R2_BUCKET_NAME}
      - R2_PUBLIC_URL=${R2_PUBLIC_URL}
      - FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID}
      - OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
      - LOG_LEVEL=INFO
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - uploads:/app/uploads
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  postgres:
    image: pgvector/pgvector:pg16
    container_name: drapeai-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: drapeai
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: drapeai
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./api/db/init.sql:/docker-entrypoint-initdb.d/01-init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U drapeai"]
      interval: 10s
      timeout: 5s
      retries: 5

  nginx:
    image: nginx:alpine
    container_name: drapeai-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certbot/conf:/etc/letsencrypt:ro
      - ./certbot/www:/var/www/certbot:ro
    depends_on:
      - backend

volumes:
  pgdata:
    driver: local
  uploads:
    driver: local
```

### Backend Dockerfile

File: `api/Dockerfile`

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system deps for rembg and Pillow
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1-mesa-glx libglib2.0-0 curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download rembg model (avoid download at runtime)
RUN python -c "from rembg import new_session; new_session('u2net')"

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
```

---

## 5. Nginx + TLS Configuration

File: `nginx/nginx.conf`

```nginx
events {
    worker_connections 1024;
}

http {
    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;

    # Redirect HTTP to HTTPS
    server {
        listen 80;
        server_name api.drapeai.app;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name api.drapeai.app;

        ssl_certificate /etc/letsencrypt/live/api.drapeai.app/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/api.drapeai.app/privkey.pem;

        # Security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

        # Request size limit (10MB for image uploads)
        client_max_body_size 10m;

        # Proxy to FastAPI
        location / {
            limit_req zone=api burst=20 nodelay;

            proxy_pass http://backend:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Timeouts for long AI operations
            proxy_read_timeout 120s;
            proxy_send_timeout 120s;
        }
    }
}
```

### Obtain TLS certificate

```bash
# First time: get certificate from Let's Encrypt
# (Temporarily stop nginx or use webroot mode)
sudo certbot certonly --standalone -d api.drapeai.app --email you@email.com --agree-tos

# Copy certs to the mounted volume
sudo cp -rL /etc/letsencrypt/live/api.drapeai.app /home/drapeai/app/certbot/conf/live/
sudo cp -rL /etc/letsencrypt/archive/api.drapeai.app /home/drapeai/app/certbot/conf/archive/

# Auto-renewal cron (runs as root)
echo "0 3 * * * certbot renew --quiet && docker restart drapeai-nginx" | sudo tee /etc/cron.d/certbot-renew
```

---

## 6. Cloudflare R2 Setup

### Create bucket

1. Log in to Cloudflare dashboard
2. Go to R2 Object Storage
3. Create bucket: `drapeai-images`
4. Region: Auto (or APAC if available)

### Create API token

1. R2 > Manage R2 API Tokens > Create API token
2. Permissions: Object Read & Write
3. Scope: Specific bucket > drapeai-images
4. Save the Access Key ID and Secret Access Key

### Configure custom domain (optional)

1. R2 bucket settings > Custom Domains
2. Add `images.drapeai.app`
3. Cloudflare auto-creates DNS CNAME

### Backend configuration

```env
R2_ACCOUNT_ID=your_account_id
R2_ACCESS_KEY_ID=your_key_id
R2_SECRET_ACCESS_KEY=your_secret
R2_BUCKET_NAME=drapeai-images
R2_PUBLIC_URL=https://images.drapeai.app
```

### R2 bucket structure

```
drapeai-images/
  demo/                    # demo wardrobe images (shared)
    item_001.png
    item_002.png
    ...
  users/
    {user_id}/
      items/
        {item_id}.png      # full size, bg removed
        {item_id}_thumb.png # 200x200 thumbnail
      avatar.png           # profile photo (optional)
```

---

## 7. Firebase Setup

### Create project

1. Go to https://console.firebase.google.com
2. Create project: "DrapeAI"
3. Enable Authentication:
   - Sign-in methods: Phone, Google
   - Add authorized domains: `drapeai.app`, `api.drapeai.app`

### Flutter configuration

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure (run from app/ directory)
flutterfire configure --project=drapeai-firebase
```

This generates:
- `app/lib/firebase_options.dart`
- `app/android/app/google-services.json`
- `app/ios/Runner/GoogleService-Info.plist`

### Cloud Messaging setup

1. Firebase Console > Cloud Messaging
2. Generate VAPID key (for web, not needed for mobile)
3. For iOS: upload APNs key (from Apple Developer account)
   - Apple Developer > Keys > Create key with APNs enabled
   - Upload .p8 file to Firebase

### Backend JWT verification

The backend verifies Firebase JWTs using Google's public keys:

```python
import httpx
from jose import jwt

FIREBASE_PUBLIC_KEYS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
_cached_keys = {}
_keys_fetched_at = 0

async def verify_firebase_token(token: str) -> dict:
    global _cached_keys, _keys_fetched_at

    # Refresh keys every hour
    if time.time() - _keys_fetched_at > 3600:
        async with httpx.AsyncClient() as client:
            resp = await client.get(FIREBASE_PUBLIC_KEYS_URL)
            _cached_keys = resp.json()
            _keys_fetched_at = time.time()

    # Decode JWT
    header = jwt.get_unverified_header(token)
    key = _cached_keys.get(header["kid"])
    if not key:
        raise HTTPException(status_code=401, detail="Invalid token")

    payload = jwt.decode(
        token, key, algorithms=["RS256"],
        audience=FIREBASE_PROJECT_ID,
        issuer=f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}",
    )
    return payload  # contains "sub" (user_id), "phone_number", "email"
```

---

## 8. CI/CD Pipeline

### GitHub Actions workflow

File: `.github/workflows/deploy.yml`

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
    paths:
      - 'api/**'
      - 'docker-compose.prod.yml'
      - 'nginx/**'

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to Hetzner
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.HETZNER_IP }}
          username: drapeai
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            cd /home/drapeai/app
            git pull origin main
            docker compose -f docker-compose.prod.yml build backend
            docker compose -f docker-compose.prod.yml up -d backend
            docker compose -f docker-compose.prod.yml exec -T backend python -c "
            import asyncio
            from app.database.migrations import run_migrations
            asyncio.run(run_migrations())
            " || true
            echo "Deploy complete at $(date)"

      - name: Health check
        run: |
          sleep 10
          curl -f https://api.drapeai.app/health || exit 1
```

### GitHub secrets to configure

```
HETZNER_IP          -- VPS IP address
SSH_PRIVATE_KEY     -- SSH key for drapeai user
```

### Flutter build + deploy (manual for now, automate later)

```bash
# Android APK
cd app
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
# Then open in Xcode for archive + upload (see store_submission.md)
```

---

## 9. Database Backup

### Automated daily backup

```bash
# /home/drapeai/scripts/backup.sh
#!/bin/bash
set -e

BACKUP_DIR="/home/drapeai/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/drapeai_$TIMESTAMP.sql.gz"

mkdir -p "$BACKUP_DIR"

# Dump and compress
docker exec drapeai-postgres pg_dump -U drapeai drapeai | gzip > "$BACKUP_FILE"

# Upload to R2 (using rclone or aws cli)
aws s3 cp "$BACKUP_FILE" "s3://drapeai-backups/db/$TIMESTAMP.sql.gz" \
  --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

# Keep only last 7 local backups
ls -t "$BACKUP_DIR"/drapeai_*.sql.gz | tail -n +8 | xargs rm -f

echo "Backup completed: $BACKUP_FILE"
```

### Cron schedule

```bash
# Run daily at 2 AM
echo "0 2 * * * /home/drapeai/scripts/backup.sh >> /home/drapeai/logs/backup.log 2>&1" | crontab -
```

### Restore procedure

```bash
# Download backup
aws s3 cp "s3://drapeai-backups/db/20260420_020000.sql.gz" ./restore.sql.gz \
  --endpoint-url "https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

# Stop backend
docker compose -f docker-compose.prod.yml stop backend

# Restore
gunzip -c restore.sql.gz | docker exec -i drapeai-postgres psql -U drapeai -d drapeai

# Restart backend
docker compose -f docker-compose.prod.yml start backend
```

---

## 10. Monitoring and Alerting

### Health check endpoint

`GET /health` returns:
```json
{
  "status": "ok",
  "version": "1.0.0",
  "db": "connected",
  "uptime_seconds": 86400
}
```

### UptimeRobot (free)

1. Create account at https://uptimerobot.com
2. Add monitor: HTTPS, `https://api.drapeai.app/health`, interval: 5 min
3. Alert contacts: your email + Telegram bot

### Sentry (error tracking)

```bash
pip install sentry-sdk[fastapi]
```

```python
# In app/main.py
import sentry_sdk
sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    environment=os.getenv("ENVIRONMENT", "development"),
    traces_sample_rate=0.1,
)
```

Flutter:
```yaml
# pubspec.yaml
dependencies:
  sentry_flutter: ^8.0.0
```

### Log aggregation

```bash
# View backend logs
docker compose -f docker-compose.prod.yml logs -f backend --tail=100

# View all logs
docker compose -f docker-compose.prod.yml logs -f --tail=200
```

For production: consider forwarding logs to Grafana Cloud (free tier: 50 GB/month) via `promtail`.

### Key metrics to track

| Metric | How | Alert threshold |
|---|---|---|
| API response time (p95) | Sentry performance | > 3 seconds |
| Error rate | Sentry | > 5% of requests |
| Disk usage | `df -h` cron check | > 80% |
| Memory usage | `docker stats` | > 90% |
| DB connections | `pg_stat_activity` count | > 80 |
| OpenAI daily spend | Custom tracking table | > daily budget |
| Upload success rate | Application logs | < 90% |

---

## 11. Scaling Playbook

### When Hetzner CX22 is not enough (signs)

- API p95 latency consistently > 2 seconds
- CPU > 80% sustained
- Memory > 3.5 GB
- Vision tagging queue backing up

### Step 1: Vertical scale

Upgrade to CX32 (4 vCPU, 8 GB RAM). Takes 5 minutes in Hetzner console. No data loss.

```bash
# After resize, restart containers
docker compose -f docker-compose.prod.yml up -d

# Increase uvicorn workers
# In Dockerfile CMD, change --workers 2 to --workers 4
```

### Step 2: Separate database

Move PostgreSQL to managed service:

**Option A: Supabase** (free tier includes 500 MB, Pro at $25/mo)
- Create project, get connection string
- Update `DATABASE_URL` env var
- Remove postgres container from docker-compose

**Option B: Hetzner managed Postgres** (not yet available, use Supabase or Neon)

**Option C: Neon** (free tier includes 512 MB, Pro at $19/mo)

### Step 3: Async vision processing

If vision tagging becomes a bottleneck:

```python
# Instead of tagging synchronously in the upload endpoint,
# queue the job and return immediately

@router.post("/items/upload")
async def upload_item(image: UploadFile, user: User = Depends(get_current_user)):
    item_id = uuid4()
    # Store raw image
    await upload_image(user.id, item_id, await image.read())
    # Create item with status = "processing"
    await create_item(user.id, item_id, status="processing")
    # Queue tagging job
    await enqueue_vision_job(user.id, item_id)
    return {"id": item_id, "status": "processing"}

# Separate worker process picks up jobs
# In docker-compose: add a `worker` service running the same image with different CMD
```

---

## 12. Rollback Procedure

### Backend rollback

```bash
# SSH into server
ssh drapeai@<hetzner_ip>
cd /home/drapeai/app

# Check recent commits
git log --oneline -5

# Rollback to previous commit
git checkout <previous_commit_hash>

# Rebuild and restart
docker compose -f docker-compose.prod.yml build backend
docker compose -f docker-compose.prod.yml up -d backend

# Verify
curl https://api.drapeai.app/health
```

### Database rollback

If a migration broke something:

```bash
# Restore from last backup (see section 9)
# Backups are taken daily; worst case = 24h data loss

# For minor issues: write a corrective migration instead of restoring
# api/db/migrations/005_fix_whatever.sql
```

---

## 13. Environment Variables (Complete)

```env
# ── Server ───────────────────────────────────────
ENVIRONMENT=production
LOG_LEVEL=INFO
API_PORT=8000

# ── Database ─────────────────────────────────────
DATABASE_URL=postgresql://drapeai:${DB_PASSWORD}@postgres:5432/drapeai
DB_PASSWORD=<strong-random-password>
DB_POOL_MIN=2
DB_POOL_MAX=10

# ── OpenAI ───────────────────────────────────────
OPENAI_API_KEY=sk-...
OPENAI_SPEND_CAP=20

# ── Cloudflare R2 ────────────────────────────────
R2_ACCOUNT_ID=<cloudflare_account_id>
R2_ACCESS_KEY_ID=<r2_key>
R2_SECRET_ACCESS_KEY=<r2_secret>
R2_BUCKET_NAME=drapeai-images
R2_PUBLIC_URL=https://images.drapeai.app

# ── Firebase ─────────────────────────────────────
FIREBASE_PROJECT_ID=drapeai-firebase

# ── Weather ──────────────────────────────────────
OPENWEATHER_API_KEY=<key>

# ── Monitoring ───────────────────────────────────
SENTRY_DSN=https://...@sentry.io/...

# ── Secrets (never commit) ───────────────────────
# All above values with <...> are injected via:
# - GitHub Actions secrets (for CI/CD)
# - /home/drapeai/app/.env file on server (for docker-compose)
```

### .env file on server

```bash
# Create with restricted permissions
touch /home/drapeai/app/.env
chmod 600 /home/drapeai/app/.env

# Edit
nano /home/drapeai/app/.env
# Paste all env vars above with real values

# Docker compose reads it automatically
docker compose -f docker-compose.prod.yml --env-file .env up -d
```

Never commit `.env` to git. `.gitignore` must include:
```
.env
*.env
.env.*
```
