# V1.3 — Persistence, Cache & Image Performance

## Implemented
- Favorites persisted with SharedPreferences.
- Watch history persisted with SharedPreferences.
- API cache with timestamps and TTL.
- Home cache: 15-minute fresh cache.
- Stale Home cache fallback up to 7 days when the API is unavailable.
- Anime details cache for 12 hours.
- CachedNetworkImage for image caching.
- Home pull-to-refresh now forces a fresh API request.
- Search keeps debouncing and uses pagination-ready repository methods.

## Important limitation
Favorites/history currently persist IDs and episode numbers, but the complete Anime object is not yet persisted. This is intentional for this stage.

## Next
- Persist lightweight Anime metadata for favorites/history.
- Add paginated search UI.
- Add paginated episodes.
- Add provider abstraction / backend proxy.
- Add offline-aware repository states.
- Then move toward the production backend.
