# V1.14.0 — UI/UX Stabilization

## Goal
Stabilize the Flutter presentation layer on top of the V1.13.0 mobile↔backend contract without changing D1, backend architecture, provider manager, or API routes.

## Changes
- Added consistent loading, empty, retry, and degraded-state UI components.
- Improved search debounce, stale-request protection, pull-to-refresh, duplicate suppression, and infinite pagination UX.
- Improved anime details with resilient image loading, metadata chips, synopsis fallback, retry behavior, and episode pagination based on backend pagination.
- Improved episode loading/error/empty states and preserved watch history writes.
- Standardized cached image rendering for hero, details, history, and cards.
- Added RTL application direction for the Arabic UI.
- Preserved Favorites and Watch History using the existing local storage keys.
- Ads, analytics, and video are explicitly disabled for the V1.14.0 release.
- Backend files, D1 migrations, API routes, provider manager, and architecture are unchanged from V1.13.0.

## Versioning
- Mobile app: `1.14.0+1`
- Backend: remains `1.13.0`
- API: `v1`
- D1: unchanged

## Validation target
- `flutter pub get`
- `flutter analyze`
- `flutter test`
- Android debug build
- `/api/health`, `/api/config`, `/api/top/anime`, `/api/anime`, `/api/anime/:id/full`, `/api/anime/:id/episodes`
- Offline/cache fallback for top, search, details, and episodes
- Favorites and Watch History persistence
- Ads=false, Analytics=false, Video=false
