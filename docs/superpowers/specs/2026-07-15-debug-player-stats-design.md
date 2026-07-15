# Debug Player Stats Screen — Design

## Purpose

A developer-facing debug screen for inspecting statistics of a single hardcoded
player, derived from the rating games currently loaded in the database
(`gamesRepositoryProvider`). Built to be iterated on: the first statistic is
**win rate by player slot**, with more stats added over time.

## Scope (first iteration)

- Hardcoded player: `Seezov`.
- Single statistic: win rate per player slot (slots 1–10), computed over rating
  games only (`Game.isRatingGame() == true`).

## Entry Point

Add a 4th tab **"Debug"** to the `NavigationBar` + `IndexedStack` in
`main.dart`, alongside Season / Players / Dashboard.

## Files

Following the existing screen convention (screen + `_providers.dart` sidecar):

- `lib/screens/debug/debug_screen.dart` — `ConsumerWidget`. Hardcodes
  `const _kDebugPlayer = 'Seezov'`. Renders the per-slot win-rate list.
- `lib/screens/debug/debug_providers.dart` — provider computing the per-slot
  stats for the hardcoded player.

## Logic

For the hardcoded player, over all games where `isRatingGame()`:

1. Determine the player's slot in each game via `game.getPlayerSlot(player)`
   (returns index 0–9; `-1` if not in that game — skip those).
2. Bucket by slot. For each slot (index 0–9, displayed as 1–10):
   - `played` = number of rating games the player was in that slot.
   - `wins` = number of those where `game.hasPlayerWon(player)` is true.
   - `winRate` = `wins / played` (0 when `played == 0`).
3. Emit an ordered list of 10 slot records `{slot, played, wins, winRate}`.

The provider derives from `gamesRepositoryProvider`, so it recomputes when games
load/change.

## Display

- A header line with overall totals (total rating games the player appears in,
  total wins, overall win rate).
- A list of 10 rows, one per slot, each showing:
  `Slot N · wins/played · XX.X%`
  with a horizontal bar proportional to win rate.
- Slots with `played == 0` are greyed out and show `—` instead of a percentage.

## Non-goals

- No runtime player selection (hardcoded for debug).
- No persistence, export, or non-rating-game stats.
- Not intended for end users; lives behind the Debug tab.

## Extensibility

Additional statistics (per-role win rate, first-kill rate, best-move points,
etc.) will be added as further sections on this same screen in later iterations.
