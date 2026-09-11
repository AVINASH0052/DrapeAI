# Sugatai Launch Plan — September 2026

**Target:** production-ready, store-submission-ready, controlled launch by **September 30, 2026**.

**Plan owner:** Sugatai team  
**Product:** Sugatai AI wardrobe stylist  
**Release posture:** early access / controlled beta first, followed by wider availability after store approval and beta validation.

## 1. Definition of success

For this launch, “10/10 ready” means there are no known P0 or P1 blockers across product, security, release builds, operations, privacy, or store submission. It does not mean every future roadmap feature is complete.

The release must prove that a new user can:

1. Sign in with Firebase.
2. Complete onboarding.
3. Upload wardrobe photos.
4. Receive processed wardrobe items.
5. Generate an outfit.
6. Refine, save, and mark an outfit as worn.
7. Upload a private try-on photo.
8. Generate and view a try-on result.
9. Receive useful error and loading states when a dependency is slow or unavailable.
10. Delete the account and associated user data.

The launch will be considered complete only when the same flow works on real iOS and Android devices against the production-like backend.

## 2. Scope freeze

### Included in this launch

- Firebase phone, Google, and Apple authentication where configured.
- Style onboarding and preferences.
- Wardrobe upload, validation, tagging, and background processing.
- Daily outfits, shuffle, feedback, refinement, lookbooks, calendar, and analytics.
- Body-photo setup and private try-on.
- External/shop try-on where already implemented.
- Push notifications where configured.
- Account deletion and privacy controls.
- Admin operations required to support early users.
- Marketing site, waitlist, privacy policy, terms, and support contact.

### Explicitly deferred

Do not expand scope during this release window with:

- Razorpay or paid Pro billing.
- Affiliate shopping integrations.
- Vernacular UI.
- Trip packing planner.
- Human stylist marketplace.
- Resale marketplace.
- Whole-wardrobe RAG chat.
- New AI providers unless required to keep the existing launch path working.

Paid plans may remain documented as future functionality, but no public paid promise should be made until billing, entitlement enforcement, refunds, and store billing compliance are complete.

## 3. Code changes first

Before store preparation, beta recruitment, or production rollout, make the following code and configuration changes. Each change must land with its focused tests and must pass CI before the next release activity begins.

### 3.1 Add a real CI quality gate

Files:

- `.github/workflows/ci.yml` — add the release validation workflow.
- `.github/workflows/deploy.yml` — require the CI workflow and deploy the tested commit/tag.
- `api/pytest.ini` and `api/requirements.txt` — keep the test runtime reproducible.
- `app/pubspec.yaml` and Flutter project configuration — use the supported Flutter version consistently.

Code/configuration changes:

- Add backend, web, admin, and Flutter jobs.
- Use Python 3.11 for the backend, matching the Docker image.
- Install dependencies from scratch rather than relying on cached local packages.
- Start PostgreSQL and Redis services for integration tests.
- Run backend import checks, pytest, web build, admin build, `flutter analyze`, and `flutter test`.
- Make deployment depend on a successful CI run.
- Make deployment use an immutable tested commit or release tag instead of pulling an arbitrary branch tip.
- Upload test and build artifacts so failed release checks can be diagnosed.

Tests to add or verify:

- A clean checkout passes all jobs.
- A deliberate failing test blocks deployment.
- The backend imports successfully with every dependency installed from `requirements.txt`.
- The Flutter job runs on a clean runner without relying on local SDK cache state.

### 3.2 Make production configuration fail safely

Files:

- `api/app/config.py`
- `api/app/main.py`
- `api/.env.example`
- `docs/local-development/ENV-VARS.md`

Code/configuration changes:

- Add explicit production validation for Firebase project configuration, database, Redis, storage, CORS, and the selected AI provider.
- Keep the development `test-token` path impossible when `ENVIRONMENT=production`.
- Reject wildcard CORS, localhost API URLs, development tunnel URLs, and empty production storage configuration.
- Do not silently fall back to in-memory rate limiting in production when Redis is required; fail readiness or fail startup with an actionable message.
- Validate try-on provider order, model names, timeout values, daily limits, and spend caps.
- Document every required production variable and whether it is a secret.

Tests to add or verify:

- Missing Firebase, R2, database, Redis, or provider configuration fails with a clear message.
- Development configuration still works locally.
- Production rejects `test-token`, wildcard CORS, and invalid environment names.
- Production never starts with an uncapped AI provider.

### 3.3 Split liveness and readiness health checks

Files:

