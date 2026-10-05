# Dynamic game threshold — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

The main-league threshold (the season's `gameLimit`) stops being a number typed into the config.
While a season is being played it follows the sheet's formula; when the season ends it freezes,
and an admin may set a different final value on `/debug/`.

## The sheet's rule

The S31 sheet («Судді», «Поточний поріг:») computes:

```
threshold = (g1 + g2 + g3) / 3 × 0.6 − 5
```

where g1–g3 are the rating-game counts of the three most active players of the season. Checked
against the exported games: S28 → 55.0 (config 55), S29 → 50.2 (50), S30 → 40.6 (40),
S31 today → 15.4 (sheet shows 15,4). A player is in the main league when
`gamesPlayed >= threshold`, so with 15.4 the main league starts at 16 games.

## Decisions

| Topic | Decision |
|---|---|
| Which seasons | Those with `"gameLimitRule": "top3"` in the config: S31 and every new season. S0–30 keep their fixed `gameLimit` (they already match the sheets). |
| In progress | `seasonInProgress(gameDates, now)` (calendar quarters, already used for accomplishments). While true: threshold = formula, unrounded. |
| Season ended | `gameLimit` from the config if set (admin's value), else `ceil(formula)` from the final data. |
| Integer limit | Every existing consumer keeps comparing against the int `gameLimit`; for a formula season it is `ceil(threshold)` (same split as `>= 15.4`). Below 0 → 0. |
| Display | Season page: «Поточний поріг: 15,4» while in progress; «Поріг: 41» after. Player profile (current season, below threshold): «До основної ліги: ще N ігор». |
| Admin | `/debug/` gets a «Пороги» section: each ended `top3` season shows the formula value and an input; saving writes `gameLimit` into `remote_config.json` and `assets/raw/season_config.json` in one commit, like tournament edits. Clearing the input removes `gameLimit` (back to the formula). |
| Small league | Unchanged: `smallLeagueMinGames` ≤ games < `gameLimit`. Early in a season it can be empty, as in the sheet. |
| App | Gets the same effective `gameLimit` through `loadedSeasonConfigsProvider`; its screens need no change. The manual `gameLimitOverrideProvider` slider still overrides on top. |

## Data flow

1. `SeasonConfig` gains `gameLimitRule` (`fixed` default | `top3`) and `double? liveThreshold`;
   `gameLimit` becomes optional in JSON when the rule is `top3`.
2. `SeasonMeta` carries the rule, the configured limit (nullable) and `now`.
3. In the isolate, after a season's games are parsed and per-player stats computed (they do not
   depend on the limit), `effectiveThreshold(meta, playerStats, gameDates)` returns
   `(int gameLimit, double? live)`; season stats and role percentiles are then generated with
   that limit. The result goes back with the season's output.
4. The loader replaces each loaded config with `config.copyWith(gameLimit: …, liveThreshold: …)`
   before publishing `loadedSeasonConfigsProvider`, so records, leagues, accomplishments, chat and
   the site export all use the effective value.
5. `season_export.dart` writes `liveThreshold` next to `gameLimit`; the site renders it.

Pure function, in `lib/services/stats/threshold.dart`:

```dart
double formulaThreshold(Iterable<int> ratingGames); // top 3, padded with 0, ×0.6 − 5
({int gameLimit, double? live}) effectiveThreshold({
  required String rule, required int? configured,
  required Iterable<int> ratingGames, required List<DateTime> gameDates, required DateTime now});
```

## Config changes

- S31 in both config files: add `"gameLimitRule": "top3"`, remove `"gameLimit": 40`.
- Season 32 (added at go-live) gets `"gameLimitRule": "top3"` without `gameLimit`.
- `CLAUDE.md` «Adding a New Season» mentions the rule.

## Error handling

- `top3` season with fewer than 3 players: missing counts are 0 (as the sheet's `IFERROR(…;0)`).
- A `fixed` season without `gameLimit` is a config error (as today: load fails for that season).
- `/debug/` rejects a non-integer or negative threshold.

## Testing

- `formulaThreshold`: S28/S29/S30/S31 counts → 55.0 / 50.2 / 40.6 / 15.4; fewer than 3 players.
- `effectiveThreshold`: in progress → ceil + live; ended without configured → ceil, live null;
  ended with configured → configured; `fixed` → configured always; negative → 0.
- Loader: S31 fixture with a fixed clock in October → `gameLimit` 16, `liveThreshold` 15.4;
  with a clock in December → 16, null.
- Site: season page shows the live line; `config-edit` op for thresholds (vitest);
  `npm run build` + `check-dist`.

## Out of scope

- Changing thresholds of S0–30.
- A dynamic small-league threshold.
