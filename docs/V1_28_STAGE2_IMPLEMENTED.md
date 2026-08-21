# V1.28 Stage 2 — Playback Pipeline

Implemented in this working tree:

- Catalog/MAL IDs are resolved to AniList IDs through the backend before Anivexa playback.
- The player now queries the Anivexa episode catalog and tries every provider already wired into the project, in priority order.
- Playback requests are explicitly `sub` only.
- Provider failures are isolated so one unavailable provider does not block the others.
- Multiple playable provider results are exposed to the player as selectable sources.
- Saved default quality is used when a matching quality label is returned.
- Anime episode tiles now enter the in-app playback flow instead of defaulting to external source pages.
- Existing provider adapters remain the source implementation; no new provider scraping code was added.

Flutter compilation remains unverified in this environment because the Flutter SDK is not installed here.