- `api/app/routes/health.py`
- `api/app/main.py`
- `infra/docker-compose.prod.yml`
- `infra/nginx/nginx.conf`
- `.github/workflows/deploy.yml`

Code/configuration changes:

- Keep `/health` as a lightweight liveness endpoint.
- Add a readiness endpoint that checks PostgreSQL, Redis, worker availability/heartbeat, storage configuration, and required provider configuration.
- Return a non-success status when the service is not ready, rather than returning HTTP 200 with only a degraded body.
- Add Docker health checks for the API and worker.
- Make deployment wait for readiness, not merely for a listening HTTP process.
- Configure Nginx and deployment smoke checks to use the correct health endpoint.

Tests to add or verify:

- Database failure makes readiness fail.
- Redis failure makes production readiness fail.
- The deployment workflow fails when readiness is degraded.
- Liveness remains available during dependency diagnosis.

### 3.4 Harden Android release signing and iOS transport security

Files:

- `app/android/app/build.gradle.kts`
- `app/android/key.properties.example`
- Android ProGuard/R8 configuration files.
- `app/ios/Runner/Info.plist`
- iOS release build settings and entitlements.

Code/configuration changes:

- Remove the Android fallback from release signing to the debug key.
- Fail the release build when the production keystore is missing or incomplete.
- Enable R8/minification and verify required keep rules for Firebase, Flutter plugins, and reflection-based code.
- Keep keystores and signing credentials outside Git and CI logs.
- Remove `NSAllowsArbitraryLoads` from production iOS settings.
- Keep any local-network or cleartext exceptions limited to debug configuration.
- Confirm release builds use only HTTPS production API URLs.

Tests to add or verify:

- Release Android build fails without release signing credentials.
- Signed AAB installs and starts on supported Android versions.
- Minified Android build completes auth, upload, push, and navigation flows.
- iOS release archive builds without arbitrary network loads.
- Release binaries contain no localhost, tunnel URL, test-token, or development-only configuration.

### 3.5 Implement public legal and support pages

Files:

- `web/src/App.tsx`
- New web legal-page components/content under `web/src/`.
- `web/src/worker.ts`
- `web/index.html`
- `web/public/` assets as needed.

Code/configuration changes:

- Implement public `/privacy`, `/terms`, and `/support` routes/pages.
- Make the Cloudflare Worker preserve those routes and return the correct page on direct navigation, not only after client-side navigation.
- Add footer links from the landing page.
- Add canonical metadata and page titles for each legal page.
- Keep public policy language aligned with the mobile in-app legal screens.
- Do not describe future billing, analytics, retention, or subprocessors as live unless they are actually enabled.

Tests to add or verify:

- Direct requests to `/privacy`, `/terms`, and `/support` return the correct content and HTTP success status.
- Links work on mobile and desktop.
- The pages still work after Cloudflare deployment and SPA fallback behavior.
- Legal content mentions account deletion, body photos, wardrobe photos, AI processing, storage, subprocessors, retention, and contact details accurately.

### 3.6 Provide a reliable store-review path

Files:

- `app/lib/features/auth/` for reviewer-friendly login behavior where needed.
- `app/lib/features/wardrobe/` and onboarding screens if a demo wardrobe is implemented.
- Relevant API route/service files for idempotent demo data.
- `docs/store_submission.md` for final reviewer instructions.

Code/configuration changes:

- Choose one supported path: a real reviewer test account, or an authenticated demo-wardrobe flow.
- If using demo data, seed it idempotently and keep it isolated from real user data.
- Ensure the reviewer can reach outfit generation and try-on without being blocked by an empty closet.
- Ensure the reviewer can delete the test account and test user-owned data.
- Remove any undocumented developer bypass from release builds.

Tests to add or verify:

- A fresh reviewer account can complete the core journey without manual database edits.
- Demo data is not visible to other users.
- Demo seeding can be repeated without duplicates.
- Store review instructions match the actual app.

### 3.7 Harden account deletion and private image cleanup

Files:

- `api/app/routes/user.py`
- `api/app/services/storage.py`
- `api/app/database/queries/` as required.
- `app/lib/features/auth/providers/auth_provider.dart`
- `app/lib/features/profile/presentation/profile_screen.dart`
- `api/tests/` and `app/test/` deletion tests.

Code/configuration changes:

- Make account deletion transactional for database records and explicit for R2/source/derived images.
- Make deletion idempotent so retries do not fail after partial cleanup.
- Handle Firebase recent-login requirements with a clear re-authentication path.
- Return a generic client-safe error while logging an actionable internal failure.
- Ensure queued jobs cannot recreate or retain data after deletion.
- Verify push tokens and external try-on history are removed.

