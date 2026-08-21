# Anime Leo V1.14.0 Deployment

ZIP: `anime-platform-v1.14.0-ui-ux-stabilization.zip`

## Scope
V1.14.0 updates the Flutter UI/UX only. It is built directly on the V1.13.0 integration-hardening tree.

- Backend architecture unchanged.
- D1 schema/migrations unchanged.
- Provider Manager unchanged.
- API version remains `v1`.
- Backend remains `1.13.0`.
- Ads, analytics, and video remain disabled.

## Termux

```bash
cd ~/storage/shared/Download
rm -rf anime-platform-v1.14.0-ui-ux-stabilization
unzip -q anime-platform-v1.14.0-ui-ux-stabilization.zip -d anime-platform-v1.14.0-ui-ux-stabilization

cd ~/storage/shared/Download/my-project
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r ~/storage/shared/Download/anime-platform-v1.14.0-ui-ux-stabilization/. .

cd anime-platform-mobile-v1
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
cd ..

# Backend smoke checks only; do not modify backend for V1.14.
cd backend
npm test
cd ..

git add -A
git commit -m "Release V1.14.0 UI UX stabilization"
git push origin main
```

Do not run `npm install` in Android shared storage.
Do not expose or copy Cloudflare secrets into Flutter or Git.
