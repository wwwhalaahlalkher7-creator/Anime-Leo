# Deploy V1.12.0

ZIP: `anime-platform-v1.12.0-provider-manager.zip`

```bash
cd ~/storage/shared/Download
rm -rf anime-platform-v1.12.0-provider-manager
unzip -q anime-platform-v1.12.0-provider-manager.zip -d anime-platform-v1.12.0-provider-manager
cd ~/storage/shared/Download/my-project
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r ~/storage/shared/Download/anime-platform-v1.12.0-provider-manager/. .
ls -la backend
ls -la backend/src
git add -A
git commit -m "Release V1.12.0"
git push --force origin main
```

Do not run `npm install` in Android shared storage.

After deployment, run the existing production smoke tests plus `/api/config` and `/api/health?deep=true`.
