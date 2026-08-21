# Deploy V1.11.0 — Catalog Reliability + D1

## 1. Extract the release

```bash
cd ~/storage/shared/Download
rm -rf anime-platform-v1.11.0-release
unzip -q anime-platform-v1.11.0-release.zip -d anime-platform-v1.11.0-release
```

## 2. Replace the project contents

```bash
cd ~/storage/shared/Download/my-project
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r ~/storage/shared/Download/anime-platform-v1.11.0-release/. .

ls -la backend
ls -la backend/src
```

## 3. Commit and push

```bash
git add -A
git commit -m "Release V1.11.0"
git push --force origin main
```

## 4. Deploy the Worker

Use the existing Cloudflare deployment environment. Do not change the D1 database ID or the existing runtime secret configuration.

The release keeps `CATALOG_SEED_TOKEN` as a runtime secret and does not require the token to be placed in the project files or Flutter.

## 5. Smoke test after deployment

```bash
cd ~/storage/shared/Download/my-project/backend
API_BASE_URL="https://anime-leo.www-halaahlalkher7.workers.dev/api" npm run test:smoke
```

The smoke test covers:
- health
- config
- deep health
- top anime
- search
- anime details
- episodes
- catalog diagnostics

`episodes` returning an empty/degraded result is acceptable while D1 has no episode rows and the provider is unavailable.
