# DrapeAI -- Project Structure

Exact folder layout for the monorepo. Every folder explained. Copy this to scaffold the project.

---

## Root Layout

```
drapeai/
├── app/                      # Flutter mobile app (Android + iOS)
├── api/                      # FastAPI backend
├── infra/                    # Docker, Nginx, deploy scripts
├── docs/                     # This documentation folder
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
├── .gitignore
├── PLAN.md                   # Master plan linking to all docs
└── README.md                 # Repo readme (setup + run instructions)
```

---

## Flutter App (`app/`)

```
app/
├── pubspec.yaml                    # Dependencies, assets, app config
├── pubspec.lock
├── analysis_options.yaml           # Dart linting rules
├── lib/
│   ├── main.dart                   # Entry point: ProviderScope + MaterialApp.router
│   ├── app.dart                    # MaterialApp.router with GoRouter
│   │
│   ├── core/                       # Shared infrastructure (not UI)
│   │   ├── constants/
│   │   │   ├── colors.dart         # AppColors: gray900, indigo500, etc.
│   │   │   ├── typography.dart     # AppTextStyles: displayLg, titleMd, etc.
│   │   │   ├── spacing.dart        # AppSpacing: xs=4, sm=8, md=16, lg=24, xl=32
│   │   │   ├── api_endpoints.dart  # All endpoint URLs in one place
│   │   │   └── enums.dart          # Category, SubCategory, Color, Formality, etc.
│   │   ├── theme/
│   │   │   └── app_theme.dart      # ThemeData: light theme only
│   │   ├── network/
│   │   │   ├── dio_client.dart     # Dio instance with interceptors
│   │   │   ├── auth_interceptor.dart  # Attaches Firebase JWT to requests
│   │   │   └── api_exception.dart  # Typed exceptions: NetworkException, ServerException
│   │   ├── storage/
│   │   │   └── secure_storage.dart # Flutter Secure Storage wrapper
│   │   ├── router/
│   │   │   └── app_router.dart     # GoRouter config: routes, guards, deep links
│   │   └── utils/
│   │       ├── image_utils.dart    # Compress, resize before upload
│   │       └── date_utils.dart     # Format dates for Indian locale
│   │
│   ├── features/                   # Feature modules (one per screen group)
│   │   ├── auth/
│   │   │   ├── data/
│   │   │   │   ├── auth_repository.dart
│   │   │   │   └── auth_service.dart    # Firebase Auth calls
│   │   │   ├── domain/
│   │   │   │   └── auth_state.dart      # AuthState: loading, authenticated, unauthenticated
│   │   │   ├── presentation/
│   │   │   │   ├── auth_screen.dart
│   │   │   │   ├── otp_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       ├── phone_input_field.dart
│   │   │   │       └── otp_input_field.dart
│   │   │   └── providers/
│   │   │       └── auth_provider.dart   # Riverpod providers
│   │   │
│   │   ├── onboarding/
│   │   │   ├── data/
│   │   │   │   └── preferences_repository.dart
│   │   │   ├── presentation/
│   │   │   │   ├── onboarding_screen.dart   # 5-question quiz
│   │   │   │   ├── welcome_screen.dart      # Post-quiz: "upload or try demo"
│   │   │   │   └── widgets/
│   │   │   │       ├── quiz_step.dart
│   │   │   │       └── style_chip.dart
│   │   │   └── providers/
│   │   │       └── onboarding_provider.dart
│   │   │
│   │   ├── wardrobe/
│   │   │   ├── data/
│   │   │   │   ├── item_repository.dart
│   │   │   │   └── item_model.dart
│   │   │   ├── presentation/
│   │   │   │   ├── wardrobe_screen.dart     # Grid of items + FAB to add
│   │   │   │   ├── item_detail_screen.dart  # Single item view + edit tags
│   │   │   │   ├── camera_screen.dart       # Camera + photo guide overlay
│   │   │   │   ├── tag_review_screen.dart   # AI tags + user correction
│   │   │   │   └── widgets/
│   │   │   │       ├── item_card.dart       # Grid item thumbnail
│   │   │   │       ├── category_filter_bar.dart
│   │   │   │       ├── photo_guide_overlay.dart
│   │   │   │       └── tag_chip.dart
│   │   │   └── providers/
│   │   │       ├── wardrobe_provider.dart
│   │   │       └── upload_provider.dart     # Handles upload + tagging flow
│   │   │
│   │   ├── outfits/
│   │   │   ├── data/
│   │   │   │   ├── outfit_repository.dart
│   │   │   │   └── outfit_model.dart
│   │   │   ├── presentation/
│   │   │   │   ├── today_screen.dart        # 3 outfit cards for today
│   │   │   │   ├── shuffle_screen.dart      # Swipeable deck
│   │   │   │   └── widgets/
│   │   │   │       ├── outfit_card.dart     # Outfit display: items + reason
│   │   │   │       ├── feedback_buttons.dart
│   │   │   │       └── shuffle_card.dart
│   │   │   └── providers/
│   │   │       ├── outfit_provider.dart
│   │   │       └── shuffle_provider.dart
│   │   │
│   │   ├── lookbooks/
│   │   │   ├── data/
│   │   │   │   ├── lookbook_repository.dart
│   │   │   │   └── lookbook_model.dart
│   │   │   ├── presentation/
│   │   │   │   ├── lookbooks_screen.dart
│   │   │   │   ├── lookbook_detail_screen.dart
│   │   │   │   └── widgets/
│   │   │   │       └── lookbook_card.dart
│   │   │   └── providers/
│   │   │       └── lookbook_provider.dart
│   │   │
│   │   └── profile/
│   │       ├── data/
│   │       │   └── user_repository.dart
│   │       ├── presentation/
│   │       │   ├── profile_screen.dart
│   │       │   └── widgets/
│   │       │       └── stat_tile.dart
│   │       └── providers/
│   │           └── profile_provider.dart
│   │
│   └── shared/                      # Widgets used across features
│       ├── widgets/
│       │   ├── app_button.dart      # Primary, secondary, text variants
│       │   ├── app_bottom_nav.dart  # Bottom navigation bar
│       │   ├── loading_skeleton.dart
│       │   ├── empty_state.dart     # Illustration + message + CTA
│       │   ├── error_state.dart     # Retry button
│       │   └── cached_image.dart    # CachedNetworkImage wrapper
│       └── providers/
│           └── connectivity_provider.dart
│
├── assets/
│   ├── images/
│   │   ├── logo.svg
│   │   ├── onboarding_1.svg         # Illustrations for onboarding
│   │   ├── onboarding_2.svg
│   │   ├── empty_wardrobe.svg
│   │   ├── empty_outfits.svg
│   │   └── no_connection.svg
│   └── fonts/
│       ├── Inter-Regular.ttf
│       ├── Inter-Medium.ttf
│       ├── Inter-SemiBold.ttf
│       └── Inter-Bold.ttf
│
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   ├── google-services.json       # Firebase config (not committed to public repo)
│   │   └── src/main/AndroidManifest.xml
│   ├── build.gradle
│   ├── key.properties                 # Signing config (gitignored)
│   └── gradle.properties
│
├── ios/
│   ├── Runner/
│   │   ├── Info.plist                 # Permissions, bundle config
│   │   ├── GoogleService-Info.plist   # Firebase config
│   │   └── Assets.xcassets/           # App icons
│   ├── Runner.xcworkspace
│   └── Podfile
│
└── test/
    ├── unit/
    │   ├── auth_repository_test.dart
    │   ├── item_model_test.dart
    │   └── outfit_model_test.dart
    └── widget/
        ├── item_card_test.dart
        └── outfit_card_test.dart
```

