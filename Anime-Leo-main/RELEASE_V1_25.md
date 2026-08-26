# Anime Leo v1.25 — API Integration Foundation

## Changes
- Centralized Flutter API configuration in `lib/config/api_config.dart`.
- Added backend environment template at `backend/.dev.vars.example`.
- Added `docs/API_INTEGRATION_GUIDE.md`.
- API provider credentials remain backend-only.
- Video integration is provider-agnostic and requires an authorized source before enabling playback.
- Subtitle integration can be enabled independently.

## Verification
Run:

```bash
flutter pub get
flutter analyze
flutter test
```

Then build with the production Worker URL using `--dart-define=API_BASE_URL=...`.
