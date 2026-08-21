# V1.7 — Database + Catalog + Provider Architecture

## Implemented

### Backend
- Cloudflare D1 schema for anime, episodes, providers, analytics events, and rate limits.
- Normalized catalog service.
- Provider adapter interface.
- Jikan metadata adapter behind the backend.
- Database-first catalog with provider fallback when the requested catalog page is not populated.
- Normalized API response contract.
- Anonymous analytics endpoint, disabled by default.
- Basic D1-backed per-IP-hash rate limiting.
- Remote configuration for maintenance mode, minimum app version, search limits, and feature flags.
- Video provider interface with a safe No-Op implementation.
- Health endpoint now checks D1 availability.

### Flutter
- Fixed the missing `remoteConfig` constructor wiring in `main.dart`.
- Fixed `AdSlot(height: ...)` compile errors.
- Added remote config startup loading with fail-safe disabled configuration.
- Added analytics abstraction with a disabled-by-default remote implementation.
- Updated anime model and repository to understand normalized backend data.
- Added episode page caching.
- Added client-side VideoProvider abstraction with a No-Op implementation.

## Important

V1.7 requires a Cloudflare D1 database before catalog endpoints can work in production.

Do not enable ads, analytics, or video yet.

## Next version

V1.8 should focus on deployment verification, catalog sync quality, monitoring dashboards, and a legally authorized video provider if one is available.
