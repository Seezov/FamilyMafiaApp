# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Flutter migration complete.** The original Android/Kotlin code is preserved on `master`. This branch (`feature/flutter_migration`) is Flutter-only.

---

## Build Commands

```bash
flutter run                      # Run on connected device/emulator
flutter build apk --debug        # Debug APK
flutter build apk --release      # Release APK
flutter analyze                  # Static analysis
flutter test                     # Unit tests
dart run build_runner build      # Regenerate freezed / json_serializable code
dart run build_runner watch      # Watch mode for code generation
```

## Flutter Architecture

Riverpod + Dart, Jetpack-style layering.

**Layers:**
- `lib/screens/` — Flutter screens, each with a `_providers.dart` sidecar
  - `home/` — `HomeScreen` (season selector + per-season player rating list)
  - `players/` — `PlayersScreen` (grid of all players, tap → `PlayerProfileScreen`); `players_providers.dart` owns `playersListProvider`, `filteredPlayersProvider`, `playerSearchQueryProvider`, `playerAccomplishmentsProvider`
  - `dashboard/` — `DashboardScreen` (placeholder)
- `lib/repositories/` — Riverpod `StateNotifierProvider` singletons:
  `GamesRepository`, `PlayersRepository`, `RatingRepository`, `SeasonRepository`
- `lib/services/season_loader.dart` — loads all 29 seasons from `assets/raw/`, computes ratings, populates repositories
- `lib/providers/app_providers.dart` — `appDataProvider` (FutureProvider) triggers full load on first watch
- `lib/models/` — Dart models (freezed + json_serializable):
  `Game`, `Player`, `RatingPlayerStats`, `SeasonStats`, `YearStats`, `PlayerPlacements`, `SlotStats`, `Stats`, `BestMoves`
- `lib/enums/` — `Role`, `Season` (0–28), `GameValues`
- `lib/extensions/` — `double_extensions.dart`, `list_extensions.dart`

No local database — all data loaded from `assets/raw/*.json` (one per season + `players.json`).

## Flutter Data Flow

1. `appDataProvider` is watched by each screen; shows a spinner until resolved
2. `SeasonLoaderService.loadAll()` reads every season JSON → parses → populates all four repositories
3. `RatingRepository` / `SeasonRepository` hold pre-computed `RatingPlayerStats` / `SeasonStats`
4. Screen-level providers (e.g. `selectedSeasonProvider`, `seasonGamesProvider`) derive view data from repositories
5. Screens are `ConsumerWidget`s that `ref.watch` their providers

## Navigation

`main.dart` uses a `NavigationBar` + `IndexedStack` with three tabs:
- **Season** (`HomeScreen`) — per-season player rating list (season chips + expandable player cards)
- **Players** (`PlayersScreen`) — full player roster grid with search and tap-through to `PlayerProfileScreen`
- **Dashboard** (`DashboardScreen`) — placeholder

> **"Players screen"** always refers to `PlayersScreen` (`lib/screens/players/players_screen.dart`), not `HomeScreen`.

## Adding a New Season (Flutter)

1. Add the season JSON to `assets/raw/`
2. Add a new entry to `lib/enums/season.dart` with correct `id`, `title`, `jsonFile`, `gameLimit`, and `gamesMultiplier`

## Key Stack

- Dart / Flutter 3.x, Material 3
- Riverpod 2.6.1, freezed + json_serializable (KSP-equivalent via build_runner)
- Dio 5.x (HTTP), go_router 14.8.1 (wired up later)
- minSdk 29

---

## Legacy Android Code

The original Kotlin/Jetpack Compose app is preserved on the `master` branch.
Architecture: MVVM + Hilt DI, Retrofit for Google Sheets API, JSON from `res/raw/`.
