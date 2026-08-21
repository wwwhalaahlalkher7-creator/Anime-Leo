# V1.11.0 Progress — Catalog Reliability + D1

## Goal
Strengthen the V1.10.2 catalog/D1 layer without changing the architecture.

## Changes
- Added an explicit `CatalogDatabaseError` boundary around catalog reads.
- Search, Top, Details, and Episodes D1 read failures now return a controlled `503 catalog_database_unavailable` response instead of a generic `500`.
- Provider failures remain graceful and continue to use available D1 data with `degraded=true`.
- Existing V1.10.2 bootstrap, authentication, schema, and D1 ID are preserved.
- Smoke tests now include catalog diagnostics and episodes verification.

## Intentionally not included
- No multi-provider manager.
- No video provider.
- No ads.
- No analytics activation.
- No Flutter architecture change.
- No D1 ID change.

## Acceptance
1. `/api/health` returns 200.
2. `/api/config` returns 200 and reports app version 1.11.0.
3. `/api/diagnostics/catalog` returns 200.
4. `/api/top/anime?page=1&limit=3` returns a valid catalog response.
5. `/api/anime?q=naruto&page=1&limit=3` returns a valid catalog response.
6. `/api/anime/20/full` returns D1 data when present.
7. `/api/anime/20/episodes?page=1&limit=3` returns a valid response; an empty/degraded result is acceptable while episode rows are not populated and Jikan is unavailable.
8. A real D1 catalog read failure returns controlled 503 rather than generic 500.
