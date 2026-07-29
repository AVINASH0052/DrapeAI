# Profile: Flutter UI generation

Use when adding screens, widgets, or feature modules.

## Do

1. Place code under `app/lib/features/<feature>/` (data / presentation / providers).
2. Use `AppColors` / `AppTheme` / spacing tokens — light theme only.
3. Material Icons only; no emoji.
4. Wire Dio through existing client + auth interceptor.
5. Handle loading, empty, and error states.
6. Add/adjust widget tests under `app/test/` for behaviour changes.
7. Match [../frontend/ui_ux_spec.md](../frontend/ui_ux_spec.md) when it specifies the screen.

## Don’t

- Hardcode production API URLs or secrets
- Introduce a second state-management library without ask
- Invent a new visual system that fights existing tokens
