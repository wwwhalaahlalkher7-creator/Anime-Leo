# Anime Leo V1.30.0+18 — Anime Details/Provider Resolution Fix

## Root cause addressed

The Anime details path can receive a canonical MAL ID from the Flutter client while providers use different ID namespaces. The aggregator now explicitly gates provider calls by ID namespace: Jikan receives only positive MAL IDs, while AniList accepts positive MAL IDs (`idMal`) or legacy negative AniList IDs.

This prevents an invalid provider request from being treated as the same namespace and makes the details aggregation resilient when one provider cannot resolve the requested ID.

## Diagnostics

Added `GET /api/diagnostics/anime/{id}` (no cache) to report per-provider resolution and the resolved canonical identity.

## Version

- Flutter: `1.30.0+18`
- Backend: `1.30.0.18`
