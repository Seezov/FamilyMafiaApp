# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Flutter migration complete.** The original Android/Kotlin code is preserved on `master`. This branch (`feature/flutter_migration`) is Flutter-only.

---

## Build Commands

API keys for remote seasons live in `assets/.env.json` (gitignored). Pass them via `--dart-define`:

```bash
flutter run                      # Run on connected device/emulator (bundled seasons only)
flutter run --dart-define=SHEETS_API_KEY=... --dart-define=REMOTE_CONFIG_URL=...   # With remote seasons
flutter build apk --debug        # Debug APK
flutter build apk --release --dart-define=SHEETS_API_KEY=... --dart-define=REMOTE_CONFIG_URL=...  # Release APK with remote
flutter analyze                  # Static analysis
flutter test                     # Unit tests
dart run build_runner build      # Regenerate freezed / json_serializable code
dart run build_runner watch      # Watch mode for code generation
flutter test tool/export_site_data_test.dart   # Export site JSON into site/data/ (needs assets/prefetched/ for remote seasons)
cd site && npm ci && npm run dev               # Stats site dev server (reads site/data/)
cd site && npm run build                       # What CI deploys: site/dist, plus link / key / player-page checks
dart run tool/prefetch_seasons.dart   # Snapshot remote seasons into assets/prefetched/ (needs SHEETS_API_KEY, REMOTE_CONFIG_URL env)
```

## Flutter Architecture

Riverpod + Dart, Jetpack-style layering.

**Layers:**
- `lib/constants/` — `season_constants.dart` (all season boundaries, formula thresholds, player exclusions with doc comments)
- `lib/screens/` — Flutter screens, each with a `_providers.dart` sidecar
  - `home/` — `HomeScreen` (season selector + per-season player rating list); split into `src/` parts: `loading_indicator`, `background_loading_banner`, `season_chips`, `season_header_card`, `player_card`
  - `players/` — `PlayersScreen` (grid of all players, tap → `PlayerProfileScreen`); `PlayerProfileScreen` split into `src/` parts: `accomplishments_section`, `season_chart`, `player_utilities`, `role_distribution_section`, `first_kill_section`, `best_moves_section`; `players_providers.dart` owns `playersListProvider`, `filteredPlayersProvider`, `playerSearchQueryProvider`, `playerAccomplishmentsProvider`
  - `dashboard/` — `DashboardScreen` (placeholder)
- `lib/repositories/` — Riverpod `StateNotifierProvider` singletons:
  `GamesRepository`, `PlayersRepository`, `RatingRepository`, `SeasonRepository`
- `lib/services/season_loader.dart` — computes ratings in background isolate, populates repositories; split into `src/` parts: `isolate_io`, `isolate_functions`, `data_filtering`, `game_parsing`, `player_rating`, `season_stats`, `percentiles`
- `lib/services/rating_formulas.dart` — pure public functions for all rating calculations (testable independently)
- `lib/services/season_data_service.dart` — orchestrates bundled vs remote season loading
- `lib/services/sheets_service.dart` — Dio-based Google Sheets API v4 wrapper (with `SheetsException` validation)
- `lib/services/season_cache_service.dart` — caches remote season data + remote config locally
- `lib/providers/app_providers.dart` — `appDataProvider` (3-phase: fetch configs → load JSONs → compute), `loadedSeasonConfigsProvider`
- `lib/models/` — Dart models (freezed + json_serializable):
  `Game`, `Player`, `RatingPlayerStats` (@freezed), `SeasonStats`, `SeasonConfig`, `YearStats`, `PlayerPlacements`, `SlotStats`, `Stats`, `BestMoves`
- `lib/enums/` — `Role`, `Season` (0–28, with `toConfig()` extension), `GameValues`
- `lib/extensions/` — `double_extensions.dart`, `list_extensions.dart`

Bundled seasons from `assets/raw/*.json`. Remote seasons from Google Sheets API (cached locally via `path_provider`).

## Flutter Data Flow

1. `seasonConfigsProvider` fetches remote config (GitHub raw JSON) → fallback: cached → bundled-only
2. `appDataProvider` watches configs, loads each season JSON via `SeasonDataService` (bundled or remote+cached)
3. `SeasonLoaderService.loadAll()` runs CPU work in a background isolate → populates all repositories
4. `RatingRepository` / `SeasonRepository` hold pre-computed `RatingPlayerStats` / `SeasonStats`
5. `loadedSeasonConfigsProvider` holds the list of successfully loaded `SeasonConfig`s for UI
6. Screen-level providers (e.g. `selectedSeasonProvider`, `seasonGamesProvider`) derive view data from repositories
7. Screens are `ConsumerWidget`s that `ref.watch` their providers