---

## FastAPI Backend (`api/`)

```
api/
├── requirements.txt                # Python dependencies
├── Dockerfile                      # Production container
├── pytest.ini                      # Test configuration
│
├── app/
│   ├── __init__.py
│   ├── main.py                     # FastAPI app, middleware, exception handlers
│   ├── config.py                   # Settings from env vars (pydantic BaseSettings)
│   │
│   ├── auth/
│   │   ├── __init__.py
│   │   ├── firebase.py             # verify_firebase_token()
│   │   └── dependencies.py         # get_current_user dependency
│   │
│   ├── database/
│   │   ├── __init__.py
│   │   ├── connection.py           # asyncpg pool creation
│   │   ├── migrations.py           # Run SQL migrations in order
│   │   └── queries/
│   │       ├── __init__.py
│   │       ├── users.py            # get_user, create_user, update_user
│   │       ├── items.py            # create_item, get_items, update_item, delete_item
│   │       ├── outfits.py          # save_outfit, get_outfits, record_feedback
│   │       ├── lookbooks.py        # CRUD for lookbooks
│   │       └── preferences.py      # save_preferences, get_preferences
│   │
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── health.py               # GET /health
│   │   ├── auth.py                 # POST /auth/verify
│   │   ├── users.py                # GET /me, PATCH /me
│   │   ├── preferences.py          # PUT /preferences, GET /preferences
│   │   ├── items.py                # POST /items/upload, GET /items, etc.
│   │   ├── outfits.py              # POST /outfits/generate, POST /outfits/shuffle, etc.
│   │   ├── lookbooks.py            # CRUD endpoints
│   │   ├── demo.py                 # POST /demo/activate, POST /demo/clear
│   │   └── push.py                 # POST /push/register
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── vision.py               # GPT-4o Vision tagging
│   │   ├── embeddings.py           # text-embedding-3-small
│   │   ├── outfit_engine.py        # Rule engine: filter -> build -> score
│   │   ├── llm_ranker.py           # GPT-4o outfit ranking
│   │   ├── background_removal.py   # rembg wrapper
│   │   ├── weather.py              # OpenWeatherMap API
│   │   └── storage.py              # R2 upload/download/delete
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   ├── user.py                 # User dataclass
│   │   ├── item.py                 # Item dataclass with enums
│   │   ├── outfit.py               # Outfit dataclass
│   │   └── preferences.py          # Preferences dataclass
│   │
│   └── utils/
│       ├── __init__.py
│       ├── image_validation.py     # Magic bytes check, size limits
│       └── cost_tracker.py         # OpenAI spend cap enforcement
│
├── db/
│   ├── init.sql                    # Initial schema (CREATE TABLE, CREATE INDEX)
│   └── migrations/
│       ├── 001_initial.sql
│       ├── 002_add_weather_cache.sql
│       └── 003_add_push_tokens.sql
│
└── tests/
    ├── conftest.py                 # Fixtures: test DB, test client
    ├── test_auth.py
    ├── test_items.py
    ├── test_outfits.py
    ├── test_outfit_engine.py       # Unit tests for rule engine
    └── test_vision.py              # Mock OpenAI responses
```

