# Anime Leo V1.22.0 — Automatic Catalog Sync

## Goal
The backend now expands and refreshes the D1 anime catalog automatically. The mobile app does not need to request an anime first, and there is no manual increase to the catalog size.

## How it works
Cloudflare Cron runs every 6 hours. Each run walks two Jikan streams:
- `popularity`: broad catalogue coverage.
- `latest`: newer/recently aired titles.

Each stream advances a persistent D1 page cursor. Existing records are updated with an upsert, so duplicates are not created.

## Deployment
From the deployment environment, after updating the repository:

```bash
cd backend
npm install
npm run db:migrate
npm run deploy
```

The migration creates `catalog_sync_state`.

## Verification

```bash
curl -s "https://YOUR-WORKER.workers.dev/api/health"
curl -s "https://YOUR-WORKER.workers.dev/api/config"
curl -s "https://YOUR-WORKER.workers.dev/api/diagnostics/catalog"
curl -s "https://YOUR-WORKER.workers.dev/api/diagnostics/catalog-sync"
```

After the first scheduled run, `catalog-sync` should show advancing `page`, `last_success_at`, and increasing `total_upserted`.

## Schedule
Default: every 6 hours (`0 */6 * * *`).

Configuration in `wrangler.toml`:
- `CATALOG_SYNC_ENABLED = "true"`
- `CATALOG_SYNC_PAGES = "5"`
- `CATALOG_SYNC_LIMIT = "24"`

The scanner deliberately stays conservative with the public Jikan service and processes requests sequentially.
