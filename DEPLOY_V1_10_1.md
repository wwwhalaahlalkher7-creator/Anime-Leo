# Deploy V1.10.1 — Catalog Diagnostic

## Purpose

Deploy the diagnostic-only release before changing the catalog/provider architecture.

The new endpoint is:

`GET /api/diagnostics/catalog`

It reads D1 only and does not call Jikan.

## Deploy

From `backend/`:

```bash
npm install
npx wrangler deploy
```

The existing D1 binding and database ID are preserved.

## Verify

After deployment, call:

```bash
curl -i https://YOUR-BACKEND/api/diagnostics/catalog
```

Expected shape:

```json
{
  "status": "ok",
  "database": {
    "connected": true,
    "anime_count": 0,
    "episodes_count": 0,
    "scored_anime_count": 0
  },
  "catalog": {
    "has_anime": false,
    "has_scored_anime": false,
    "search_probe_naruto_matches": 0,
    "top_probe_scored_rows": 0
  }
}
```

The numbers above are examples only.

## Interpretation

- `anime_count = 0`: D1 has no catalog seed/data; this is the strongest explanation for an empty degraded Catalog when Jikan Search/Top is unavailable.
- `anime_count > 0` and `naruto_matches > 0`: Search can potentially fall back to D1 for matching titles.
- `scored_anime_count > 0`: Top can potentially fall back to D1.
- `anime_count > 0` but both catalog probes are 0: inspect the actual stored data and SQL filtering next.
- `status = error`: the Worker could not query D1 and the database binding/migration/runtime must be investigated first.

Do not add another provider yet. The diagnostic result determines the next V1.10.1 fix.
