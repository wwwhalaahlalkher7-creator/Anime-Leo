# Anime Leo V1.25.2

## MangaDex catalog reliability

- Fixed the MangaDex catalog request to use a documented stable ordering (`followedCount`) instead of the previous rating ordering.
- Requests now require Arabic availability and available chapters while keeping content rating `safe`.
- Added a small retry for MangaDex rate-limit/server errors.
- MangaDex public catalog access still requires no API token in this project.
- Arabic chapter reading remains served through MangaDex APIs; Anime Leo does not host manga image bytes.

V1.25.3 update: TMDB animation catalog expanded with categories, pagination/load-more, and English external titles in both Arabic and English interfaces.
