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
```

## Flutter Architecture

Riverpod + Dart, Jetpack-style layering.

**Layers:**
- `lib/constants/` — `season_constants.dart` (all season boundaries, formula thresholds, player exclusions with doc comments)
- `lib/screens/` — Flutter screens, each with a `_providers.dart` sidecar
  - `home/` — `HomeScreen` (season selector + per-season player rating list); split into `src/` parts: `loading_indicator`, `background_loading_banner`, `season_chips`, `game_limit_picker`, `season_header_card`, `player_card`
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

`main.dart` uses a `NavigationBar` + `IndexedStack` with three tabs:
- **Season** (`HomeScreen`) — per-season player rating list (season chips + expandable player cards)
- **Players** (`PlayersScreen`) — full player roster grid with search and tap-through to `PlayerProfileScreen`
- **Dashboard** (`DashboardScreen`) — placeholder

> **"Players screen"** always refers to `PlayersScreen` (`lib/screens/players/players_screen.dart`), not `HomeScreen`.

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