Tests to add or verify:

- Account deletion succeeds for a complete user.
- Deletion succeeds when some storage objects are already missing.
- Deletion retry is safe.
- No user rows, child rows, push tokens, job records, or private images remain after deletion.
- A queued job cannot write new user data after deletion.

### 3.8 Add production observability and safe failure handling

Files:

- `api/app/main.py`
- `api/app/middleware/` and relevant service modules.
- `api/app/utils/cost_tracker.py`
- `api/.env.example`
- `infra/docker-compose.prod.yml`
- Admin health/analytics pages where needed.

Code/configuration changes:

- Enable production error tracking with a configured Sentry DSN or approved equivalent.
- Add structured request/job correlation IDs.
- Redact tokens, API keys, full email addresses, phone numbers, and raw image data from logs.
- Emit useful job failure, provider failure, quota, and spend-cap events.
- Add provider, worker, and queue health visibility to the admin console or operational endpoint.
- Ensure cost tracking failure does not silently permit uncapped calls.
- Add explicit retry limits and terminal failure states for background work.

Tests to add or verify:

- A simulated API exception appears in error tracking without sensitive data.
- Provider failures are visible in logs/admin metrics.
- Spend-cap and quota events are emitted.
- Retries stop at the configured limit.

### 3.9 Close the security gaps found in the current implementation

The following are concrete gaps found during the launch audit. They must be fixed and tested before production users are invited.

#### 3.9.1 Fix rate-limit identity and production degradation

Files:

- `api/app/main.py`
- `api/app/middleware/rate_limiter.py`
- `api/app/auth/dependencies.py`
- `api/app/services/redis_client.py`
- `api/tests/test_auth.py` and rate-limit tests.

Finding:

- `RateLimitMiddleware` runs before FastAPI dependencies populate `request.state.user_id`, so its supposed per-user limits currently fall back to the client IP for authenticated requests.
- If Redis is unavailable, production falls back to in-memory limits. Multiple API workers or replicas can then bypass the intended global limit.

Required changes:

- Authenticate or safely derive a stable identity before applying user-scoped limits, or enforce expensive-operation quotas inside authenticated route/service code where the verified user ID is available.
- Keep IP-based limits for unauthenticated endpoints and add user-based limits for authenticated expensive operations.
- In production, treat Redis as required for distributed rate limiting and job queues. Mark readiness failed or stop accepting expensive work when Redis is unavailable.
- Keep an explicitly documented in-memory fallback only for development.
- Use atomic Redis operations for the sliding-window counter and verify concurrent requests cannot over-admit.
- Add rate-limit event metrics without logging sensitive request data.

Required tests:

- Two authenticated users behind the same IP have independent user limits.
- One user cannot bypass limits by opening multiple sessions or hitting multiple API workers.
- Unauthenticated waitlist/API traffic is limited by IP.
- Redis outage causes production readiness to fail and does not silently enable an unsafe distributed fallback.
- Concurrent requests cannot exceed the configured quota.

#### 3.9.2 Protect private wardrobe, avatar, and try-on images

Files:

- `api/app/services/storage.py`
- `api/app/routes/` image-returning endpoints.
- `admin/src/services/api.js` and admin image components.
- R2 bucket/CDN configuration.
- Storage and ownership integration tests.

Finding:

- Production `get_image_url()` returns an `R2_PUBLIC_URL` when configured. Public object URLs are not protected by API ownership checks, which conflicts with the product promise that closets and body photos are private.
- The fallback `/uploads/...` URL is not served in production when R2 configuration is incomplete, so an incomplete setup can both break images and create pressure to make the bucket public.

Required changes:

- Keep the R2 bucket private.
- Return short-lived signed URLs or proxy image access through an authenticated ownership-checked endpoint.
- Never expose raw storage keys to mobile or admin clients unless required.
- Validate that the requested object belongs to the authenticated user before issuing a URL or streaming bytes.
- Give admins only the access needed for support and record access to sensitive images where appropriate.
- Make missing R2 configuration fail production readiness rather than silently returning broken URLs.
- Ensure deletion invalidates access to both source and derived objects.

Required tests:

- Anonymous users cannot fetch a private image.
- User A cannot obtain a signed URL for User B’s image.
- Signed URLs expire within the configured lifetime.
- Deleted images cannot be fetched.
- Avatar, wardrobe, outfit-preview, and external try-on objects all use the same privacy model.

#### 3.9.3 Remove sensitive data from logs and client errors

Files:

