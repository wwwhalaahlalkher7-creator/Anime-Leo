# Video Source Research — Creative Commons & Public Domain (2026-08)

> **V1.28 project decision (20 Aug 2026):** ani-cli-arabic is an authorized playback integration for this release, and MyDubList is an authorized Arabic-dub metadata source. The older CC/public-domain research below is historical research and is not the active anime playback path.


Status: Option 1 decided and implemented as a standalone provider (not yet
wired into any route). Option 2 decided in principle but **not** implemented
as an open API integration — see "Decision — Option 2" below for why, and
what's needed before it can be.

`backend/src/video-provider.ts` and `arabic-episode-provider.ts` are
unchanged — their hard rule stays: only wire a source into an actual route
once its rights are verified per-title where needed.

## Bottom line up front
"Anime" (Japanese TV/theatrical animation) that is genuinely public domain
or Creative Commons is **very rare** — almost none of what people mean by
"anime" qualifies. What's realistic and safe:

1. **Blender Studio open movies** — real, official, unambiguously CC-BY
   animated short films. Good fit for the plan's "Animation List" item.
   Not anime, but legally clean and app-ready today.
2. **Internet Archive** — hosts some genuinely public-domain older
   Japanese animation, but mixed in with pirated re-uploads on the same
   site. Usable, but needs a manual, per-title license check before
   anything from it is wired into the app — an API alone can't tell "PD"
   apart from "someone uploaded a copyrighted show anyway."
3. **Anime-specific "free streaming" APIs** (Consumet/Gogoanime-style,
   the amvstrm/Miru API family, etc.) — these proxy or scrape unlicensed
   sources. They're exactly what `docs/SETTINGS_SIDEBAR_PLAN.md` already
   ruled out for this project (same category as Anime4up / "Anime
   Witcher"). Listed below only so it's clear they were considered and
   rejected, not missed.

## Option 1 — Blender Studio (video.blender.org)
- What it is: the Blender Foundation's own PeerTube instance hosting its
  official open-movie shorts — *Big Buck Bunny*, *Sintel*, *Elephants
  Dream*, *Tears of Steel*, *Cosmos Laundromat*, *Coffee Run*, *Charge*,
  *Spring*, and others.
- License: Creative Commons Attribution, stated by the Blender Foundation
  itself — the actual rights holder. The exact version (2.5/3.0/4.0) and
  scope varies per title and sometimes per asset within a title (Big Buck
  Bunny's film is CC BY 3.0, but its musical score was released separately
  under CC BY-NC-ND) — so attribution is per-video, not a single blanket
  string.
- API: PeerTube's REST API — public, no auth needed for reads. Same shape
  of "configured external source" the app already uses for
  `arabic-episode-provider.ts`.
- Fit: content type is animated short films, not episodic anime — good
  match for the plan's separate "Animation List" sidebar item, not a
  substitute for an anime episode source.

**Decision — Option 1: implemented.** `backend/src/blender-studio-provider.ts`
is written and delivered (see chat), mirroring the existing
`ArabicEpisodeProvider`/`VideoProvider` pattern:
- `list(page, limit)` — cheap catalog data (title, thumbnail, duration) from
  `GET /video-channels/{channel}/videos`, for a grid.
- `getAsset(externalId)` — resolves the actual HLS stream URL plus a
  ready-to-render attribution line, fetched lazily per title from
  `GET /videos/{uuid}`, same lazy-fetch shape as
  `videoProvider.getEpisodeVideo()`.
- `NoOpAnimationProvider` — safe default, same pattern as `NoOpVideoProvider`.
Not yet wired into `index.ts`, a D1 table, or a Flutter screen — that's the
Animation List backend route + screen work itself (Phase 8 of
`SETTINGS_SIDEBAR_PLAN.md`), a separate task from this provider adapter.

## Option 2 — Internet Archive (archive.org)
- What it is: a large, well-documented hosting/metadata service
  (`archive.org/developers`) with a free Advanced Search/scrape API
  (`/services/search/v1/scrape`) and Metadata API (`/metadata/{id}`).
- License reality: Archive.org hosts a real public-domain film collection,
  and a small number of genuinely public-domain older Japanese animated
  films circulate there (courts have found pre-1953 Japanese films PD in
  Japan; the calculation gets more complex for 1953–1971 titles and
  differs again for the US term). But the same site also hosts plenty of
  fan re-uploads of shows that are still very much under copyright — the
  API has no reliable "is this actually PD" field to filter on.
- Conclusion: technically excellent API, legally unusable *in bulk*. It
  could only be used title-by-title, with someone actually confirming the
  specific film's public-domain status (ideally with a citation), before
  that one item is added — not as an automated feed.

**Decision — Option 2: not implemented as an open API integration.**
Querying archive.org's search/scrape endpoint generically and serving
whatever comes back would build exactly the automated, unverified feed this
doc already ruled out — the API can't distinguish a real pre-1953 PD title
from a fan re-upload of a still-copyrighted series on the same site, so an
open integration risks doing precisely what `video-provider.ts`'s hard rule
and the sidebar plan's scope boundary exist to prevent.
What *is* safe to build, once wanted: a thin `ArchiveOrgAnimationProvider`
that only serves a short, hand-maintained allowlist of specific
`archive.org` identifiers — each one individually confirmed public-domain
(with a citation) before it's added to the list — fetched via the plain
Metadata API (`/metadata/{id}`) per known-good ID, never via open search.
Structurally this is the same `AnimationProvider` interface as Option 1;
only the source of the ID list differs (hand-curated vs. a live channel
listing). Not built yet — needs either specific verified `archive.org`
identifiers to seed the allowlist, or a decision to defer this option
until some exist.

## Option 3 — Wikimedia Commons
- Same Blender Foundation films (and other genuinely CC/PD animated
  shorts) are mirrored here under clear per-file license tags, queryable
  via the standard MediaWiki API. Functionally a second, slightly more
  curated way to reach the same Option 1 content plus occasional other CC
  animation — not a distinct new catalog.

## Considered and ruled out
- **Openverse** (Creative Commons' own search API): images and audio
  only — it explicitly does not index video, so it's not usable for this
  at all.
- **"Free anime API" aggregators** (Consumet-style, Gogoanime scrapers,
  the amvstrm/Miru API, etc.): these work by scraping or proxying
  unlicensed streaming sites. This is precisely the pattern
  `video-provider.ts`'s hard rule and the sidebar plan's scope boundary
  already exclude — not revisited here.

## Prerequisite noticed while implementing Option 1
`lib/screens/player_screen.dart` and `lib/services/video_provider.dart`
don't actually render video yet — today the player screen only shows a
placeholder icon/state text, and `pubspec.yaml` has no video-playback
package (no `video_player`, `chewie`, or `webview_flutter`). So even once
an `AnimationAsset.streamUrl` (HLS) exists from `blender-studio-provider.ts`,
nothing in the Flutter app can play it yet. That's a real dependency add
(same category as Phase 5's external-player intent or Phase 7's
`url_launcher`/`share_plus`) — separate from, and needed before, any
Animation List screen can actually play a title.

## Recommendation
- Nothing to wire in for actual anime episodes — no real source cleared
  that bar. The project's current behavior (video disabled, real "no
  licensed source configured" message) stays correct.
- For the "Animation List" sidebar item (Phase 8): Blender Studio's open
  movies are ready to use with a clean license, and the provider adapter
  now exists — wiring it into a real route/table/screen is the remaining
  Phase 8 work, plus adding actual HLS playback to the Flutter app.
- Internet Archive stays a manual, title-by-title option, not an API
  integration, unless/until specific verified IDs are supplied.
