# Anime Leo V1.28 — Current Progress

Updated: 20 August 2026

## Completed in this working tree

- API base URL has a single source of truth in `lib/config/api_config.dart`.
- Flutter client API version is `1.28`.
- Anime repository uses the `AnimeDataSource` interface for MAL → AniList mapping; no runtime type cast to `AnimeApiService`.
- Watch progress, 90% completion, subtitle preference, quality preference, source selection, and next-episode countdown are implemented in the player path.
- Android external playback now uses an implicit `ACTION_VIEW` intent with `video/*`, allowing Android to present compatible installed video applications.
- CI no longer deletes the Flutter `test/` directory and now runs `flutter test` after `flutter analyze`.
- Backend smoke checks include Anivexa route reachability.
- Wrangler compatibility date is `2026-08-20`; the previous `mapper.js` export error and `smartcache.js` Cloudflare filesystem path issue have already been addressed in the source tree.

## Still release-blocking

- Flutter/Android CI must actually pass `flutter analyze`, `flutter test`, and APK build.
- Cloudflare deployment must pass from GitHub Actions; local static inspection cannot prove deployment success.
- The V1.28 project owner has designated ani-cli-arabic as an authorized production playback source; deployment and real-device playback still require verification.
- Real-device playback, PiP, subtitle loading, source fallback, and external-player behavior still require Android verification.
- Notifications require an actual delivery pipeline (for example FCM + backend) before being described as active.

## Release gate

Do not label the build `Released` until all Definition-of-Done checks in the repair specification pass.

## Source integration update — 20 Aug 2026

- Primary playback adapter wired to **ani-cli-arabic**.
- **MyDubList** Arabic-dub availability integrated as metadata with CC BY 4.0 attribution.
- V1.28 remains subtitle-first; MyDubList does not enable an audio-track selector.
- Playback endpoint: `/api/playback/:malId/:episode`.
- Dub metadata endpoint: `/api/dubs/mydublist/:malId`.
- Existing Anivexa chain remains as a resilience fallback.
