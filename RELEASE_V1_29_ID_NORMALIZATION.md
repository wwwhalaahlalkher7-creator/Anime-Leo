# Anime Leo V1.29 — Content ID Normalization

## Purpose

Provider IDs are no longer treated as interchangeable. The app now carries a canonical content identity plus provider-specific IDs.

## Identity contract

- `canonicalId`: stable identity, preferring `mal:<MAL_ID>` when a MAL mapping exists.
- `malId`: MyAnimeList/Jikan ID. This is the only ID accepted by the primary playback endpoint.
- `anilistId`: AniList ID. This is used by Anivexa/AniList operations.
- `providerId` / `provider`: the native provider identifier and its source.
- `id` / `externalId`: retained for backward compatibility with existing catalog and D1 records.

## Provider behavior

- Jikan emits `malId` and `canonicalId = mal:<id>`.
- AniList requests `idMal` and emits a MAL canonical identity when available; otherwise it remains `anilist:<id>`.
- Existing negative AniList external IDs are normalized as `anilist:<id>` and are never treated as MAL IDs.
- MyDubList and ani-cli-arabic continue to receive MAL IDs only.
- Anivexa continues to receive AniList IDs only.
- MangaDex IDs remain independent manga/chapter IDs and are not placed in `Anime.id`.

## Playback safety

Playback now uses `malId` when available. A negative/provider-specific ID can no longer be sent to `/api/playback/{malId}/{episode}` as if it were a MAL ID.

## Fallback safety

AniList details can now resolve a positive MAL ID using AniList's `idMal` lookup. This keeps metadata fallback functional even when Jikan is unavailable.
