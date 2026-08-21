# V1.17.0 Deployment

Termux is for upload/deployment only.

1. Upload the V1.17.0 ZIP to the deployment machine.
2. Extract it over the project workspace according to the existing deployment workflow.
3. From `backend/`, run the existing deployment command:

```bash
npm install
npm run db:migrate
npm run deploy
```

4. Verify `/api/health` and `/api/config`.
5. Build the Flutter APK with the deployed API URL.

Monetization, analytics, and video remain disabled in this release.

Do not put Cloudflare credentials or `CATALOG_SEED_TOKEN` in the Flutter app or source control.
