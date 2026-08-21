# Anime Leo + Anivexa merge

Anivexa is embedded inside `backend/src/anivexa/` and mounted by the Anime Leo
Cloudflare Worker under `/api/anivexa`.

This avoids running a second API service. Existing Anime Leo catalog/search/
details/episode routes are preserved.

Flutter now exposes:
- `AnimeApiService.anivexaEpisodes(...)`
- `AnimeApiService.anivexaWatch(...)`
- `AnimeRepository.getAnivexaEpisodes(...)`
- `AnimeRepository.getAnivexaWatch(...)`

The current player UI was intentionally not replaced in this merge; the merged
watch endpoint returns Anivexa's stream metadata, including HLS streams and
subtitle metadata where the provider supplies them.
