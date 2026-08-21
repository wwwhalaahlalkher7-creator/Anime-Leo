# Anime Leo V1.21.0 — Catalog and Arabic synopsis update

## Changes
- English anime titles are used everywhere in the mobile UI.
- Translation button and separate translation box are removed.
- Arabic mode automatically prepares the synopsis in Arabic and never shows the English synopsis first.
- Home loads up to six catalog pages.
- Backend provider chain is `jikan,anilist`; AniList is used automatically when Jikan fails.
- AniList records use negative internal IDs so they cannot collide with Jikan/MAL IDs.

## Deployment
1. Upload the release ZIP using the existing Termux deployment workflow.
2. From `backend/`, run:
   `npm install`
   `npm run db:migrate`
   `npm run deploy`
3. Verify `/api/health?deep=true`, `/api/config`, and `/api/top/anime?page=1&limit=24`.
4. Build the APK with the deployed API URL.

No API key is required for the AniList public GraphQL endpoint.
