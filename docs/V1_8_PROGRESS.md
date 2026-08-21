# V1.8 — Production Foundation + V1.7 Fixes

## What changed
- D1 database binding is configured with the supplied production database ID.
- Nested D1 migrations are explicitly discovered with `migrations_pattern = "migrations/*/migration.sql"`.
- Backend version and minimum app version are 1.8.0.
- Catalog search/top now merge partially cached D1 results with provider fallback and deduplicate by external ID.
- Episode pages now fall back to the provider when a cached page is incomplete, including page > 1.
- Jikan provider User-Agent updated to 1.8.
- Added a repeatable API smoke-test script.
- Ads, analytics and video remain disabled.
- Flutter architecture remains backend-only; no direct Jikan dependency is introduced.

## D1
The configured database ID is:

`4268654f-1c22-49f0-9d71-32ca62c95051`

The migration layout is intentionally kept as:

`migrations/0001_initial/migration.sql`

Cloudflare D1 requires the explicit `migrations_pattern` for this nested layout.

## Smoke test
After deployment:

`API_BASE_URL=https://YOUR-WORKER.workers.dev/api npm run test:smoke`

The script checks health, config, top anime and search.

## Important
Do not commit Cloudflare API tokens, passwords, or other secrets.