- `api/app/services/redis_client.py`
- `api/app/services/embedder.py`
- `api/app/services/wardrobe_analysis.py`
- `api/app/services/try_on_job.py`
- `api/app/services/image_gen_provider.py`
- `api/app/routes/items.py`
- `api/app/routes/try_on.py`
- New shared logging/redaction utility under `api/app/`.

Findings:

- Redis connection logging can include the complete Redis URL, including a password if one is present.
- Some debug/error logs include prompt text, raw LLM output, city/location, image URLs, user IDs, or provider exception text.
- The external try-on route returns `str(e)` to the client, which can expose provider internals and request details.
- Sentry is optional and there is no documented guarantee that production exceptions are captured and visible to operators.

Required changes:

- Add structured logging with request ID, job ID, route, service, severity, duration, and a redacted user reference.
- Redact credentials from all URLs and exception messages before logging.
- Do not log prompts, raw model output, image bytes/URLs, phone numbers, full emails, or location unless explicitly approved and minimized.
- Store a generic client-safe error code/message and keep detailed diagnostics only in protected logs/error tracking.
- Add explicit Sentry capture/configuration checks and verify production exceptions are received.
- Add log retention and access-control rules for the production logging system.

Required tests:

- Secret scan and log-fixture tests detect API keys, bearer tokens, passwords, signed URLs, and raw image references.
- Client responses contain stable generic error codes, not provider exception strings.
- A simulated exception appears in error tracking with a request ID and no sensitive payload.
- Logs can correlate an API request with its background job without exposing user content.

#### 3.9.4 Add security headers and abuse controls to public workers

Files:

- `web/src/worker.ts`
- `admin/src/worker.ts`
- `web/index.html`
- `admin/index.html`
- Cloudflare/WAF configuration.

Required changes:

- Add consistent security headers to web and admin responses: CSP, `Permissions-Policy`, `Referrer-Policy`, `X-Content-Type-Options`, and frame protection.
- Keep the admin console `noindex` and restrict access through Firebase admin authorization.
- Review whether admin bearer tokens need to remain in `localStorage`; prefer a short-lived, HttpOnly, Secure, SameSite session where the architecture allows it.
- Add rate limiting and abuse protection to the public waitlist endpoint. Consider Cloudflare rate limiting or Turnstile if abuse is observed.
- Restrict API proxy methods, origins, and forwarded headers to the minimum required set.

Required tests:

- Security headers are present on marketing, admin, and API responses.
- CSP does not break the production builds.
- Admin routes reject expired/non-admin tokens.
- XSS test input is rendered as text and cannot access admin credentials.
- Waitlist spam is bounded and duplicate handling remains correct.

### 3.10 Build an admin dashboard that detects breakage

The current admin System Health page checks database connectivity, table counts, uptime, and whether provider credentials appear configured. That is useful but insufficient for monitoring production. The dashboard must show summarized operational telemetry; it should not expose raw production logs in the browser.

Files:

- `api/app/routes/admin.py`
- `api/app/database/queries/admin.py`
- New admin health/error query or service modules.
- `admin/src/services/api.js`
- `admin/src/pages/SystemHealth.jsx`
- New admin pages/components for Errors, Jobs, Providers, and Audit.

Required backend endpoints:

- `GET /admin/health/readiness` — PostgreSQL, Redis, worker heartbeat, storage, and required-provider readiness.
- `GET /admin/health/providers` — configured provider, live probe status where safe, last successful call, last failure, latency, and spend-cap state.
- `GET /admin/health/errors?days=7` — grouped redacted errors by service, route, severity, error code, count, first seen, last seen, and request ID examples.
- `GET /admin/health/jobs?hours=24` — queued, running, completed, failed, timed-out, and stale ARQ/try-on/upload jobs.
- `GET /admin/health/requests?hours=24` — request volume, status-code counts, latency percentiles, rate-limit events, and top failing routes.
- `GET /admin/audit` — paginated admin actions with actor, action, target, timestamp, request ID, and redacted metadata.

Required dashboard behavior:

- Show a red/amber/green status for every dependency, with “last checked” timestamps.
- Show current incidents at the top of the dashboard.
- Show API 4xx/5xx trends, p95 latency, failed jobs, queue depth, provider failures, and AI spend/quota warnings.
- Poll operational summaries every 30–60 seconds with manual refresh.
- Preserve the last known good state when a monitoring request fails, while clearly showing that data is stale.
- Link a failed job or error group to the relevant user/job detail page without exposing raw secrets or image data.
- Display deployment version/commit and environment so operators know what is running.
- Add visible warnings when Sentry, Redis, worker heartbeat, R2, or the selected AI provider is unavailable.
- Record admin viewing and destructive actions in the existing audit log.

