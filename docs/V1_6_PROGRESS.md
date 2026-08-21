# V1.6 — Backend Hardening & Remote Configuration

## Implemented

### Backend
- Better method handling.
- Health endpoint.
- Remote configuration endpoint.
- Explicit feature flags.
- Safer upstream proxy structure.
- Cache HIT/MISS headers.
- Retry-After on upstream rate limit.
- Reserved analytics endpoint.
- No secrets required in the Flutter client.

### Mobile
- Remote configuration service.
- Fail-safe feature flags.
- Analytics abstraction (No-Op for now).
- Backend remains configurable with `API_BASE_URL`.

## Current feature flags

```json
{
  "ads": false,
  "analytics": false,
  "video": false
}
```

These remain disabled until their implementations are ready.

## What you need to do after this version

### A) Install Flutter if not already installed
You need Flutter SDK to build the APK. Termux is not the required production environment.

### B) Deploy the backend
The easiest current route is Cloudflare Workers.

From the `backend` directory:

```bash
npm install
npx wrangler login
npm run deploy
```

Copy the Worker URL.

### C) Connect the app to the backend

```bash
flutter pub get

flutter run \
  --dart-define=API_BASE_URL=https://YOUR-WORKER.workers.dev/api
```

For APK:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://YOUR-WORKER.workers.dev/api
```

### D) Test

Open:

```text
https://YOUR-WORKER.workers.dev/api/health
https://YOUR-WORKER.workers.dev/api/config
```

Both should return JSON.

## Do not do yet

- Do not add random video scraping sources.
- Do not put provider secrets in Flutter.
- Do not enable ads before the app's main flow is stable.
- Do not publish the app before confirming the content/video source is licensed.

## V1.7 target

- Persistent server-side catalog.
- Database.
- Provider adapter layer.
- Anonymous analytics.
- Legitimate video provider interface.
- Production deployment.
- Monitoring and rate limiting.