## Navigation

`main.dart` uses a `NavigationBar` + `IndexedStack`; the tabs come from
`appTabsFor` in `lib/navigation/app_tabs.dart` — six on mobile, four on the web
(Chat and Debug are mobile-only):
- **Season** (`HomeScreen`) — per-season player rating list (season chips + expandable player cards)
- **Players** (`PlayersScreen`) — full player roster grid with search and tap-through to `PlayerProfileScreen`
- **Dashboard** (`DashboardScreen`)
- **Records** (`RecordsScreen`)
- **Chat** (`ChatScreen`, mobile only) — Gemini chat
- **Debug** (`DebugScreen`, mobile only)

> **"Players screen"** always refers to `PlayersScreen` (`lib/screens/players/players_screen.dart`), not `HomeScreen`.

## Web site

Deployed to https://seezov.github.io/FamilyMafiaApp/ by `.github/workflows/web.yml`
(push to `feature/flutter_migration`, nightly, or "Run workflow"). The workflow file
must also be on `master` — GitHub only runs `schedule` / shows the button from the
default branch.

- The site is a static Astro project in `site/`, **not** the Flutter web build. Its data is
  JSON computed by the app's own providers: `tool/export_site_data_test.dart` loads every
  season through `loadSiteContainer()` (`lib/site_export/`) and `writeSiteData` writes
  `site/data/` (gitignored). Every table is exported display-ready (`SiteTable`), formatted
  in Dart like the app's widgets; the site only lays out and sorts.
- Adding a stat to the site = add it to the matching `lib/site_export/*_export.dart` and
  render it in `site/src/`. The app UI is unaffected.
- The build has **no API keys**: the export overrides `envJsonProvider` to `{}` and reads
  remote seasons + config from the `assets/prefetched/` snapshot; `site/scripts/check-dist.mjs`
  fails the build if `AIza` appears, an internal link is broken, or a player has no page.
- Player URLs are `/players/<slug>/`, transliterated from the display name (`slugs.dart`);
  renaming a player changes the URL.