Required monitoring tests:

- Kill or disconnect PostgreSQL, Redis, the worker, storage, and the selected AI provider one at a time.
- Confirm the backend reports the correct readiness state.
- Confirm the admin dashboard shows the failure within the polling interval.
- Confirm a recovered dependency returns to healthy state.
- Confirm stale dashboard data is marked stale rather than presented as current.
- Confirm error details are redacted and admin access is enforced.
- Confirm dashboard endpoints do not materially slow or overload the production database.

### 3.11 Add the release test harness

Files:

- `api/tests/conftest.py` and new backend integration tests.
- `app/integration_test/` for mobile end-to-end coverage.
- Existing feature tests under `app/test/`.
- New or updated test scripts under `scripts/` if required.

Code/configuration changes:

- Add deterministic fixtures for users, wardrobe items, outfits, try-on jobs, and provider responses.
- Add PostgreSQL/Redis integration fixtures instead of relying only on mocks.
- Add mobile integration coverage for the critical user journey.
- Add test data cleanup between runs.
- Add a production-like smoke script that exercises auth, upload, outfit, try-on, push registration, and deletion.
- Add secret scanning and dependency audit to CI.

Tests to add or verify:

- Full backend suite passes from a clean environment.
- Flutter analyzer and test suite pass.
- Critical mobile journey passes on a real device.
- Production-like smoke script passes with real Firebase/storage/provider configuration.
- Security and dependency scans pass without high-severity findings.

## 4. Release blockers currently known

These items must be resolved before public launch:

- The intended commits must be pushed to `origin/main`; the deployment workflow pulls from the remote branch.
- Backend tests must run successfully in a clean Python 3.11 environment.
- Flutter analysis, widget tests, integration tests, and release builds must run successfully in CI or on a verified release machine.
- Android release builds must never fall back to debug signing.
- Android release minification and ProGuard/R8 configuration must be verified.
- iOS production networking must not allow arbitrary loads.
- Public privacy, terms, and support pages must exist at stable URLs.
- A reviewer/test account or a reliable demo-wardrobe path must be available.
- Production-like end-to-end smoke tests must pass for auth, storage, workers, AI, push, and account deletion.
- Monitoring, backups, restore, and rollback must be demonstrated.

## 5. Workstreams

### Workstream A — Release control and repository hygiene

**Outcome:** the exact source revision that is tested is the revision that gets deployed and submitted.

Tasks:

- Confirm the working tree is clean before release work begins.
- Review the commits ahead of `origin/main` and push the intended changes.
- Create a release branch from the tested commit.
- Add a release tag after final validation.
- Record the release commit, app version, API version, and deployment timestamp.
- Remove generated artifacts and local-only changes from the release diff.
- Confirm no `.env`, Firebase private material, service-account keys, keystores, or tokens are tracked.
- Run `git diff --check` and a secret scan before release tagging.

Exit criteria:

- The tested commit, release tag, and deployed commit are identical.
- `git status` is clean.
- Secret scan is clean.
- Release notes identify known limitations and deferred features.

### Workstream B — CI and reproducible builds

**Outcome:** every release candidate is tested automatically in clean environments.

Tasks:

- Add a backend CI job using Python 3.11, the supported runtime.
- Install `api/requirements.txt` from scratch.
- Run import checks, formatting/lint checks, and the full pytest suite.
- Add PostgreSQL and Redis services to CI where integration tests require them.
- Add a web build job.
- Add an admin build job.
- Add Flutter setup using the repository’s supported Flutter 3.x version.
- Run `flutter pub get`, `flutter analyze`, and `flutter test`.
- Add Android release compilation to CI after signing is configured securely.
- Add iOS build validation on a macOS runner or verified release machine.
- Fail the pipeline on warnings that affect release safety: missing signing, missing required variables, unresolved analyzer errors, or failed tests.
- Keep deployment manual, but require the release workflow to reference a tested tag or commit.

Exit criteria:

- A clean CI run passes for backend, web, admin, and Flutter.
- A failed test prevents release deployment.
- The deployment job cannot deploy an untested branch tip.

### Workstream C — Backend, database, and worker reliability

**Outcome:** the API and asynchronous processing remain correct under normal failures.

Tasks:

