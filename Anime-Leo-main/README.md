# Anime Leo

Flutter Android client for the Anime Leo platform.

## Run

```bash
flutter pub get
flutter run
```

## Release build

```bash
flutter build apk --release
```

The app uses the backend API layer by default and can fall back to cached data when available.
Do not put API secrets in the mobile app.

## Backend

The `backend/` directory contains the Cloudflare Worker API and D1 migrations.

The mobile client receives the backend URL at build time:

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://YOUR-BACKEND/api
```

## Current release — V1.24.0

- Anime, Manga & Manhwa, and Animated Shows are available as the main content sections.
- The top header remains pinned while scrolling.
- Manga uses the Arabic-availability catalog from MangaDex.
- Animated Shows use the Arabic-localized TMDB catalog when `TMDB_API_TOKEN` is configured in Cloudflare.
- External-source pages are opened externally; the app does not proxy or redistribute third-party video.
- Ads, analytics, and video playback remain disabled by default.
