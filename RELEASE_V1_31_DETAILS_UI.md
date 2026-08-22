# Anime Leo v1.31.0 — Enhanced Anime Details UI

## UI
- Redesigned anime details screen to follow the supplied reference interface.
- Hero background + poster + Arabic/English titles.
- Metadata chips for year, status, episode count and type.
- Approximate next-episode countdown using provider broadcast day/time when available.
- Mature-content warning when the provider rating indicates adult content.
- Primary watch/download actions and compact favorite/list/rating/background/review/comment actions.
- MyAnimeList-style score/rank/member card.
- Structured information card for source, duration, airing dates, studio and age rating.
- Synopsis with Arabic translation support and expand/collapse.
- Trailer card.
- Tabs for characters, related works and similar anime.
- Improved episode cards, download actions and pagination.

## API/detail payload
- Jikan detail requests now use `/anime/{id}/full`.
- Provider normalization exposes source, duration, airing dates, rating, rank, members, popularity, season, studio names, trailer/background images, broadcast schedule, characters, relations and recommendations.
- Existing D1/catalog behavior remains backward compatible; fields unavailable in the database are simply omitted from the enhanced UI.

## Resilience
- Existing details/episodes fallback behavior is preserved.
- Optional enhanced fields are rendered only when available.
