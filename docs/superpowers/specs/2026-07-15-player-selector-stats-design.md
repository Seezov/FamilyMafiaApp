# Player Selector on Stats Screen — Design

**Date:** 2026-07-15

## Goal

Add a searchable player selector to the stats screen (formerly "Debug"). Typing shows a dropdown of matching players; selecting one shows that player's win-rate-by-slot. When no player is selected, the screen shows global per-slot win rate across all players.

## Current State

- `lib/screens/debug/debug_screen.dart` renders win-rate-by-slot for a hardcoded `kDebugPlayer` ("Seezov").
- `lib/screens/debug/debug_providers.dart`:
  - `kDebugPlayer = 'Seezov'`
  - `SlotWinRate` typedef: `({int slot, int played, int wins, double winRate})`
  - `winRateBySlot(List<Game> games, String player)` — exact-string slot match via `game.getPlayerSlot(player)`.
  - `debugSlotWinRateProvider` — watches games, computes for `kDebugPlayer`.
- `lib/screens/players/players_providers.dart`:
  - `playersListProvider` — `List<Player>` sorted by total games desc, excluding invalid/empty.
  - Search pattern: `playerSearchQueryProvider` + `filteredPlayersProvider` (case-insensitive `displayName.contains`).
- `Player` has `displayName` and `nicknames` (`List<String>?`). Nickname-based matching precedent: `playerBestMovesProvider` uses `player.nicknames ?? [player.displayName]`.

## Decisions

1. **Global (no selection):** per-slot win rate across ALL players — for each slot 1-10, every rating-game seat counts as played, and a win if that seat won (`hasPlayerWon` on the seat's name).
2. **Matching:** dropdown lists canonical `displayName`s (like the Players tab). Per-player slot stats aggregate across ALL of that player's nicknames.
3. **Default state:** starts global with an empty search field. No hardcoded default player; `kDebugPlayer` is removed.

## Architecture

### State
- New `selectedPlayerProvider = StateProvider<Player?>((ref) => null)` in `debug_providers.dart`. `null` = global.

### Computation (`debug_providers.dart`)
- `winRateBySlotGlobal(List<Game> games) -> List<SlotWinRate>`: iterate rating games; for each seat index 0..9 with a non-empty player name, increment played, and increment wins if `game.hasPlayerWon(seatName)`.
- `winRateBySlotForPlayer(List<Game> games, Player player) -> List<SlotWinRate>`: for each rating game, find the first nickname in `player.nicknames ?? [player.displayName]` present in `game.players`; if found and its slot is 0..9, increment played, and wins if `hasPlayerWon(name)`.
- `debugSlotWinRateProvider` watches `gamesRepositoryProvider` + `selectedPlayerProvider`; returns global when null, else per-player.
- Remove `kDebugPlayer` and the old string-based `winRateBySlot`.

### UI (`debug_screen.dart`)
- AppBar title: selected player's `displayName`, else `'Statistics'`.
- Top of the ListView: an `Autocomplete<Player>` search field.
  - Options: `playersListProvider`, filtered by case-insensitive `displayName.contains(query)`. Empty query → no dropdown (or full list — implementation detail; keep it responsive).
  - `displayStringForOption` = `displayName`.
  - On selected: set `selectedPlayerProvider`.
  - Trailing clear (×) button when a player is selected → resets provider to `null` and clears the field.
- Slot rows and overall summary re-render from `debugSlotWinRateProvider` reactively (unchanged rendering).

## Data Flow

search text → Autocomplete options from `playersListProvider` → user selects → `selectedPlayerProvider` → `debugSlotWinRateProvider` recomputes → AppBar title + slot rows update. Clear → provider null → global.

## Error Handling

- Player with only invalid/empty names is already excluded by `playersListProvider`.
- Slot index guarded to 0..9 (existing behavior).
- Empty games / no matches → all-zero rows rendering "—" (existing behavior).

## Testing

- `winRateBySlotGlobal`: aggregates all seats across rating games; ignores non-rating games; empty input → zeros.
- `winRateBySlotForPlayer`: player matched via a secondary nickname is counted; absent player → zeros; ignores non-rating games; mafia-role win counted.
- Existing `debug_providers_test.dart` tests updated to the new function names/signatures.

## Out of Scope (YAGNI)

- Fuzzy search, selection persistence, multi-select, additional stat types.