- **Game browser:** `/season/N/games/` shows every parsed game (rating and non-rating) from
  `site/data/games/N.json` (`lib/site_export/games_export.dart`; `browserGames` re-parses each
  season's JSON — the repositories hold rating games only). Host comments, event labels and
  «Стіл N» come from the raw sheet rows via `lib/services/sheet_game_extras.dart`; if a season's
  anchors don't match its games the extras are dropped (alignment test names the season).
- `web/`, `WebFrame` and the `kIsWeb` branches still exist in the app but are no longer deployed.
- GitHub disables `schedule` workflows in public repos after 60 days without
  repo activity; if the nightly build stops, re-enable it in the Actions tab.
- **Game hosting (season 32+):** hosts record games on `/host/` (Firebase Auth + Firestore,
  project `familymafiaapp`, rules in `firestore.rules`, tests in `firebase/rules-test/` — run
  with `JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr"` and its `bin` on `PATH`). Seasons with `"source": "firestore"` are read over
  REST by `FirestoreService`; `games-watch.yml` rebuilds the site hourly when
  `meta/state.updatedAt` changed. Hosts are managed in the Firestore console
  (`hosts/{email}` = `{name, admin}`). Rules are published from the console's Rules tab.
- **Tournaments:** `/debug/` (admins, Google sign-in) edits Firestore `config/club` — tournaments,
  rejected candidates, final thresholds (`gameLimits`); rules in `firestore.rules`. The app reads it
  over REST (`FirestoreService.fetchClubConfig`, cached); the build reads the
  `assets/prefetched/club_config.json` snapshot. Saves bump `meta/state`, so the site rebuilds within
  an hour.
- **Annual rating:** `/annual/` (+ `/annual/<year>/`) from `site/data/annual.json`
  (`lib/site_export/annual_export.dart`, formulas in `lib/services/stats/annual_rating.dart`, TS port in
  `site/src/lib/annual/points.ts`, both checked against `test/fixtures/annual_points_cases.json`). External
  tournaments, series and marathons are Firestore `events/{id}`, edited by admins on `/annual/edit/`;
  prefetch snapshots them into `assets/prefetched/annual_events.json`. Club seasons from S28 are added by
  the export once finished (main league 1…N, small league top 5 as 101–105, year of the season's last month).
  2024–2025 came from the sheets once (`tool/import/`).
- **Player list:** Firestore `config/players` (`{players: [{name, nicknames}]}`, ordered — the app numbers
  players by position) is the roster; admins edit it on `/players/edit/` (add, nicknames, rename keeps the
  old name as a nickname, merge, unresolved game names from `site/data/unresolved.json`). Validation in
  `lib/models/roster.dart` and `site/src/lib/roster/roster.ts` (shared fixture `test/fixtures/roster_cases.json`).
  Prefetch snapshots it to `assets/prefetched/players.json` in the old `players.json` shape; the app reads it
  live → cached → bundled `assets/raw/players.json` (now only a fallback). Profiles follow renames through
  `aliases` in `site/data/players.json`.
  Edit it only on `/players/edit/`: the rule accepts any list, but the build fails on a clash or a
  malformed entry, so a console edit can stop every deploy. Colliding player slugs are `<slug>-<n>` (n by
  list order), never the id, so merges do not move URLs.
- **Player profiles:** `/account/` (Google sign-in → claim a player → admin approves on
  `/account/admin/` → nick + avatar). Firestore `claims/{uid}` (private) and
  `profiles/{playerKey}` (public; `playerKey` = lower-cased, URI-encoded display name).
  `site/scripts/fetch-profiles.ts` runs before `astro build`, writes `data/profiles.json` and
  `public/avatars/` (gitignored); components show nicks via `PlayerName.astro`. Changes appear
  after the next build (games-watch, ≤ 1 h). Rules for both live in `firestore.rules`.
- Running the prefetch locally leaves a ~650 KB snapshot in `assets/prefetched/`
  that also goes into local release APKs (no secrets, just data). Before a
  release APK: `rm assets/prefetched/season*.json assets/prefetched/remote_config.json`.

## Adding a New Season

**Bundled (offline):**
1. Add the season JSON to `assets/raw/`
2. Add a new entry to `lib/enums/season.dart` with correct `id`, `title`, `jsonFile`, `gameLimit`, and `gamesMultiplier`

**Remote (Google Sheets, no app update needed):**
1. Create a Google Sheet with game data in the expected column format
2. Add the season entry to the remote config JSON hosted on GitHub:
   ```json
   {"id": 29, "title": "Season 29", "gameLimit": 60, "gamesMultiplier": 0.0,
    "source": "remote", "spreadsheetId": "1aBcD...", "sheetName": "Sheet1", "range": "A:J"}
   ```
3. The app fetches the updated config on launch and loads the new season from Sheets

**Main-league threshold:** new seasons use `"gameLimitRule": "top3"` with no `gameLimit`: while the
season is played (calendar quarter, `seasonInProgress`) the threshold follows the sheet formula
(top-3 rating-game counts averaged × 0.6 − 5; main league = games ≥ it); after it ends, the admin's
value from Firestore `config/club.gameLimits` (set on `/debug/`) or the rounded-up formula. Seasons
without the rule keep their fixed `gameLimit`.

## Game Rules

The game is Mafia (10-player social deduction). Official tournament rules reference: `.claude/projects/C--Users-user-AndroidStudioProjects-FamilyMafiaApp/memory/game_rules.md`

This app is for **club play**, not tournaments. The core game mechanics (roles, phases, voting, night actions) are the same, but **rating calculations differ** from the official tournament system. See `lib/services/rating_formulas.dart` for the actual club rating formulas used in the app.

## Key Stack

- Dart / Flutter 3.x, Material 3
- Riverpod 2.6.1, freezed + json_serializable (KSP-equivalent via build_runner)
- Dio 5.x (HTTP + Google Sheets API)
- path_provider (local caching of remote seasons)
- minSdk 29

## Testing

```bash
flutter test                                        # All tests
flutter test test/services/rating_formulas_test.dart # Rating formula unit tests
```

## Conventions

- Magic numbers live in `lib/constants/season_constants.dart` with doc comments
- Large files use `part`/`part of` with parts in a `src/` subdirectory
- Rating formulas are standalone public functions in `rating_formulas.dart` (not private, for testability)

---

## Legacy Android Code

The original Kotlin/Jetpack Compose app is preserved on the `master` branch.
Architecture: MVVM + Hilt DI, Retrofit for Google Sheets API, JSON from `res/raw/`.
