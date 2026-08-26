# Anime Leo V1.28.0 Beta 1 — Diagnostic Release

## Purpose

This build is intentionally diagnostic. It is not the final release.

### Anime data path

The Anime section no longer reads anime metadata, details, episodes, seasons, or upcoming titles from the Anime Leo backend or Cloudflare D1.

Flow:

`Flutter -> Jikan API`

This isolates the historical 15-title/D1 catalog problem from the mobile Anime section.

### Failure visibility

Network/API failures are intentionally shown to the user with:

- HTTP status when available
- upstream/provider message when available
- request endpoint
- request ID where applicable
- exception type/cause for network/parse failures

Do not hide or replace these messages during Beta testing. They are evidence for the next fix.

### Cache behavior

The Anime repository does not silently fall back to stale cached data after a failed live request in the diagnostic paths. This is deliberate so a broken upstream request remains visible.

### Intro

The intro video and secondary logo were removed. Startup now shows only `assets/anime_leo_icon.png` while startup preloading runs.

### Versioning

Edit only `VERSION`, then run:

`./tool/sync_version.sh`

The script synchronizes the Flutter version, runtime version constant, and backend `APP_VERSION` variable.

Current version: `1.28.0-beta.1+15`

### Important scope note

D1 still exists for backend features that intentionally use the catalog (for example the current animation/manga catalog architecture). The final goal of this Beta is specifically to remove D1 dependency from the Anime section, not to delete the entire project's D1 database.
