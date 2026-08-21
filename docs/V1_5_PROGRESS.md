# V1.5 — Own Backend Foundation

## Implemented

### Mobile
- `AnimeDataSource` abstraction.
- App no longer hardcodes Jikan as its public API.
- API base URL is controlled by `--dart-define=API_BASE_URL`.
- Added backend health check in Settings.
- Added monetization abstraction and safe No-Op ad service.
- Ads remain disabled by default.
- Existing local persistence, cache, pagination and image cache remain active.

### Backend
A Cloudflare Worker has been added under `/backend`.

It provides:
- `/api/health`
- `/api/config`
- `/api/top/anime`
- `/api/anime`
- `/api/anime/:id/full`
- `/api/anime/:id/episodes`

The backend currently proxies Jikan and caches successful responses.

## Architecture

```text
Flutter Android / Web
          |
          v
   AnimeDataSource
          |
          v
   AnimeApiService
          |
          v
 Anime Platform Backend
          |
       Cache
          |
          v
     Data Provider
```

The provider can be replaced later without updating the client UI.

## Important
This backend is a metadata API foundation. It is not a video piracy mechanism and does not supply unauthorized video streams/downloads.

## V1.6 target
- Add a proper database for app-owned data.
- Add server-side catalog normalization.
- Add provider adapters.
- Add user-independent analytics events.
- Add remote feature flags.
- Add a legitimate video provider interface.
- Integrate a real ad SDK only after the app is stable and the chosen ad network supports the target region.
