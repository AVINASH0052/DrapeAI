# Git workflow

1. Branch from the team’s main integration branch (`main` / `master` / `develop` — match the remote default).
2. Keep PRs focused — one feature or fix.
3. Write commits that explain *why* (not a file dump).
4. Ensure CI (`.github/workflows/`) is green before merge when available.
5. Do not force-push shared branches; do not commit `.env`.

Hooks / release tagging: follow whatever the existing GitHub Actions already expect.
