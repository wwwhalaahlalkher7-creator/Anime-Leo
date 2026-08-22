# Anime Leo v1.32.0 — Live Episode Schedule

## Sidebar
- Replaced the Episode Schedule placeholder with a real screen.
- Schedule is driven by the live broadcast data source rather than completed D1 records.
- Day selector starts on the current weekday and supports the full week.
- Each day is sorted by broadcast time.

## Backend
- Added `GET /api/anime/schedule?day=monday..sunday`.
- Uses Jikan schedule data with `filter=airing` and `sfw=true`.
- Response keeps the existing Anime API shape so cards can open the normal Anime Details screen.
- Added short client caching and graceful stale-cache behavior.

## UX
- Shows anime poster, title, broadcast time, next-episode label and airing status.
- Tapping an item opens the same enhanced Anime Details page.
- Pull-to-refresh and retry states are included.
- No episode number is fabricated when the provider does not expose an authoritative next-episode number.
