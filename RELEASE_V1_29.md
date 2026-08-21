# Anime Leo V1.29 — Offline Downloads

## Scope
- Manual episode downloads when the authorized source exposes a direct download URL.
- MediaFire-resolved direct URLs are surfaced as download-capable by the ani-cli-arabic adapter.
- Completed anime only: a full-series download action is shown when status is finished. Movies receive a download action.
- Ongoing anime do not expose a full-series download action.
- No auto-download feature.
- Local download manager with progress, cancellation, retry via re-start, and offline files.

## Source boundary
The backend does not proxy or store media bytes. It only exposes short-lived source metadata returned by the configured provider. Download files are stored on the Android device.
