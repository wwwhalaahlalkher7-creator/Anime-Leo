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

## Current release — V1.29.0+15

- Anime, Manga & Manhwa, and Animated Shows are available as the main content sections.
- The top header remains pinned while scrolling.
- Manga uses the Arabic-availability catalog from MangaDex.
- Animated Shows use the Arabic-localized TMDB catalog when `TMDB_API_TOKEN` is configured in Cloudflare.
- V1.29 playback and manual offline downloads use the authorized `ani-cli-arabic` adapter; MyDubList supplies Arabic-dub availability metadata (CC BY 4.0).
- Manual downloads are exposed only when the provider returns a direct download URL. Completed anime can queue the whole series; movies can download directly. No auto-download.
- Ads and analytics remain disabled by default. The V1.28 backend exposes the episode/source integration used by the release.


## Embedded Anivexa API

The Anime Leo backend now embeds the Anivexa provider layer. It is exposed from
the same Worker under `/api/anivexa`, so the mobile app does not need a second
backend deployment.

- `GET /api/anivexa/episodes/:anilistId`
- `GET /api/anivexa/episodes/:provider[/:provider...]/:anilistId`
- `GET /api/anivexa/watch/:provider/:anilistId/:sub|dub/:episode`

The original Anime Leo catalog endpoints remain unchanged.


## Backend deployment in CI

The backend is deployed separately from the APK build. The GitHub repository must contain these Actions secrets:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

The `Deploy Anime Leo Backend` workflow applies D1 migrations, deploys the Worker, and runs the backend smoke test. This is required when backend routes change; building a new APK alone does not update the live Worker.

## V1.28 source integrations

- Playback: `ani-cli-arabic` API adapter.
- Arabic-dub availability metadata: MyDubList (CC BY 4.0).
- MyDubList attribution: `Dub data © MyDubList - https://mydublist.com - (CC BY 4.0)`
- V1.28 remains subtitle-first; dub audio tracks are not exposed in the player yet.
