# Anime Leo API Integration Guide

## Current boundary

Anime metadata currently uses this path:

```text
Flutter AnimeRepository
  ↓
AnimeApiService
  ↓
Jikan API
```

Catalog-backed features use the Worker:

```text
Flutter catalog services
  ↓
Cloudflare Worker API
  ↓
D1 / provider adapters
```

This split is intentional. It prevents an outage in the D1 catalog path from making the main anime metadata path unusable.

## API base URL

Pass the Worker URL at build time when building catalog-backed features:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-WORKER.example.workers.dev/api
```

Do not hard-code environment-specific URLs in screens.

## Secrets

Never place provider credentials in Flutter or the APK. Keep secrets in Cloudflare Worker configuration.

Examples include:

- `TMDB_API_TOKEN`
- authorized episode/source provider credentials

## Adding an integration

1. Identify the owning boundary: direct mobile metadata or Worker-backed catalog.
2. Add an adapter at that boundary.
3. Normalize the response into Anime Leo models.
4. Add the endpoint/contract only if the Worker owns the integration.
5. Add error, timeout, and fallback handling.
6. Update the relevant repository/service.
7. Run `flutter analyze`, `flutter test`, and the backend smoke tests.

## Video

Video playback remains disabled until an authorized provider is available. The backend must not scrape, bypass access controls, proxy, or redistribute unauthorized streams.
