# Anime Platform V1.9 — deployment

This package is the V1.9 cumulative package based on the supplied V1.8 production foundation.
It keeps the V1.8 files and adds the V1.9 hardening changes.

## Cloudflare Workers Build

- Root directory: `backend`
- Build command: `None`
- Deploy command: `npx wrangler deploy`
- D1 binding: `DB`
- D1 database ID: `4268654f-1c22-49f0-9d71-32ca62c95051`

## Termux

After extracting this package into the download folder:

```bash
cd ~/storage/shared/Download/my-project
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r ~/storage/shared/Download/anime-platform-v1.9-cumulative-corrected/. .
ls -la backend
ls -la backend/src
git add -A
git commit -m "Release V1.9"
git push --force origin main
```

If `cp` fails, stop. Do not commit or push.

## Verify

```text
https://anime-leo.www-halaahalkher7.workers.dev/api/health
https://anime-leo.www-halaahalkher7.workers.dev/api/config
https://anime-leo.www-halaahalkher7.workers.dev/api/health?deep=true
```

Expected application/backend version: `1.9.0`.
Expected D1 status on health: `ok`.
