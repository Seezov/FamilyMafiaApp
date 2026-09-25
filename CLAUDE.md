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
flutter run -d chrome            # Web (bundled seasons + prefetched snapshot, if any)
flutter build web --release --base-href /FamilyMafiaApp/   # What CI deploys
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

- Web shows Season, Players, Dashboard, Records only (`lib/navigation/app_tabs.dart`);
  Chat (paid Gemini) and Debug are mobile-only.
- The web build has **no API keys**: CI writes `{}` to `assets/.env.json` and a grep
  guard fails the build if `AIza` appears in `build/web`.
- Remote seasons + the remote config come from a build-time snapshot in
  `assets/prefetched/` (gitignored), written by `tool/prefetch_seasons.dart` and read
  through `AssetSeasonCacheService`. The web never fetches the live config, so the
  config and the season snapshots always match.
- Wide windows: `WebFrame` caps the app to a 600 px column.
- GitHub disables `schedule` workflows in public repos after 60 days without
  repo activity; if the nightly build stops, re-enable it in the Actions tab.
- Running the prefetch locally leaves a ~650 KB snapshot in `assets/prefetched/`
  that also goes into local release APKs (no secrets, just data). Before a
  release APK: `rm assets/prefetched/season*.json assets/prefetched/remote_config.json`.

**Note on Windows:** Under Git Bash on Windows, prefix the web build with `MSYS_NO_PATHCONV=1`
or the `--base-href /FamilyMafiaApp/` argument gets mangled into a Windows path.

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
