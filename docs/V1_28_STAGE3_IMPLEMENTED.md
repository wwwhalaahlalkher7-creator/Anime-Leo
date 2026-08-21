# Anime Leo V1.28 Stage 3

Implemented:
- Player subtitle overlay for WebVTT/SRT-like timed cues.
- Arabic/English subtitle preference is respected when tracks are supplied by the provider.
- Previous/Next episode navigation is passed from the episode list.
- Automatic next-episode countdown at 90% completion, with cancel action.
- Quality preference is applied when switching sources as well as on initial load.
- Watch progress is still saved locally and completion threshold remains 90%.
- Source picker remains available when multiple authorized providers return playable assets.

Still pending until a real Flutter/Android build environment is available:
- `flutter analyze`
- `flutter test`
- Android device playback verification
- native external-player package discovery (the current project has no checked-in Android host; URL launching remains the safe fallback).
