# Anime Leo V1.13.0 Deployment

ZIP: `anime-platform-v1.13.0-integration-hardening.zip`

## Termux

```bash
cd ~/storage/shared/Download
rm -rf anime-platform-v1.13.0-integration-hardening
unzip -q anime-platform-v1.13.0-integration-hardening.zip -d anime-platform-v1.13.0-integration-hardening

cd ~/storage/shared/Download/my-project
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r ~/storage/shared/Download/anime-platform-v1.13.0-integration-hardening/. .

ls -la backend
ls -la backend/src
ls -la anime-platform-mobile-v1

git add -A
git commit -m "Release V1.13.0"
git push --force origin main
```

Do not run `npm install` in Android shared storage.
Do not expose or copy any Cloudflare secrets into Flutter or Git.
