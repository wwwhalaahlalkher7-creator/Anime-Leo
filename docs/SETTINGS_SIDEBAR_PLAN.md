# Settings & Sidebar Redesign — Work Plan (V1.23 target)

> **Status note (see `docs/V1_22_1_PROGRESS.md`):** Phases 0–7 are done.
> Phase 8 is in progress — "Coming Soon" and "Seasons" now have real backend
> endpoints and screens. The rest of Phase 8 (Global Stats, Characters,
> Manga List, Animation List, Episode Schedule, News) is still pending, in
> the order recommended below. Telegram/contact-email links (Phase 7) are
> now configured with real defaults.

## Scope boundary — read this first
This plan covers **UI/UX and app-settings architecture only**: a sidebar (Drawer)
navigation pattern and a full Settings screen, styled after the reference screenshots.

**Out of scope, intentionally:** pulling episode video files from Anime4up, the
"Anime Witcher" app/site, or any similar unlicensed streaming source. `backend/src/video-provider.ts`
already encodes this as a hard rule for this project ("Implementations must represent
a provider that has explicit permission to distribute the referenced video... never
scrapes or proxies unofficial streams"), and `arabic-episode-provider.ts` has the same
constraint for the Arabic episode catalog. This plan doesn't touch or weaken that contract.
If a licensed/authorized video or Arabic-episode feed is arranged later, wiring it in
is a separate, well-scoped task — not this one.

## Current app inventory (relevant to this work)
- No `Drawer` / sidebar and no settings screen exist yet (`lib/screens` only has
  home, search, anime_details, player).
- `lib/core/theme_controller.dart` — `ChangeNotifier`, persists `light_mode` bool via
  SharedPreferences. Only light/dark, no "system" option yet.
- `lib/core/app_language.dart` — singleton `ChangeNotifier`, persists `app_language`
  string (`ar`/`en`) via SharedPreferences. Arabic is default.
- `lib/services/storage_service.dart` — SharedPreferences-backed favorites (`favorites_v2`)
  and watch history (`history_v2`). No settings/prefs model yet, no downloads.
- `lib/services/translation_service.dart`, `remote_config_service.dart`,
  `monetization_service.dart`, `monitoring_service.dart`, `analytics_service.dart` exist
  and can back specific settings rows later (e.g. ad toggles, diagnostics).
- No notification system, no `url_launcher` / `share_plus` wiring seen yet — needed for
  "contact us", "share app", and external links.

## Target structure (from the reference screenshots)
**Sidebar (Drawer)**, opened from a hamburger icon, top to bottom:
profile header (avatar + name) → Home → Anime List → Manga List → Animation List →
Seasons → Global Stats → Coming Soon → divider → My List → Favorites → Watch History →
Downloads → divider → Characters → Episode Schedule → News → Telegram link → Settings.

**Settings screen**, grouped sections:
1. **Account** — edit personal data; show-my-favorites/reviews/comments-to-others
   toggles; auto-mark-watched-episodes toggle; hide-mature-content toggle.
2. **Notifications** — new-episode alerts (scope picker: all / favorites-only / off),
   comment notifications, review notifications, news notifications.
3. **Player** — default player picker (ask every time / built-in fast player /
   external player such as MX Player).
4. **General** — appearance (system / light / dark).
5. **Other** — official website link, contact us (email + Telegram), share app,
   disclaimer, privacy policy, about app.

## Phased roadmap
Each phase is a self-contained session; each ends in a compiling, runnable app.

**Phase 0 — App-wide theme (✅ done)**
- Centralize the palette in `ThemeData`/`theme_controller.dart` so every screen
  inherits it, instead of styling new screens now and re-styling old ones later.
- Delivered: `lib/core/app_colors.dart` (palette constants), `lib/core/app_theme.dart`
  (`buildAppTheme()`), `main.dart` wired to it, old purple seed color and hardcoded
  `0x090A0F` background removed from `main.dart`, and the two hardcoded gradient
  overlays in `home_screen.dart`/`anime_details_screen.dart` updated to match the new
  `#05081A` background so they still blend correctly.

**Phase 1 — Navigation shell**
- `lib/widgets/app_drawer.dart`: the sidebar widget, wired to `AppLanguage` for bilingual
  labels and to existing routes.
- Wrap `home_screen.dart` (and other top-level screens as needed) with the drawer.
- `lib/screens/settings_screen.dart`: empty section-list scaffold + route.
- Placeholder screens/routes for sidebar items that don't have a home yet (Manga List,
  Animation List, Global Stats, Coming Soon, Characters, Episode Schedule, News) so
  navigation doesn't dead-end. Content for these is Phase 6+, not Phase 1.

**Phase 2 — Settings data model**
- New `lib/core/app_settings.dart`: one `ChangeNotifier` holding all toggle/enum state
  (mirrors the `ThemeController`/`AppLanguage` pattern already in the codebase).
- Persist via `StorageService` (new keys, same SharedPreferences approach already used
  for favorites/history) so it's one consistent pattern, not a second storage layer.

**Phase 3 — Account section (decided: placeholder for now)**
- Ships as a "Coming Soon" row/screen only — no edit-profile UI, no visibility toggles,
  no auth. Revisit once you decide local-profile vs. real backend accounts.

