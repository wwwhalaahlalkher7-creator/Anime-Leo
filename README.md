# Anime Leo

Flutter Android client and Cloudflare Worker backend for Anime Leo.

## Current version

`1.28.0-beta.1+15`

The canonical version lives in `VERSION`. Run `./tool/sync_version.sh` after changing it to synchronize Flutter and Worker version metadata.

## Architecture

```text
Flutter
 ├─ Local state (favorites / watch history / settings)
 ├─ Persistent API cache (stale-while-revalidate)
 ├─ Jikan metadata client
 └─ Manga / Animation catalog client
          │
          ▼
Cloudflare Worker API
 ├─ Edge cache + rate limiting
 ├─ D1 catalog
 ├─ Provider manager (Jikan → AniList fallback)
 └─ Optional authorized content providers
```

Anime metadata currently uses Jikan directly from the Flutter client. The backend remains responsible for catalog-backed Manga/Animation features and optional authorized integrations.

## Development

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

For a production Worker endpoint:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-BACKEND/api
```

API secrets must remain in backend/Cloudflare configuration and must never be embedded in the APK.

## Backend

See `backend/README.md` for Worker, D1, deployment, and smoke-test instructions.
