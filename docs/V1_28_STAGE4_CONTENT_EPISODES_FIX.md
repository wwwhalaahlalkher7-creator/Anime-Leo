# Anime Leo V1.28.0+14 — Stage 4 Content & Episodes Fix

## Implemented

### 1. Episode list now follows the Anivexa playback path
- Anime details first resolves the MAL ID to an AniList ID through the existing Anivexa mapping route.
- Episode lists are built from Anivexa subtitle (`sub`) episode metadata across the configured providers.
- The existing Jikan/catalog episode endpoint remains the fallback.
- Episode cache keys were versioned to avoid reusing the older empty episode results.

### 2. Top anime catalog refresh/coverage
- Bumped the mobile top-anime cache key.
- Added a catalog query version to bypass stale Cloudflare cache entries.
- Increased the number of catalog pages loaded by the mobile home repository from 6 to 8.

### 3. Manga catalog resilience
- MangaDex Arabic-first catalog loading now falls back to the broad safe catalog if the optional Arabic query is rejected or returns no rows.
- This keeps the Manga/Manhwa section populated even when Arabic availability filters temporarily fail.

## Preserved behavior

- Subtitle-first content remains the current target.
- Dubbed content is not introduced as the default content mode.
- No npm commands or Termux tests are required for this stage.
- The existing Anivexa provider authorization/configuration remains unchanged.