- Run migrations against an empty PostgreSQL database.
- Run migrations against a database containing representative existing data.
- Verify Alembic head matches the schema expected by the running API.
- Verify migration rollback notes for every release migration.
- Test API startup with missing and invalid required production configuration.
- Test API startup with valid production configuration.
- Verify Firebase audience, issuer, key rotation, and token expiration checks.
- Verify development test-token behavior is impossible in production.
- Test ownership isolation for every user resource.
- Test suspended-user behavior and admin authorization.
- Test Redis-backed rate limits across multiple API workers.
- Test behavior when Redis is unavailable.
- Test ARQ queue processing, retries, timeouts, and permanently failed jobs.
- Test duplicate upload and duplicate try-on requests.
- Test that stale or completed jobs cannot overwrite newer user state.
- Verify generic client errors and useful server-side logs.
- Ensure logs do not contain tokens, API keys, full photos, or unnecessary PII.

Exit criteria:

- All critical API integration tests pass.
- No cross-user read, update, delete, or image access is possible.
- Failed background work is visible and recoverable.
- Migrations are repeatable and documented.

### Workstream D — AI provider, cost, and try-on readiness

**Outcome:** AI features are predictable, bounded, and safe to operate.

Tasks:

- Select one production primary try-on provider and document the fallback order.
- Verify every configured provider/model ID in the target production account.
- Run a real wardrobe-tagging smoke test.
- Run a real outfit-generation smoke test.
- Run a real try-on smoke test using a test user and representative images.
- Test invalid person photos, invalid garment photos, unsupported poses, and oversized inputs.
- Verify asynchronous job polling and timeout messaging in the app.
- Verify provider failure falls through to the configured fallback or returns a clear failure.
- Verify daily per-user try-on limits.
- Verify provider-level and total monthly spend caps.
- Verify concurrent jobs cannot bypass quotas.
- Record latency, failure rate, approximate cost, and output quality for each provider used.
- Keep IDM-VTON disabled unless its commercial licensing and operating configuration are explicitly approved.
- Do not make a commercial launch depend on an unapproved non-commercial model license.

Exit criteria:

- At least one real end-to-end try-on succeeds in production-like infrastructure.
- Provider failure, timeout, quota exhaustion, and budget exhaustion are tested.
- No unbounded provider path exists.
- Try-on quality is acceptable for early-access users, with limitations disclosed.

### Workstream E — Mobile release hardening

**Outcome:** signed iOS and Android builds are installable, secure, and usable on supported devices.

Tasks:

- Confirm `1.0.0+1` or the final approved version/build number.
- Verify Android application ID and iOS bundle identifier.
- Configure release signing from secure, local or CI-managed credentials.
- Make the Android build fail if the release keystore is missing.
- Enable R8/minification and verify the release build starts correctly.
- Test Firebase configuration for release builds, not only debug builds.
- Remove iOS `NSAllowsArbitraryLoads` from production settings.
- Verify HTTPS-only production API configuration.
- Verify camera, photo-library, notification, and microphone permission descriptions.
- Confirm permissions are requested only when needed.
- Verify deep links and external links.
- Test account deletion and re-authentication requirements.
- Test push token registration, unregister, and notification handling.
- Confirm no debug test-token entry is available in release builds.
- Verify app icon, splash screen, screenshots, metadata, and launch behavior.

Exit criteria:

- Signed Android AAB installs and launches on at least two Android versions.
- Signed iOS archive installs and launches on at least two iOS devices or simulators plus one physical device.
- No release build points to localhost, a tunnel, or development credentials.
- No release build uses debug signing.

### Workstream F — Privacy, legal, and trust

**Outcome:** users and app stores can understand how data and AI processing work.

Tasks:

- Publish `/privacy`, `/terms`, and `/support` pages on the public domain.
- Link privacy and terms from the marketing site footer.
- Link privacy and terms from the mobile app.
- Document authentication, wardrobe photos, body photos, derived images, city/preferences, analytics, push tokens, and AI processing.
- List relevant subprocessors: Firebase, Cloudflare/R2, configured AI providers, weather provider, and error monitoring.
- Document retention and account-deletion timelines accurately.
- Document that try-on output is probabilistic and not a medical or measurement tool.
- Confirm users can delete their account and private body photo.
- Verify deletion of source and derived storage objects.
- Prepare Play Data Safety and App Store privacy declarations.
- Confirm the product is not marketed to children under 13.
- Provide a working privacy and support email address.

Exit criteria:

- Public legal URLs return the correct documents.
- In-app copy matches the public policy.
- Store privacy declarations match actual data flows.
- Account deletion is tested end to end.

### Workstream G — Operations, monitoring, and recovery

**Outcome:** the team can detect and recover from failures after launch.

Tasks:

