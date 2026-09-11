# Frontend (`app/`)

Flutter consumer app for **Sugatai** (`com.sugatai.sugatai`).

## Layout

| Path | Role |
|---|---|
| `lib/core/` | Theme, router, Dio, brand, shell |
| `lib/features/auth/` | Firebase Google / Apple / phone + dev test entry |
| `lib/features/avatar/` | Body setup + Avatar Studio |
| `lib/features/wardrobe/` | Grid, camera upload, item detail, gaps |
| `lib/features/outfits/` | Today, shuffle, chat, visualize |
| `lib/features/try_on/` | Fitting room, history, refine |
| `lib/features/lookbooks/` | Saved collections |
| `lib/features/calendar/` | Wear calendar |
| `lib/features/analytics/` | Usage stats |
| `lib/features/notifications/` | In-app notification list |
| `lib/features/onboarding/` | Style profile quiz (from Profile) |
| `lib/features/profile/` | Account, legal, about |
| `test/` | Widget / feature tests |

## Deep dives

- [../frontend/README.md](../frontend/README.md)
- [../../design-system/sugatai/MASTER.md](../../design-system/sugatai/MASTER.md) — **authoritative** brand tokens
- `app/README.md`

## Invariants

Light theme · Material Icons · Riverpod · GoRouter · auth interceptor on Dio · no emoji in UI · API base via `--dart-define=API_BASE_URL`.

## Firebase iOS

Bundle id is `com.sugatai.sugatai`. In Firebase Console, the iOS app’s bundle id must match, then download a fresh `GoogleService-Info.plist` into `app/ios/Runner/` (gitignored). Template: `GoogleService-Info.plist.example`.
