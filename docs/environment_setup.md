# Sugatai -- Environment Setup

Dev machine setup from zero to running the full stack locally. macOS-focused (your machine), with Linux notes where different.

---

## Table of Contents

- [1. Prerequisites](#1-prerequisites)
- [2. Flutter Setup](#2-flutter-setup)
- [3. iOS Setup (Xcode)](#3-ios-setup-xcode)
- [4. Android Setup](#4-android-setup)
- [5. Python Backend Setup](#5-python-backend-setup)
- [6. PostgreSQL + pgvector (Local)](#6-postgresql--pgvector-local)
- [7. External Services API Keys](#7-external-services-api-keys)
- [8. Running the Full Stack Locally](#8-running-the-full-stack-locally)
- [9. VS Code Configuration](#9-vs-code-configuration)
- [10. Troubleshooting](#10-troubleshooting)

---

## 1. Prerequisites

| Tool | Version | Install |
|---|---|---|
| macOS | 14+ (Sonoma) | Already installed |
| Homebrew | Latest | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| Git | 2.40+ | `brew install git` |
| VS Code | Latest | `brew install --cask visual-studio-code` |

Verify:
```bash
brew --version
git --version
code --version
```

---

## 2. Flutter Setup

### Install Flutter SDK

```bash
# Option A: Homebrew (recommended)
brew install --cask flutter

# Option B: Manual
# Download from https://docs.flutter.dev/get-started/install/macos
# Extract to ~/development/flutter
# Add to PATH in ~/.zshrc:
# export PATH="$HOME/development/flutter/bin:$PATH"
```

### Verify installation

```bash
flutter --version
# Should show: Flutter 3.24.x or later

flutter doctor
# Should show checkmarks for:
# [✓] Flutter
# [✓] Android toolchain
# [✓] Xcode
# [✓] Chrome (for web, optional)
# [✓] VS Code
```

### Accept licenses

```bash
flutter doctor --android-licenses
# Accept all with 'y'
```

---

## 3. iOS Setup (Xcode)

### Install Xcode

```bash
# Install from Mac App Store (takes ~30 min, ~12 GB)
# Or use:
xcode-select --install  # Command line tools only (not enough for iOS builds)
```

After Xcode installs:

```bash
# Accept license
sudo xcodebuild -license accept

# Install iOS simulator
open -a Simulator
# Or: Xcode > Settings > Platforms > Download iOS 17.x simulator
```

### CocoaPods

```bash
brew install cocoapods
# Or: sudo gem install cocoapods
pod --version
```

### Verify

```bash
flutter doctor
# [✓] Xcode - develop for iOS and macOS
```

---

## 4. Android Setup

### Install Android Studio

```bash
brew install --cask android-studio
```

Open Android Studio once to complete setup wizard:
1. Standard installation
2. Accept all SDK licenses
3. Wait for SDK components to download

### Or install SDK only (if you prefer VS Code)

```bash
brew install --cask android-commandlinetools
# Then use sdkmanager to install required packages
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
```

### Set environment variables

Add to `~/.zshrc`:

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/tools:$PATH"
```

```bash
source ~/.zshrc
```

### Verify

```bash
flutter doctor
# [✓] Android toolchain - develop for Android devices

# Test with emulator or physical device
flutter devices
```

---

## 5. Python Backend Setup

### Install Python 3.11

```bash
brew install python@3.11

# Verify
python3.11 --version
# Python 3.11.x
```

### Create virtual environment

```bash
cd api/

python3.11 -m venv .venv
source .venv/bin/activate

# Verify
which python
# Should show: /path/to/api/.venv/bin/python

python --version
# Python 3.11.x
```

### Install dependencies

```bash
pip install --upgrade pip
pip install -r requirements.txt

# This includes rembg which downloads ~170 MB model on first use.
# Pre-download:
python -c "from rembg import new_session; new_session('u2net')"
```

---

## 6. PostgreSQL + pgvector (Local)

### Option A: Docker (recommended)

```bash
# From project root
docker compose -f infra/docker-compose.dev.yml up -d
```

File: `infra/docker-compose.dev.yml`

```yaml
version: "3.9"
services:
  postgres:
    image: pgvector/pgvector:pg16
    container_name: drapeai-dev-postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: drapeai
      POSTGRES_PASSWORD: devpassword
      POSTGRES_DB: drapeai
    volumes:
      - pgdata_dev:/var/lib/postgresql/data
      - ../api/db/init.sql:/docker-entrypoint-initdb.d/01-init.sql
volumes:
  pgdata_dev:
```

### Option B: Native install

```bash
brew install postgresql@16
brew services start postgresql@16

# Install pgvector extension
brew install pgvector

# Create database
createdb drapeai
psql drapeai -c "CREATE EXTENSION vector;"
```

### Verify

```bash
psql postgresql://drapeai:devpassword@localhost:5432/drapeai -c "SELECT 1;"
# Should return: 1
```

---

## 7. External Services API Keys

Create `api/.env` for local development:

```env
# ── Server ───────────────────────────────────────
ENVIRONMENT=development
LOG_LEVEL=DEBUG
API_PORT=8000

# ── Database ─────────────────────────────────────
DATABASE_URL=postgresql://drapeai:devpassword@localhost:5432/drapeai

# ── OpenAI ───────────────────────────────────────
OPENAI_API_KEY=sk-...
OPENAI_SPEND_CAP=5

# ── Cloudflare R2 (use local storage in dev, or create a test bucket) ──
R2_ACCOUNT_ID=
R2_ACCESS_KEY_ID=
R2_SECRET_ACCESS_KEY=
R2_BUCKET_NAME=drapeai-dev
R2_PUBLIC_URL=http://localhost:8000/uploads

# ── Firebase ─────────────────────────────────────
FIREBASE_PROJECT_ID=drapeai-firebase

# Weather: Open-Meteo (no API key)
```

### Where to get each key

| Service | URL | Cost |
|---|---|---|
| OpenAI API | https://platform.openai.com/api-keys | Pay per use |
| Firebase | https://console.firebase.google.com | Free |
| Cloudflare R2 | https://dash.cloudflare.com > R2 | Free tier (10 GB) |
| Weather | Open-Meteo (built-in, no key) | Free |

---

## 8. Running the Full Stack Locally

### Terminal 1: Database

```bash
cd Sugatai
docker compose -f infra/docker-compose.dev.yml up
```

### Terminal 2: Backend

```bash
cd Sugatai/api
source .venv/bin/activate

# Run migrations
python -c "
import asyncio
from app.database.migrations import run_migrations
asyncio.run(run_migrations())
"

# Start server with hot reload
uvicorn app.main:app --reload --port 8000

# API now available at http://localhost:8000
# Docs at http://localhost:8000/docs (Swagger UI)
```

### Terminal 3: Flutter app

```bash
cd Sugatai/app

flutter pub get

# Run on iOS simulator
flutter run -d iphone

# Or run on Android emulator
flutter run -d android

# Or run on a connected physical device
flutter run
```

### Verify everything works

1. Open `http://localhost:8000/health` -- should return `{"status": "ok"}`
2. Open `http://localhost:8000/docs` -- Swagger UI should load
3. App should launch on simulator/emulator
4. Auth screen should appear

---

## 9. VS Code Configuration

### Required extensions

```bash
code --install-extension Dart-Code.dart-code
code --install-extension Dart-Code.flutter
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-azuretools.vscode-docker
code --install-extension bradlc.vscode-tailwindcss      # Not needed, just nice for HTML/CSS
code --install-extension esbenp.prettier-vscode
```

### `.vscode/settings.json` (workspace)

```json
{
  "[dart]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "Dart-Code.dart-code",
    "editor.rulers": [80]
  },
  "[python]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "ms-python.python",
    "editor.rulers": [88]
  },
  "python.defaultInterpreterPath": "./api/.venv/bin/python",
  "dart.lineLength": 80,
  "editor.tabSize": 2,
  "files.exclude": {
    "**/.DS_Store": true,
    "**/__pycache__": true,
    "**/node_modules": true
  }
}
```

### `.vscode/launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter: Debug",
      "type": "dart",
      "request": "launch",
      "program": "app/lib/main.dart"
    },
    {
      "name": "FastAPI: Debug",
      "type": "debugpy",
      "request": "launch",
      "module": "uvicorn",
      "args": ["app.main:app", "--reload", "--port", "8000"],
      "cwd": "${workspaceFolder}/api",
      "env": {
        "ENVIRONMENT": "development"
      }
    }
  ]
}
```

---

## 10. Troubleshooting

### `flutter doctor` shows issues

```bash
# Missing Android licenses
flutter doctor --android-licenses

# Missing Xcode command line tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# CocoaPods not found
brew install cocoapods
cd app/ios && pod install
```

### PostgreSQL connection refused

```bash
# Check if Docker container is running
docker ps | grep drapeai-dev-postgres

# Restart
docker compose -f infra/docker-compose.dev.yml down
docker compose -f infra/docker-compose.dev.yml up -d

# Check logs
docker logs drapeai-dev-postgres
```

### rembg model download fails

```bash
# Manual download
mkdir -p ~/.u2net
curl -L https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx \
  -o ~/.u2net/u2net.onnx
```

### iOS build fails with CocoaPods error

```bash
cd app/ios
rm -rf Pods Podfile.lock
pod install --repo-update
cd ..
flutter clean
flutter pub get
flutter run -d iphone
```

### Firebase config missing

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure
cd app
flutterfire configure --project=drapeai-firebase
```

### Port 8000 already in use

```bash
lsof -ti:8000 | xargs kill -9
```

### M1/M2 Mac Python issues

```bash
# If pip install fails for native packages
ARCHFLAGS="-arch arm64" pip install -r requirements.txt
```
