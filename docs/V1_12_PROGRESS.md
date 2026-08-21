# V1.12.0 Progress — Provider Manager / Multi-provider Foundation

## Goal
Introduce a backend-only Provider Manager so metadata providers can be prioritized and fail over without changing catalog logic or Flutter.

## Changes
- Added `ProviderManager` implementing the existing `AnimeProvider` contract.
- Provider calls are attempted in configured priority order.
- Health checks can continue to the next provider.
- Added `PROVIDER_ORDER` runtime configuration.
- Jikan remains the only implemented provider in V1.12.0.
- Existing D1-first catalog behavior and V1.11.0 degraded handling are preserved.
- Flutter remains unaware of provider identities and implementation details.

## Intentionally not included
- No unverified or unauthorized metadata provider.
- No video provider.
- No ads.
- No analytics activation.
- No D1 ID change.
- No D1 migration required.

## Acceptance
1. Provider Manager is used by all catalog/provider operations.
2. `PROVIDER_ORDER=jikan` preserves current production behavior.
3. `/api/config` exposes provider order without exposing secrets.
4. `/api/health?deep=true` uses the manager health check.
5. Catalog endpoints continue to pass V1.11.0 behavior.
6. A future provider can be added by implementing `AnimeProvider` and registering it in the manager without changing Flutter.
