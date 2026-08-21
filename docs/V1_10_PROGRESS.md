# V1.10 / V1.10.1 Progress

## V1.10
- Provider resilience.
- D1 fallback.
- Graceful degradation.
- Degraded responses are not stored in Edge Cache.

## V1.10.1 — Diagnostic phase
Added:

`GET /api/diagnostics/catalog`

The endpoint is read-only and does **not** call Jikan. It reports:
- D1 connectivity.
- Total anime rows.
- Total episode rows.
- Anime rows with scores.
- Oldest/newest anime `updated_at`.
- A simple Naruto title-match probe.
- Count of scored rows available to the Top catalog query.
- Whether the provider is configured.

Purpose:
Determine whether the production Catalog failure is caused by an empty D1 database, missing/insufficient catalog data, or later in the provider/catalog path.

This diagnostic release does not yet change provider selection or introduce another provider.


## V1.10.2 — Catalog bootstrap

The production diagnostic confirmed D1 was empty while Jikan individual details remained reachable and Jikan search/top returned 504. V1.10.2 adds protected D1 catalog bootstrap using individual detail requests.
