# V1.13.0 — Flutter ↔ Backend Integration Hardening

## Goal
Strengthen the mobile/backend contract without changing the backend architecture or provider design.

## Changes
- Mobile app version is now `1.13.0`.
- Production API default URL is corrected to the deployed Anime Leo Worker URL.
- Flutter API errors now preserve the backend request ID when available.
- Flutter API errors parse safe backend `message`/`degraded` fields without exposing secrets.
- Search now uses a short local cache and a stale-cache fallback for provider/backend outages, matching the resilient Catalog behavior.
- Existing top/details/episodes caching and V1.12 Provider Manager behavior are preserved.
- Backend version is bumped to `1.13.0` only; no D1 schema or architecture change.
- Ads, analytics, and video remain disabled.

## Compatibility
- API remains `v1`.
- Minimum supported backend app version remains `1.9.0`.
- D1 database ID is unchanged.
- Flutter still communicates only with the Anime Leo backend.

## Validation target
Verify mobile-to-backend integration against:
- `/api/health`
- `/api/config`
- `/api/top/anime`
- `/api/anime`
- `/api/anime/:id/full`
- `/api/anime/:id/episodes`
- degraded/error responses with request IDs