- Define API liveness and readiness checks separately.
- Include PostgreSQL, Redis, worker, storage, and provider readiness in operational checks where appropriate.
- Configure Sentry or equivalent error tracking for production.
- Configure alerts for elevated API 5xx errors, worker backlog, failed jobs, database failures, Redis failures, and spend-cap events.
- Verify logs are structured enough to trace a request/job without logging sensitive data.
- Configure database backups.
- Perform a restore into a separate database and verify application startup against it.
- Document deployment rollback to the previous known-good image/commit.
- Test rollback in staging or a production-like environment.
- Document who responds to incidents and where logs/alerts are checked.
- Verify TLS certificates, domain routing, CORS, and security headers.
- Verify Redis is not publicly exposed.

Exit criteria:

- A simulated API, worker, database, and provider failure produces a visible alert or clear degraded state.
- Backup restore succeeds.
- Rollback procedure is written and tested.
- The deployment health check fails when the service is not ready, not merely when the process is unreachable.

### Workstream H — Admin and customer support readiness

**Outcome:** early users can be supported without direct database intervention.

Tasks:

- Verify admin login and admin-only routes.
- Test user search and user detail views.
- Test item/outfit/try-on job inspection.
- Test support actions and audit logging.
- Test flagged-content review and account suspension behavior.
- Verify admin cannot bypass intended audit controls.
- Prepare a support response for failed uploads, failed try-ons, account deletion, and login problems.
- Prepare a known-issues page for beta users.

Exit criteria:

- A support operator can diagnose the common launch failures from the admin console and logs.
- Destructive admin operations require confirmation and are audited.

## 6. Testing matrix

### Backend unit and service tests

- Configuration validation.
- Firebase token validation.
- Upload MIME, magic-byte, size, and image-dimension checks.
- Prompt loading and structured LLM JSON parsing.
- Outfit rule filtering and ranking fallback behavior.
- Spend-cap calculations.
- Try-on input checks.
- Provider cascade and error classification.
- Job state transitions and stale-job protection.
- Storage URL/key handling.

### API integration tests

- Health and readiness endpoints.
- Authenticated profile creation and update.
- Preferences and onboarding.
- Wardrobe create/list/read/update/delete.
- Cross-user access denial for every resource type.
- Outfit generation, shuffle, feedback, save, and wear.
- Lookbooks and calendar.
- Avatar/try-on photo upload, replacement, and deletion.
- Try-on job creation, polling, completion, failure, timeout, and quota.
- External try-on history.
- Push token register/unregister.
- Account deletion.
- Admin authentication and audit log behavior.
- Waitlist validation and duplicate handling.

### Mobile tests

- Auth screen states and OTP validation.
- Onboarding completion and skip paths.
- Wardrobe empty/loading/error/ready states.
- Camera and gallery upload flows.
- Tag review and item deletion.
- Today, shuffle, chat refine, and feedback.
- Try-on photo setup, result polling, retry, and quota messaging.
- Avatar Studio selection and history.
- Lookbook/calendar interactions.
- Profile, legal pages, logout, and account deletion.
- Offline, timeout, expired token, 401, 403, 429, and 500 states.

### End-to-end smoke tests

Run against staging or production-like services with real Firebase and storage:

1. Create test account.
2. Complete onboarding.
3. Upload one garment image.
4. Confirm background processing completes.
5. Generate one outfit.
6. Save and mark it worn.
7. Upload a full-body photo.
8. Generate a try-on result.
9. Register and unregister push notifications.
10. Delete the account.
11. Confirm database rows and R2 objects are removed.

### Security tests

- Missing, malformed, expired, and wrong-audience Firebase tokens.
- Development test token against production configuration.
- Cross-user resource enumeration.
- SQL injection payloads in search/filter/admin parameters.
- Oversized, malformed, polyglot, and unsupported image uploads.
- Rate-limit bypass attempts.
- Admin privilege escalation.
- Public access to private image URLs.
- Secret scanning of the repository and build artifacts.
- CORS and security-header verification.

### Performance and resilience tests

- Concurrent authenticated API requests.
- Concurrent uploads within and above limits.
- Worker backlog and retry behavior.
- Slow AI provider response.
- AI provider 429/5xx failures.
- Redis restart.
- API restart during an in-flight job.
- Database restart and recovery.
- Cold-start and warm-start try-on latency.
- Mobile behavior on slow and interrupted networks.

## 7. Date-based execution schedule

### September 10–11 — Release control

- [ ] Confirm scope freeze.
- [ ] Review and push intended commits.
- [ ] Create release branch.
- [ ] Record current blockers.
- [ ] Decide production primary try-on provider.
- [ ] Create launch tracking board/checklist.

### September 12–14 — CI, security, and public trust