---

## Infrastructure (`infra/`)

```
infra/
├── docker-compose.dev.yml          # Local development (postgres + pgvector)
├── docker-compose.prod.yml         # Production (nginx + backend + postgres)
├── nginx/
│   └── nginx.conf                  # Production Nginx config
└── scripts/
    ├── backup.sh                   # Database backup script
    ├── restore.sh                  # Database restore script
    └── setup-server.sh             # Initial Hetzner server setup
```

---

## Key Configuration Files

### `.gitignore`

```gitignore
# Environment
.env
*.env
.env.*

# Flutter
app/build/
app/.dart_tool/
app/.packages
app/.flutter-plugins
app/.flutter-plugins-dependencies

# iOS
app/ios/Pods/
app/ios/.symlinks/
app/ios/Flutter/Generated.xcconfig
app/ios/Runner/GeneratedPluginRegistrant.*

# Android
app/android/.gradle/
app/android/local.properties
app/android/key.properties
*.jks

# Firebase (sensitive)
app/android/app/google-services.json
app/ios/Runner/GoogleService-Info.plist

# Python
api/__pycache__/
api/.pytest_cache/
api/venv/
api/.venv/
*.pyc

# Docker
data/

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
```

### `app/pubspec.yaml` (key dependencies)

```yaml
name: drapeai
description: AI Outfit Assistant
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0

  # Networking
  dio: ^5.4.0

  # Routing
  go_router: ^14.0.0

  # Firebase
  firebase_core: ^3.0.0
  firebase_auth: ^5.0.0
  firebase_messaging: ^15.0.0

  # UI
  cached_network_image: ^3.3.0
  flutter_svg: ^2.0.0
  shimmer: ^3.0.0
  flutter_card_swiper: ^7.0.0

  # Camera + Images
  camera: ^0.11.0
  image_picker: ^1.0.0
  image_cropper: ^6.0.0

  # Storage
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.0

  # Utils
  intl: ^0.19.0
  url_launcher: ^6.2.0
  permission_handler: ^11.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0
  riverpod_generator: ^2.4.0
  build_runner: ^2.4.0
  mockito: ^5.4.0
```

### `api/requirements.txt`

```
fastapi==0.115.0
uvicorn[standard]==0.30.0
asyncpg==0.30.0
httpx==0.27.0
python-jose[cryptography]==3.3.0
python-multipart==0.0.9
Pillow==10.4.0
rembg==2.0.57
openai==1.50.0
boto3==1.35.0
pydantic==2.9.0
pydantic-settings==2.5.0
sentry-sdk[fastapi]==2.14.0
```

---

## File Naming Conventions

| Layer | Convention | Example |
|---|---|---|
| Flutter screens | `snake_case_screen.dart` | `wardrobe_screen.dart` |
| Flutter widgets | `snake_case.dart` | `item_card.dart` |
| Flutter providers | `snake_case_provider.dart` | `wardrobe_provider.dart` |
| Flutter models | `snake_case_model.dart` | `item_model.dart` |
| Flutter repos | `snake_case_repository.dart` | `item_repository.dart` |
| Python routes | `snake_case.py` | `items.py` |
| Python services | `snake_case.py` | `vision.py` |
| Python queries | `snake_case.py` | `items.py` |
| SQL migrations | `NNN_description.sql` | `001_initial.sql` |
| Tests | `test_snake_case.dart/.py` | `test_items.py` |
