# Sugatai (Flutter)

Consumer mobile app for Sugatai — AI wardrobe stylist.

## Run

```bash
cd app
flutter pub get
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=ENABLE_DEV_TEST_FLOW=true
```

Wireless iOS: set `API_BASE_URL` to your Mac LAN IP. Debug builds must be launched from Flutter/Xcode; use `--profile` or `--release` for home-screen launches on iOS 14+.

## Layout

| Path | Role |
|---|---|
| `lib/core/` | Theme, router, Dio, brand, shell |
| `lib/features/` | auth, avatar, wardrobe, outfits, try_on, lookbooks, calendar, analytics, notifications, onboarding, profile |
| `test/` | Widget / feature tests |

## Brand

Product name: **Sugatai** (`com.sugatai.sugatai`). Repo folder: `Sugatai`. Firebase project id is `sugatai-41e84`. Some infra names (Postgres user/db) still say `drapeai`.

See [docs/services/FRONTEND.md](../docs/services/FRONTEND.md) and [design-system/sugatai/MASTER.md](../design-system/sugatai/MASTER.md).
