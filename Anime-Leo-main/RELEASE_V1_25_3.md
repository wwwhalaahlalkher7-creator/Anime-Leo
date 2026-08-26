# Anime Leo V1.25.3

- Expanded TMDB animation catalog with category filters: Popular, Japanese Anime, Global Animation, Top Rated, and Latest.
- Added page-by-page "Load more" pagination for animation catalogs.
- Removed the previous Japan exclusion that caused the catalog to show only a small subset of animation.
- TMDB animation metadata is requested in `en-US`.
- External catalog titles are displayed in English in both Arabic and English app interfaces.
- MangaDex titles continue to prefer English titles where available.
- TMDB API token remains a Cloudflare Worker secret; it is not embedded in the APK.
