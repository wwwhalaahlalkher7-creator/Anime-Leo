# V1.9 Install Fix

The previous V1.9 package had an invalid `@cloudflare/workers-types`
version (`4.20260814.0`), which can make Cloudflare fail during **Installing**.

This package removes that dependency and pins Wrangler to a published version:
`wrangler 4.116.0`.

Cloudflare settings remain:
- Root directory: `backend`
- Build command: `None`
- Deploy command: `npx wrangler deploy`

Do not change the root directory to `/backend`; use `backend` exactly.
