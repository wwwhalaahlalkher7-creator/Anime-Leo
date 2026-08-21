# V1.9 — Production Hardening

V1.9 is cumulative from V1.8.

## Backend
- Correct D1 catalog pagination with `LIMIT + 1`.
- Correct `CatalogResult.source` union for database/provider merges.
- Preserved provider fallback and deduplication.
- Added migration `0002_catalog_indexes`.
- Added `X-Request-ID` to API responses.
- Added `GET /api/health?deep=true` to check D1 and Jikan provider.
- Added `MAINTENANCE_MODE` and `MINIMUM_APP_VERSION` variables.
- Improved maintenance and rate-limit behavior.
- Ads/video remain disabled; analytics remains disabled by default.

## Flutter
- App version is `1.9.0+1`.
- API client sends a lightweight request ID for troubleshooting.
- Backend-only provider architecture remains unchanged.

## D1
Database ID:
`4268654f-1c22-49f0-9d71-32ca62c95051`

Migration layout:
`migrations/0001_initial/migration.sql`
`migrations/0002_catalog_indexes/migration.sql`

## Cloudflare Workers Builds
Repository root must contain `backend/`.
For a monorepo-style repository:
- Root directory: `backend` (no leading slash)
- Build command: `None`
- Deploy command: `npx wrangler deploy`

## Smoke test
After deployment:
`API_BASE_URL=https://YOUR-WORKER.workers.dev/api npm run test:smoke`
