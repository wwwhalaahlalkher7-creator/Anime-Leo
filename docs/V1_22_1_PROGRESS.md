# V1.22.0+6 — Phase 8 (partial): Coming Soon, Seasons, and contact links

Status: implemented and wired end-to-end (backend + app). Rest of Phase 8 is
still pending, per its own sub-scopes in `docs/SETTINGS_SIDEBAR_PLAN.md`.

## What shipped
- **Backend**: `GET /api/anime/coming-soon` — a database-only, paginated view
  over the existing `anime` table filtered to `status = 'Not yet aired'`
  (`backend/src/catalog.ts`: `comingSoonCatalog`; wired in
  `backend/src/index.ts`, including the maintenance-mode catalog-read guard
  and response caching, same as the other catalog routes). No new table, no
  new provider — this is exactly the "filtered view of the catalog" the plan
  called for.
- **Backend**: `GET /api/anime/seasons` — no `year` query param returns the
  distinct broadcast years present in the catalog with counts
  (`seasonYears`); `?year=YYYY` returns a paginated, score-sorted list of
  that year's titles (`seasonCatalog`). The catalog only stores a `year`,
  not a quarter/season string, so "Seasons" here means "grouped by year" —
  true winter/spring/summer/fall grouping would need a schema change and a
  provider field that isn't captured yet. Worth revisiting if that's wanted.
- **App**: `lib/screens/upcoming_anime_screen.dart` — a real, paginated grid
  screen (same shape as `SearchScreen`'s results view) replacing the
  placeholder for the sidebar's "Coming Soon" item.
- **App**: `lib/screens/seasons_screen.dart` — year chips at the top (from
  `seasonYears`), paginated grid below for the selected year
  (`getSeasonAnime`), replacing the placeholder for "Seasons".
  `AnimeDataSource`/`AnimeApiService`/`AnimeRepository` all got matching
  `comingSoon(...)`, `seasonYears()`, and `seasonAnime(year, ...)` methods
  with the same caching pattern as `getTopAnime`. `AppDrawer` now takes
  `state`/`analytics` (needed to push these screens) and routes "Coming
  Soon"/"Seasons" to them instead of `ComingSoonScreen` (the generic "under
  development" placeholder widget — unrelated name collision, worth
  remembering if that widget is ever renamed).
- **Contact links** (`lib/core/config.dart`): `telegramUrl` now defaults to
  `https://t.me/animeleo_support`; `contactEmail` now defaults to
  `www.halaahlalkher10@gmail.com`. Both already had `String.fromEnvironment`
  overrides for build-time changes without touching code — that's untouched,
  only the fallback values changed. These feed the sidebar's Telegram item
  and Settings > Other > Contact us (email + Telegram), both already wired
  through `LinkLauncher`.

## Still pending from Phase 8
Manga List, Animation List, Global Stats (needs the `type`-field check
first), Characters, Episode Schedule, and News (still blocked on picking a
feed/source + format) are unchanged and still need their own sessions.
Recommended remaining order per the plan: Episode Schedule → Global Stats →
Characters → Manga List → Animation List → News.
