# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
./gradlew build                  # Full build
./gradlew assembleDebug          # Debug APK
./gradlew test                   # Unit tests
./gradlew connectedAndroidTest   # Instrumented tests (requires device/emulator)
./gradlew lint                   # Lint checks
```

## Architecture

MVVM app with Hilt DI, Jetpack Compose UI, and Retrofit for Google Sheets API.

**Layers:**
- `ui/` — Compose screens (`HomeScreen`, `DashboardScreen`, `HallOfFameScreen`) each paired with a Hilt ViewModel
- `repository/` — In-memory singletons: `GamesRepository`, `PlayersRepository`, `RatingRepository`, `SeasonRepository`
- `entities/` — Data models: `Game`, `Player`, `RatingPlayerStats`, `SeasonStats`, `YearStats`
- `enums/` — `Role` (SHERIFF/CIVILIAN/MAFIA/DON), `Season` (0–28), `Values`
- `network/` — `GoogleSheetService` (Retrofit, Google Apps Script endpoint)
- `extensions/` — Math utilities (`Float.roundTo`, `Double.roundTo2Digits`, list helpers)

No local database — all data is loaded from JSON files in `res/raw/` (one per season) plus optional Google Sheets API calls.

## Data Flow

1. `Season` enum references a JSON resource ID and game limit per season
2. `GamesRepository` parses raw JSON into `Game` objects
3. `RatingRepository` / `SeasonRepository` compute `RatingPlayerStats` / `SeasonStats` from games
4. ViewModels expose `StateFlow<UiState>` consumed by Compose screens

## Adding a New Season

1. Add the season JSON to `res/raw/`
2. Add a new entry to the `Season` enum in `enums/Season.kt` with correct `id`, `title`, `jsonRes`, `gameLimit`, and `gamesMultiplier`

## Key Stack

- Kotlin, Jetpack Compose + Material 3
- Hilt (KSP), Retrofit + Gson, Coroutines, Navigation Compose
- compileSdk 35 / minSdk 29 / Java 1.8
