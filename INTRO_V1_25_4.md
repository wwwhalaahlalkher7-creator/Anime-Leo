# Anime Leo V1.25.4 — Intro + Startup Preload

## What changed
- Added `video_player` dependency.
- Added `IntroScreen` with fullscreen vertical intro playback.
- Added Anime Leo logo overlay during the final 1.2 seconds of the intro.
- Added a 750 ms logo hold before entering Home.
- Added `StartupPreloader` to warm the top-anime and manga caches while the intro plays.
- Pre-caches up to 12 anime poster images after the API data arrives.
- Starts the Flutter UI immediately instead of waiting for startup network/config calls.
- Added the new lion app icon and logo assets.
- Version bumped to `1.25.4+12`.

## Important
The included `assets/intro/anime_leo_intro.mp4` is the current working intro render from the AI generation stage. It still contains the generator watermark. Replace that single file later with the clean final intro video; no Dart code changes are required as long as the filename remains the same.

## Build
The existing GitHub Actions workflow already runs `dart run flutter_launcher_icons`, so the new `assets/anime_leo_icon.png` will be used for the launcher icon automatically.
