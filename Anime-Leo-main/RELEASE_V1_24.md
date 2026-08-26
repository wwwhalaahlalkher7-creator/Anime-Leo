# Anime Leo V1.24.0

## Changes
- Replaced the bottom navigation destinations with three content sections: Anime, Manga & Manhwa, and Animated Shows.
- Kept favorites, watch history, settings, and other utilities in the side drawer.
- Removed the old Animation List item from the side drawer.
- Added Arabic-capable MangaDex catalog endpoint (`/api/manga`) using titles with Arabic chapter availability, with D1 caching and scheduled background sync.
- Added Arabic-localized TMDB animation/cartoon catalog endpoint (`/api/animation`) with D1 caching and scheduled background sync. It requires `TMDB_API_TOKEN` in Cloudflare.
- Added external-source details pages for manga and animated shows; Anime Leo does not proxy their media.
- Made the main top header pinned so the menu and search controls remain visible while scrolling.
- Added generic Arabic synopsis translation caching for new content types.
- Updated app/backend version to 1.24.0 / 1.24.0.0.

## Provider configuration
Set the TMDB TMDB API Read Access Token as a Cloudflare secret before deployment:

```bash
wrangler secret put TMDB_API_TOKEN
```

MangaDex requires no project secret for the public catalog endpoint used here.
