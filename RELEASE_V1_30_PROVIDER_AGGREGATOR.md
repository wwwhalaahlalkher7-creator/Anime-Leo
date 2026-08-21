# Anime Leo V1.30 — Provider Aggregator

## What changed

- Added `backend/src/provider-aggregator.ts`.
- Jikan and AniList metadata providers are queried concurrently.
- Results are deduplicated by `canonicalId`, not by provider-native IDs.
- When AniList resolves a MAL ID, the normalized record exposes the MAL ID as `externalId` so negative AniList IDs never leak into playback paths.
- Episode metadata is merged by episode number and source metadata is deduplicated.
- Added `GET /api/providers` for provider health and aggregation diagnostics.
- Playback remains behind the `LicensedVideoProvider` contract; no unofficial video provider is enabled by this change.

## Provider verification

`/api/providers` reports the health of configured metadata providers. A provider failure does not make the whole aggregator fail when at least one provider succeeds.

## ID policy

- `mal:<id>` / `malId`: playback identity.
- `anilist:<id>` / `anilistId`: AniList/Anivexa identity.
- provider-native IDs remain provider-scoped.

## CI checks

GitHub Actions should run:

1. `flutter analyze`
2. `flutter test`
3. backend smoke tests including `/providers`
4. backend deployment
