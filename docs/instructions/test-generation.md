# Profile: Tests

## Backend

- `api/tests/` with pytest-asyncio
- Prefer testing ownership (404/403 when wrong user) and happy path
- Reuse `conftest.py` fixtures; don’t hit real paid APIs in unit tests — mock providers

## Flutter

- Widget tests under `app/test/features/…`
- Pump with needed ProviderScope overrides
- Assert user-visible text/states, not private implementation

## Don’t

- Delete failing tests to “make CI green”
- Add huge snapshot tests for trivial widgets without value
