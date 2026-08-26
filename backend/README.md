# Anime Platform Backend — V1.17.0

V1.9 changes the backend from a pure upstream proxy into a small catalog backend with Cloudflare D1 persistence and provider adapters.

## Architecture

```text
Flutter
   |
   v
Cloudflare Worker API
   |
   +---- Edge Cache
   |
   +---- Rate Limit (D1, anonymous IP hash)
   |
   +---- Catalog Service
   |       |
   |       +---- Cloudflare D1
   |       |
   |       +---- Provider Adapter
   |              |
   |              +---- JikanProvider (metadata)
   |
   +---- Analytics (disabled by default)
   |
   +---- VideoProvider interface (NoOp by default)
```

## D1 setup

From `backend/`:

```bash
npm install
npx wrangler login
npm run db:create
```

`db:create` prints a database ID. Put that ID into `wrangler.toml`:

```toml
[[d1_databases]]
binding = "DB"
database_name = "anime-platform-db"
database_id = "4268654f-1c22-49f0-9d71-32ca62c95051"
migrations_dir = "migrations"
```

Then apply the migration remotely:

```bash
npm run db:migrate
```

Finally deploy:

```bash
npm run deploy
```

## Endpoints

- `GET /api/health` — Worker + D1 health.
- `GET /api/diagnostics/catalog` — Read-only D1/catalog diagnostics; does not call the provider.
- `GET /api/config` — Remote feature flags and limits.
- `GET /api/top/anime` — Catalog-backed top anime, provider fallback on cache miss/empty catalog.
- `GET /api/anime?q=naruto&page=1&limit=12` — Catalog-backed search with provider fallback.
- `GET /api/anime/:id/full` — Normalized anime details.
- `GET /api/anime/:id/episodes?page=1&limit=24` — Normalized episodes.
- `GET /api/anime/:id/episodes/:episode/video` — Licensed video contract; currently disabled and returns 404.
- `POST /api/events` — Anonymous analytics endpoint; disabled by default.
- `POST /api/admin/catalog/seed` — Protected operator-only catalog bootstrap using Jikan individual details.

## Current flags

```json
{
  "ads": false,
  "analytics": false,
  "video": false
}
```

Analytics can only be enabled by changing `ANALYTICS_ENABLED` in Worker configuration after the client and privacy review are ready.

## Provider rule

Flutter never talks to Jikan directly. The Worker owns provider selection and normalization. A future provider implements the `AnimeProvider` interface without changing the Flutter data contract.

## Video rule

No scraping or redistribution source is included. `NoOpVideoProvider` is the only V1.9 implementation. A future implementation must point to a source the project is authorized to use.


## V1.10.1 notes
- Added `/api/diagnostics/catalog` to diagnose production D1/catalog state before changing provider architecture.
- The diagnostic endpoint does not expose user data or call Jikan.
- Minimum app version remains `1.9.0`.

## V1.9 notes
- D1 uses the configured database ID and nested migration pattern.
- Run `npm run test:smoke` with `API_BASE_URL` set after deployment.


## V1.10.2 catalog bootstrap

Jikan search/top can fail independently when MyAnimeList is unavailable. The bootstrap therefore uses a small curated list of stable MAL IDs and fetches individual anime details from `/anime/{id}`.

Set the Worker secret `CATALOG_SEED_TOKEN` and deploy. Then run the protected seed endpoint in small batches using `offset` and `limit`. Use the protected seed endpoint described above and follow the current deployment workflow.

The Flutter client does not need a contract change for V1.10.2.

## V1.17.0 — Monetization Preparation

- Monetization remains disabled.
- No ad SDK, ad network, payment flow, or analytics collection is enabled.
- The mobile client contains a provider-neutral monetization/consent contract for future integration.
- Video remains disabled behind the legal-only provider contract.
- The backend exposes monetization readiness in `/api/config` without enabling ads.

## V1.12.0 — Catalog Reliability + D1

V1.12.0 hardens the catalog/D1 boundary without changing the existing architecture.

- D1 remains the primary catalog source.
- Search, top, details, and episodes D1 read failures are classified as `catalog_database_unavailable` and return HTTP 503 instead of a generic 500.
- Jikan failures continue to use available D1 data with graceful `degraded=true` responses.
- No provider manager or multi-provider implementation is introduced yet.
- The existing D1 database ID remains unchanged.
- Ads, analytics, and video remain disabled.

## V1.20.0.1 — Arabic episode provider contract

- Added `ArabicEpisodeProvider` as an optional backend adapter for an authorized Arabic episode catalog/API.
- Jikan remains the metadata/episode fallback.
- Arabic availability is merged by episode number and returned as `sources` with `language: "ar"`.
- Arabic provider metadata is not persisted in the generic D1 `episodes` table because provider availability can change independently.
- No third-party scraper, anti-bot bypass, or video extraction is included.
- Configure `ARABIC_EPISODE_BASE`, `ARABIC_EPISODE_PROVIDER_NAME`, and optionally `ARABIC_EPISODE_API_KEY` only when an authorized provider is available.


## V1.22.0 — Automatic catalog synchronization

The Worker now expands the D1 catalog in the background using Cloudflare Cron. It does not wait for a mobile request and does not require manually growing the seed list.

Two persistent Jikan scan streams are maintained:
- `popularity`: broad catalogue coverage.
- `latest`: newer/recently started titles.

The scan cursor is stored in `catalog_sync_state`, so each scheduled run resumes from the previous page. Existing rows are updated with an upsert and duplicate external IDs are not created.

Default schedule:
```text
0 */6 * * *
```

Runtime configuration:
```toml
CATALOG_SYNC_ENABLED = "true"
CATALOG_SYNC_PAGES = "5"
CATALOG_SYNC_LIMIT = "24"
```

Diagnostics:
```text
GET /api/diagnostics/catalog-sync
```

Immediate protected run (uses the existing `CATALOG_SEED_TOKEN`):
```text
POST /api/admin/catalog/sync
Authorization: Bearer YOUR_CATALOG_SEED_TOKEN
```

## V1.24.0 content providers
- `/api/manga` uses MangaDex and filters for titles with Arabic translation availability. Results are cached in D1 and the scheduled catalog sync walks additional pages automatically.
- `/api/animation` uses TMDB's Arabic localization for animated TV shows. Configure the TMDB API Read Access Token as a Cloudflare secret named `TMDB_API_TOKEN`. Results are cached in D1 and included in scheduled sync when the secret is configured.

Before deployment of V1.24.0, apply the new D1 migration:

```bash
npx wrangler d1 migrations apply anime-platform-db --remote
```

Then configure the TMDB token if desired:

```bash
npx wrangler secret put TMDB_API_TOKEN
```

## V1.25.1 content endpoints

- `GET /api/manga/{mangaId}/chapters?language=ar&page=1&limit=100` — lists available Arabic MangaDex chapters.
- `GET /api/manga/chapter/{chapterId}` — resolves the MangaDex@Home page URLs for a chapter. Anime Leo does not proxy or store the image bytes.

These endpoints are intended for the in-app MangaDex reader. Availability and rights of individual titles remain governed by MangaDex and the relevant publisher/translation group.
