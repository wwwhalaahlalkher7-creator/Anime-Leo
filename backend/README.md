# Anime Leo Backend

Cloudflare Worker API + D1 catalog for Anime Leo.

## Runtime architecture

```text
Flutter
   │
   ▼
Cloudflare Worker
   ├─ Edge cache
   ├─ Anonymous rate limiting
   ├─ Catalog service ── D1
   ├─ Provider manager
   │    ├─ Jikan
   │    └─ AniList fallback
   ├─ Manga/Animation catalog adapters
   └─ Optional authorized episode/source adapters
```

The video layer is legal-only and disabled until an authorized provider is configured. The backend does not scrape, proxy, or redistribute unauthorized video.

## Local development

```bash
npm install
npm run dev
```

## D1

```bash
npm run db:create
npm run db:migrate
```

The repository already contains the migration history. Keep the existing database binding when deploying to the configured Worker.

## Deployment

```bash
npm run deploy
```

## Smoke tests

After deployment:

```bash
API_BASE_URL=https://YOUR-BACKEND/api npm run test:smoke
```

The smoke suite checks health/config, anime catalog endpoints, episode behavior, content catalogs, and catalog diagnostics.

## Important configuration

- `UPSTREAM_BASE` — Jikan API base.
- `ANILIST_BASE` — AniList GraphQL endpoint.
- `PROVIDER_ORDER` — provider priority, default `jikan,anilist`.
- `PROVIDER_TIMEOUT_MS` — per-provider timeout before fallback, default `8000`.
- `CACHE_SECONDS` — Worker edge-cache duration.
- `TMDB_API_TOKEN` — optional secret for the animation catalog.
- `ARABIC_EPISODE_*` — optional authorized Arabic episode provider.
- `EXTERNAL_SOURCE_*` — optional authorized external source metadata.

Never put provider secrets in Flutter code or the APK.
