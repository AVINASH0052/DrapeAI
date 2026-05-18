# DrapeAI Frontend -- Documentation Index

> Flutter (Dart) + Riverpod + Dio + GoRouter + Firebase Auth

---

## Build Order

Follow this exact sequence. Each phase depends on the previous one.

| Phase | What to Build | Guide Section |
|---|---|---|
| 1 | Project scaffold + theme + routing shell | [implementation_guide.md#phase-1](implementation_guide.md#phase-1--project-scaffold) |
| 2 | Auth flow (Firebase phone OTP + Google sign-in) | [implementation_guide.md#phase-2](implementation_guide.md#phase-2--authentication-flow) |
| 3 | Dio API client + auth interceptor | [implementation_guide.md#phase-3](implementation_guide.md#phase-3--api-client-layer) |
| 4 | Onboarding quiz (5 questions + visual tiles) | [implementation_guide.md#phase-4](implementation_guide.md#phase-4--onboarding-quiz) |
| 5 | Camera + photo capture + upload flow | [implementation_guide.md#phase-5](implementation_guide.md#phase-5--camera--upload-flow) |
| 6 | Auto-tag review screen | [implementation_guide.md#phase-6](implementation_guide.md#phase-6--auto-tag-review) |
| 7 | Wardrobe grid (3-col, filters, search, FAB) | [implementation_guide.md#phase-7](implementation_guide.md#phase-7--wardrobe-grid) |
| 8 | Item detail screen | [implementation_guide.md#phase-8](implementation_guide.md#phase-8--item-detail) |
| 9 | Today's Outfits screen (3 cards + weather badge) | [implementation_guide.md#phase-9](implementation_guide.md#phase-9--todays-outfits) |
| 10 | Shuffle screen (swipe deck) | [implementation_guide.md#phase-10](implementation_guide.md#phase-10--shuffle-screen) |
| 11 | Lookbooks (2-col grid, CRUD) | [implementation_guide.md#phase-11](implementation_guide.md#phase-11--lookbooks) |
| 12 | Profile + settings | [implementation_guide.md#phase-12](implementation_guide.md#phase-12--profile--settings) |
| 13 | Polish: animations, loading states, error states | [implementation_guide.md#phase-13](implementation_guide.md#phase-13--polish) |

---

## Reference Documents

| Document | Purpose |
|---|---|
| [implementation_guide.md](implementation_guide.md) | Step-by-step HOW to build every screen, widget by widget, with code |
| [coding_standards.md](coding_standards.md) | Dart/Flutter rules: Riverpod patterns, naming, no emojis, light theme only |
| [ui_ux_spec.md](ui_ux_spec.md) | Full design system: colors, typography, spacing, components, all 12 screen specs |

---

## Quick Reference

```bash
# Run on iOS simulator
cd app && flutter run -d "iPhone 16 Pro"

# Run on Android emulator
flutter run -d emulator-5554

# Run tests
flutter test

# Build release APK
flutter build apk --release

# Build iOS archive
flutter build ipa --release
```

### Design System at a Glance

| Token | Value |
|---|---|
| Primary text | Gray-900 `#111827` |
| Accent | Indigo-500 `#6366F1` |
| Background | `#FFFFFF` |
| Surface | Gray-50 `#F9FAFB` |
| Border | Gray-200 `#E5E7EB` |
| Error | Red-500 `#EF4444` |
| Success | Green-500 `#22C55E` |
| Font | Inter (all weights) |
| Base spacing | 4px |
| Border radius | 12px (cards), 8px (buttons/inputs) |
