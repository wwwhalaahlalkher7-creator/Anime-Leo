# V1.2 — Real Anime API

## Implemented
- Real API integration through Jikan v4.
- `AnimeApiService` isolates HTTP calls.
- `AnimeRepository` isolates mapping/business access.
- Home now loads real top anime.
- Search now performs debounced real API searches.
- Details now loads fresh anime details.
- Episodes now load from the API.
- Loading, empty, error and retry states were added.
- The API base URL is configurable, so a future backend can replace Jikan without changing the UI.

## Current provider
Jikan v4:
https://api.jikan.moe/v4

Jikan is an unofficial MyAnimeList API. It is read-only and has rate limits, so the app should not hammer it with requests.

## Important
This API supplies anime metadata. It does NOT provide the streaming rights or a legal video source for episodes. The player remains a shell until an authorized video provider/CDN is selected.

## Next
- Add persistent favorites/history.
- Add image caching.
- Add API cache/TTL.
- Add pagination for search/episodes.
- Then connect the backend/proxy so the mobile app does not depend directly on the public provider.