- [ ] Add or repair CI jobs.
- [ ] Make backend tests run from a clean Python 3.11 install.
- [ ] Restore Flutter toolchain and run analyzer/tests.
- [ ] Fix Android signing fallback.
- [ ] Enable and verify Android minification.
- [ ] Remove iOS arbitrary-load allowance.
- [ ] Publish privacy, terms, and support pages.
- [ ] Add reviewer/test account or demo wardrobe path.

### September 15–17 — Backend and operations

- [ ] Run fresh and upgrade migration tests.
- [ ] Run auth and ownership isolation tests.
- [ ] Run worker and Redis failure tests.
- [ ] Verify storage deletion.
- [ ] Add readiness checks.
- [ ] Configure monitoring and alerts.
- [ ] Verify backup and restore.
- [ ] Test rollback.

### September 18–20 — AI and full automated test pass

- [ ] Run all backend tests.
- [ ] Run all Flutter tests.
- [ ] Run web/admin builds.
- [ ] Run security and secret scans.
- [ ] Run mocked provider cascade tests.
- [ ] Run live provider smoke tests.
- [ ] Verify quotas and spend caps.
- [ ] Fix all P0/P1 failures.

### September 21–23 — Real-device QA

- [ ] Test supported iOS devices.
- [ ] Test Android 12–15 devices.
- [ ] Test permissions, offline, timeout, and reconnect behavior.
- [ ] Test complete user journey.
- [ ] Verify release builds do not use development configuration.
- [ ] Capture final store screenshots.

### September 24–25 — Store submission

- [ ] Build signed Android AAB.
- [ ] Build signed iOS archive.
- [ ] Complete store metadata and privacy declarations.
- [ ] Upload reviewer credentials/instructions.
- [ ] Submit to Play internal/closed testing.
- [ ] Submit to TestFlight/App Store review.

### September 26–28 — Controlled beta

- [ ] Invite 10–20 users.
- [ ] Monitor crashes, failed jobs, latency, and AI cost.
- [ ] Collect structured feedback.
- [ ] Fix launch-critical issues only.
- [ ] Re-run regression tests after every fix.

### September 29–30 — Final release decision

- [ ] Confirm no open P0/P1 issues.
- [ ] Confirm all release gates pass.
- [ ] Confirm deployed commit equals tested commit.
- [ ] Create final release tag.
- [ ] Run production smoke test.
- [ ] Announce controlled launch or hold release with a documented reason.

## 8. Release gates

The release is blocked if any of the following is true:

- Any critical test is failing.
- Any unauthenticated or cross-user data access is possible.
- Account deletion does not remove user data and private images.
- A release build uses debug signing, localhost, a tunnel, or development credentials.
- Privacy or terms URLs are missing or inaccurate.
- Try-on can make uncapped provider calls.
- Production errors are invisible to the team.
- Backup restore has not been tested.
- The complete smoke journey fails on a real device.
- The exact tested commit is not the deployed/submitted commit.

## 9. Launch metrics for the first week

Track daily:

- Signup completion rate.
- Onboarding completion rate.
- Time to first wardrobe item.
- Time to first generated outfit.
- Wardrobe processing success rate.
- Try-on success rate.
- Try-on median and p95 latency.
- Crash-free sessions.
- API 5xx rate.
- Background-job failure rate and queue depth.
- Average AI cost per active user.
- Number of account-deletion failures.
- Support requests by category.

Suggested early-access thresholds:

- No unresolved critical security or data-loss incidents.
- Crash-free sessions above 99%.
- Critical API 5xx rate below 1%.
- Wardrobe processing success above 95%.
- Try-on success above 90% for supported inputs.
- Every account-deletion request completes successfully or is manually remediated within one business day.

## 10. Final launch decision

On September 29, review the release gates, automated test results, device matrix, beta metrics, monitoring, and store status.

Choose one:

### Launch

All release gates pass, beta users complete the core journey, and store distribution is available.

### Controlled early access

The product is technically safe and usable, but store review or one non-critical operational item is still pending. Limit invitations and keep monitoring active.

### Hold

Any P0/P1 issue remains, data deletion is unverified, release signing is incomplete, or the core journey fails.

## 11. Required release artifacts

- Tested release commit and Git tag.
- Backend test report.
- Flutter analyzer/test report.
- Web/admin build logs.
- Signed Android AAB.
- Signed iOS archive.
- Device QA checklist and results.
- Production smoke-test record.
- Security/secret-scan result.
- Migration and rollback record.
- Backup/restore record.
- Privacy and terms URLs.
- Store metadata and reviewer instructions.
- Known-issues and support playbook.
