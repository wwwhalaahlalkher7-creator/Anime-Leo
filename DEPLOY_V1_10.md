# V1.10 Deployment

V1.10 is cumulative from V1.9. Replace the project files with this ZIP, then commit/push using the established workflow.

Cloudflare Workers:
- Root directory: `backend`
- Build command: `None`
- Deploy command: `npx wrangler deploy`

D1 database ID:
`4268654f-1c22-49f0-9d71-32ca62c95051`

After deployment test:
- `/api/health`
- `/api/config`
- `/api/health?deep=true`
- `/api/top/anime?page=1&limit=3`
- `/api/anime?q=naruto&page=1&limit=3`

When Jikan search/top are unavailable, V1.10 should return a valid JSON response with `200` and `degraded: true` when stale D1 data is available, rather than a 500.
