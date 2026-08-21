# Anime Platform V1.1

## Implemented
- Modern dark-first Material 3 UI.
- Home hero + popular + recommendations.
- Anime cards with favorites.
- Anime details and episode list.
- Search screen.
- Watch history state.
- Favorites state.
- Light/dark theme persistence.
- AdSlot placeholder for future monetization.
- Player shell ready for an authorized HLS/CDN source.

## Current limitation
Data is still mock data. Real Anime API is intentionally not connected yet.

## Next phase
Create an API abstraction:
Flutter UI -> Repository -> API service -> Backend -> Anime provider.

Do not put provider secrets in the Flutter app.
