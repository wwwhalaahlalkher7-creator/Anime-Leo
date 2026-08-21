# Anime Leo V1.20.0 — GitHub + Cloudflare

## Deployment model

Termux → GitHub → Cloudflare Worker → Anime Leo APK

## Secrets

Do NOT commit API keys to GitHub. Configure them as Cloudflare Worker secrets:

- ARABIC_EPISODE_API_KEY
- LICENSED_VIDEO_API_KEY
- LICENSED_VIDEO_API_KEY_2
- LICENSED_VIDEO_API_KEY_3
- CATALOG_SEED_TOKEN

Optional local development values belong in `.dev.vars` (ignored by Git).

## Provider architecture

The backend should expose a provider chain so a future authorized Arabic source can be added
without changing the APK:

ArabicEpisodeProvider
→ Provider 1
→ Provider 2
→ Provider 3
→ available source

Providers must only be enabled when their source permits the intended use.

## Publishing

1. Commit/push source to GitHub from Termux.
2. Deploy the backend to Cloudflare with Wrangler.
3. Configure secrets in Cloudflare.
4. Build the APK using the backend URL.
5. Publish the APK through GitHub Releases/Actions.
