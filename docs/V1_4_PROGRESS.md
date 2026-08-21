# V1.4 — Pagination, Offline Data & Provider Abstraction

## Implemented
- Full Anime object persistence for Favorites.
- Full Anime + episode persistence for Watch History.
- Favorites and history survive app restarts.
- Bounded watch history (30 entries).
- Search pagination with infinite scrolling.
- Episode pagination with "load more".
- Repository returns an `AnimePage` with `hasNextPage`.
- Existing API cache remains active.
- Existing image caching remains active.
- UI now displays persisted favorites and history.

## Offline behavior
- Home and anime details can fall back to cached API responses.
- Favorites/history are fully local.
- Search still requires network because search pages are not persisted yet.

## Architecture
UI -> Repository -> API Service
             -> Cache
             -> Local Storage

This makes the UI independent from the current API provider.

## Next recommended stage — V1.5
1. Create a backend API of our own.
2. Add provider adapters behind the backend.
3. Move API keys/provider details off the app.
4. Add server-side caching and rate limiting.
5. Add legal/authorized video-source integration.
6. Add analytics and ad mediation only after the core viewing flow is stable.