**Phase 4 — Notifications section**
- UI + `AppSettings` wiring for the toggles themselves.
- Note: these toggles only *gate* notifications. Actually delivering push notifications
  (new-episode alerts etc.) needs a notification pipeline (e.g. FCM) that doesn't exist
  in this codebase yet — that's its own project, separate from this settings screen.

**Phase 5 — Player preference**
- Settings picker UI + `AppSettings` wiring.
- Wire the chosen mode into `player_screen.dart` so it's actually respected.
- Launching a true external player (MX Player) needs an Android intent/plugin
  (e.g. `android_intent_plus`) — flag as a dependency add, not just UI.

**Phase 6 — Appearance**
- Add a "system" `ThemeMode` option to `theme_controller.dart` (currently light/dark only).
- Settings UI radio group wired to it.

**Phase 7 — Static/info pages**
- About, Privacy Policy, Disclaimer as simple content screens (text owned by this
  project, not copied from any other app).
- Contact Us: email + Telegram links via `url_launcher` (new dependency).
- Share App via `share_plus` (new dependency).
- Official website link.

**Phase 8 — Larger sidebar items (decided: build all of them for real)**
Every one of these gets a real backend endpoint + real screen, not a placeholder:
Manga List, Animation List, Seasons, Global Stats, Coming Soon, Characters,
Episode Schedule, News. Each is its own sub-scope:
- **Manga List** — new content type, separate from the anime catalog. Needs its own
  model (`Manga`, chapters instead of episodes), its own metadata source (Jikan also
  covers manga — same provider family as the existing anime metadata, so this reuses
  the `anime_api_service.dart` / `providers-jikan.ts` pattern rather than inventing a
  new integration), new D1 tables, new backend routes, new Flutter screens.
- **Animation List** — decided: separate catalog, not a filtered view of the anime
  catalog. Needs its own model/table and its own metadata source, same shape of work as
  Manga List (own D1 table, own backend route, own Flutter screen).
- **Seasons** — group the existing anime catalog by broadcast season/year; likely just
  a new query/endpoint over existing data (`backend/src/catalog.ts`), not a new content
  type.
- **Global Stats** — decided, based on the reference screenshots: a tabbed leaderboard
  screen, tabs like "Best Anime", "Best Ongoing Anime", "Best Movies", "Best Series",
  "Best OVA" — each tab a poster grid with year + type tag, ranked. This is a ranking
  view over the *existing* anime catalog (type: series/movie/OVA is already implied by
  metadata from Jikan/AniList), not a new content type — needs a backend endpoint that
  sorts/filters the catalog by score/popularity per type, plus a `type` field on stored
  anime if not already present (check `models/anime.dart` / catalog schema in Phase 8
  work — may need a migration to add/backfill `type`).
- **Coming Soon** — upcoming/unaired titles; likely a filtered view of the catalog by
  air date (`aired` field already exists per `arabic-episode-provider.ts`'s episode
  shape), so mostly a query, not new infrastructure.
- **Characters** — new content type (per-anime character list + images), needs its own
  model; Jikan also exposes character data, so same provider family as anime/manga.
- **Episode Schedule** — "what airs when" view; likely derivable from existing episode
  `aired` data plus the catalog-sync cron job already in `catalog-sync.ts`, extended to
  also capture schedule/day-of-week info.
- **News** — decided: pulled from an external feed/source rather than authored in-app.
  Still needed from you before this item's backend work starts: which feed/site, and
  its format (RSS vs. a specific API) — that determines whether this reuses the
  `ArabicEpisodeProvider`-style "configured external source" pattern already in the
  codebase or needs something new.

Recommended build order (cheapest/lowest-risk first): Seasons → Coming Soon →
Episode Schedule → Global Stats (needs the `type` field check) → Characters →
Manga List → Animation List → News (News last since it still needs the feed
source/format decided).

**Phase 9 — Polish + version bump**
- QA pass on every toggle/persisted value across app restarts.
- Update `VERSION.md` with a `V1.23.0` entry per the existing changelog convention.

## Color palette (decided — app-wide)
Sampled from the reference icon you attached, and now the intended palette for the
**whole app**, not just settings/drawer — applied consistently rather than as a
separate reskin:

| Role | Hex | Where to use |
|---|---|---|
| Background (deep navy) | `#05081A` | App/scaffold background everywhere |
| Surface / card | `#10142B` | Anime cards, section cards, drawer background |
| Primary accent | `#4C6EF5` | Active nav item, selected toggle/radio, buttons, links |
| Deep accent | `#003F8F` | Pressed/darker accent state, dividers |
| Highlight / icy blue | `#BAD9F6` | Headers, active tab text, subtle glows |
| Text on dark | `#F5F7FF` | Primary text |

Practical implication for the roadmap: this now belongs in `lib/main.dart`'s
`ThemeData` (and wherever `theme_controller.dart` builds light/dark themes) as the
single source of truth, so every screen inherits it automatically instead of each
screen hardcoding colors. Given it now touches the whole app rather than just new
screens, this is its own small phase — **Phase 0**, done first, before Phase 1 — so
the new sidebar/settings work is built directly against the final palette instead of
re-styled twice.

## Open decisions still needed (per-item, not blocking Phase 0/1)
- **News**: exact feed/site + format (RSS vs. API) — needed before that item's
  backend work in Phase 8.
- **Global Stats**: confirm the anime catalog already stores a `type` (series/movie/OVA)
  field; if not, that's a small migration to add before this tab set can be built.
