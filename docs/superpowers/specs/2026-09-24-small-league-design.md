# Small League (Мала Ліга) — Design

## Purpose

Every club season runs a second standing alongside the main rating: the
**small league** (`Мала Ліга`), for players who took part often enough to be
ranked but not often enough to qualify for the main league.

The app currently shows only the main league standing on `HomeScreen`. This
adds the small league as a second view over the same season data.

## Key finding: no new rating maths

Each season spreadsheet has a `Мала Ліга` tab next to the `Рейтинг` tab. A
column-by-column diff of the two tabs across three seasons (Літо 2026,
Весна 2026, Літо 2025) shows they hold **identical data**:

| Season | Players in `Мала Ліга` | Players in `Рейтинг` | Rows with differing game count | Rows with differing score |
|---|---|---|---|---|
| Літо 2026 | 196 | 196 | 0 | 0 |
| Весна 2026 | 196 | 196 | 0 | 0 |
| Літо 2025 | 142 | 142 | 0 | 20 (rounding only, e.g. `107.5766` vs `107.5812`) |

Same player set, same game counts, same `Бал`. The tabs differ only in row
order and one unlabelled helper column. The actual selection is done by a
spreadsheet **filter view**, which the Sheets API does not expose — which is
why the bounds cannot be recovered from the sheet data and had to come from
the club.

**Consequence:** the small league is a *filter over already-computed
`RatingPlayerStats`*, not a second rating formula. `rating_formulas.dart` is
not touched.

## Definition

A player belongs to the small league for a season when:

```
smallLeagueMinGames <= gamesPlayed < gameLimit
```

- The **upper bound is the existing `gameLimit`** — confirmed as always the
  same number as the main league's qualification threshold, so it is not
  stored twice and cannot drift.
- A player with exactly `gameLimit` games is in the **main league only**.
  The main league condition stays `gamesPlayed >= gameLimit`, unchanged.
- The leagues do not overlap.

### Lower bounds per season

Default is `15`, with four exceptions confirmed by the club:

| Season(s) | `smallLeagueMinGames` | Reason |
|---|---|---|
| 0 | `8` | Short first season, `gameLimit: 17` — see below |
| 6 | `30` | Doubled season, `gameLimit: 70` |
| 12, 14, 15 | `20` | — |
| all others | `15` | Default |

**Season 0** needed a judgement call. At the default `15` its band is `15–16`
and contains a single player. Across other seasons the ratio of lower bound to
`gameLimit` sits between 0.25 and 0.43; applied to `gameLimit: 17` that
suggests 5–7, but those bands hold 14–19 players — larger than the season's
own main league. `8` gives the band `8–16` with 11 players, matching the 11 in
the main league.

### Validation

Bounds were checked against the raw games of all 29 bundled seasons. Every
season yields a non-empty small league (8–27 players), comparable in size to
its main league. Counts are approximate (±2–3) because the check did not apply
the non-rating-game filtering that `data_filtering.dart` performs.

## Changes

### `lib/models/season_config.dart`

Add `final int smallLeagueMinGames;`.

Parse as `json['smallLeagueMinGames'] as int? ?? 15` — optional with a
default, so an older `remote_config.json` and any locally cached config
written by a previous app version keep parsing. No migration needed.
Include the field in `toJson()`.

### `lib/enums/season.dart`

Add the same field to the enum for the 29 bundled seasons, with the per-season
values from the table above.

### `remote_config.json`

Add `"smallLeagueMinGames": 15` to seasons 29 and 30.

### `lib/screens/home/home_providers.dart`

```dart
enum League { main, small }

final selectedLeagueProvider = StateProvider<League>((ref) => League.main);
```

`currentSeasonStatsProvider` branches on the selected league:

```dart
League.main  => p.gamesPlayed >= limit
League.small => p.gamesPlayed >= season.smallLeagueMinGames && p.gamesPlayed < limit
```

`hasQualifyingPlayersProvider` becomes league-aware: it applies the same
predicate as the selected league (against the season's *default* `gameLimit`,
as it does today, not the override). Otherwise an empty small league renders
the existing "No players meet this game limit" message, which states the wrong
reason.

**Interaction with `gameLimitOverrideProvider`:** the league toggle and the
manual game-limit override both control the same threshold, and together they
produce a contradictory state. Selecting the small league resets the override
to `null`, mirroring what `season_chips.dart:41` already does on season change.

### `lib/screens/home/home_screen.dart`

A `SegmentedButton<League>` below the season chips, with two segments:
**Основна** / **Мала**.

### `lib/screens/home/src/season_header_card.dart`

Show the active band (e.g. `15–39 ігор`) so the selection criterion is visible.

When the small league is empty for a season, the segment stays selectable and
the list shows an explanation naming the actual bounds, rather than the
generic game-limit message.

## Testing

`test/screens/home/home_providers_test.dart`:

- With `gameLimit: 40, smallLeagueMinGames: 15`, players with
  `14 / 15 / 39 / 40 / 41` games each land in exactly one league, and `40`
  lands in the main league.
- The main league result is unchanged from current behaviour.
- Selecting the small league clears `gameLimitOverrideProvider`.
- `SeasonConfig.fromJson` without `smallLeagueMinGames` yields `15`.

## Out of scope

- The chat/Gemini layer (`lib/services/chat/`, `gemini_chat_service.dart`)
  filters by `gameLimit` in several places. Teaching it about the small league
  is a separate change.
- `PlayerProfileScreen` does not gain a league dimension.
- The `Ліга №1`, `Школа` and tournament tabs present in some season
  spreadsheets are unrelated to this feature.
