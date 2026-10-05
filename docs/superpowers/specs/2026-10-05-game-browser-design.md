# Game browser on the site — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

The club is moving off Google Sheets. Today anyone can open the season sheet and look at any game;
the site must replace that. Every game of every season (0–31 and every Firestore season after) gets
a public, read-only card: seating, roles, the per-seat points columns, ПУ and best move/support
five, the protocol, the host's comments, and the event label it was played under. A player's
profile links to "their games" in each season.

## Decisions

| Topic | Decision |
|---|---|
| Seasons | All, 0–31 and Firestore seasons. Old seasons show what they have; empty blocks are hidden. |
| Access | Public, no sign-in, read-only. Editing stays on `/host/`. |
| Rendering | Static HTML at build time, one page per season: `/season/N/games/` |
| Game card | `<details>` per game, anchor per game, deep link opens and scrolls to it |
| Filters | Player and host, in the URL (`?player=<slug>&host=<name>`), small client script |
| Comments | Parsed from the sheet snapshots in all six historical formats + Firestore `comments` |
| Event labels | Title rows above game blocks (seasons 19–30): «СТІЛ 1», «МІНІКАП», «ФІНАЛ МІНІКАПІВ», … |
| App | `Game` gains optional fields; the Flutter app's screens are unchanged |
| Which pass | The rules pass (`sheet: false`). The sheet-quirk pass only feeds the main-league table. |

## What the user sees

### `/season/N/games/`

A third tab on the season page next to «Рейтинг» and «Мала ліга».

- **Toolbar:** player filter (input with autocomplete from the season's players), host filter
  (select), counter «N ігор». Filters live in the query string, so a filtered view is a link.
- **List**, grouped by evening: heading «Пн, 1 вересня 2026 · 6 ігор». Within an evening, games
  are grouped by table when the season knows tables («Стіл 1», «Стіл 2»); otherwise one list.
  A game row: `№ · ведучий · результат (Місто / Мафія / Не рейтинг)` plus its event label if any.
  With a player filter the row also shows that player's role and their «Разом» for the game.
  Games with no date (typos the parser couldn't read) go in a final «Без дати» group.
- **Expanded card** — a table of the 10 seats:
  `№ · Гравець · Роль · Фоли · Бал · Доп · КХ/ОП · Штраф · ПрДод · ПрШтраф · Разом`
  - Бал = 1 if the seat won, else 0 (as the sheet's Бал column). Разом = Бал + Доп + КХ/ОП +
    Штраф + ПрДод + ПрШтраф (penalties are stored negative, so this is a plain sum). No СІ top-up
    — that is per season, not per game.
  - The КХ/ОП column is labelled as the season's sheet labels it: «ЛХ» for 2–16, «КХ» for
    17–28, «ОП» for 29+.
  - A column that is empty for every seat of this game is not rendered (fouls before Firestore
    seasons, ПрДод/ПрШтраф before 29, …).
  - Roles use the site's role colours. Players with a site page link to it and go through
    `PlayerName` (profile nick/avatar). A blank seat shows «—».
- **Under the table**, each only when present: ПУ (seat + name) and best move / support five with
  its points; protocol in kill order (killed seat, sheriff version, colour guesses red/black);
  comments («6 — Зняв 1, заповіт зняти 10»; a comment for several seats lists them «3, 6 — …»;
  a comment with no seat is shown as a note on the game).
- **Link button** on each card copies `…/season/N/games/#<gameId>`. Opening a URL with that hash
  opens the card and scrolls it into view (also clears any filter that would hide it).
- **Phone:** the seat table scrolls horizontally inside the card; the page itself never does.

### Player profile

In the per-season table of `/players/<slug>/`, the games count becomes a link to
`/season/N/games/?player=<slug>`.

## Data

### `Game` model (`lib/models/game.dart`)

New optional fields (null = not known), no change to existing ones:

```dart
List<GameComment>? comments,  // host's comments, sheet order
String? label,                // event label above the game block («МІНІКАП», «Гра 3», …)
int? table,                   // 1/2 when known: Firestore `table`, or a «Стіл N» label
```

```dart
@freezed
class GameComment with _$GameComment {
  const factory GameComment({
    @Default([]) List<int> seats, // 1-indexed; empty = about the whole game
    required String text,
  }) = _GameComment;
}
```

### Sheet comments — where they are

Checked across every snapshot (`assets/raw/season0–28.json`, `assets/prefetched/season29–31.json`)
and the live sheets (no cell notes, nothing beyond column Q):

| Seasons | Location | Volume | Parsing |
|---|---|---|---|
| 0–1 | A row of its own between games, text in A («Ничья, всем по 1 баллу») | 3 | Game comment on the game **before** it |
| 2–16 | Free text in column C of seat rows 4–8 (the sidebar's spare cells; B is empty there) | 2 | Game comment |
| 17–18 | Row with «Додаткові бали:» in B, text in C, lines like `3 - виграв версію` | 3 cells | Split into lines, then seat prefix (below) |
| 19–28 | Block headed «Номер · Коментарі до дод балів» after the game; pairs number→text in B/C and a second pair in G/H or H/I | ≈3 100 | Pairs (below) |
| 29–31 | Same block, two header columns B/C and G/H; sometimes everything in one cell («5 0.1 ОП\n1 0.6 вписався…», «3,6 - були мирні…») | ≈650 | Pairs, then seat prefix on each line |

Rules for 17+:

- The comment area of a game is the rows from the «Коментарі до дод балів» / «Додаткові бали:»
  row up to the next game's «Дата» row (or a title row). Text anywhere else near a game is ignored
  — season 18 has hosts chatting in G/H/I under games («мьі це сізоу я тян…»).
- **Pair:** a text cell whose left neighbour holds a seat number → that seat. A neighbour like
  `6.9`, `3,6` or `3, 6` → several seats. A neighbour that the sheet turned into a date
  (`2025-05-06T21:00:00.000Z`) is not guessed: the comment goes in without seats.
- **Seat prefix:** a text without a number cell is split into lines; a line starting with
  `N`, `N,M`, `N.`, `N -`, `N:` takes those seats and the rest is the text. A line like
  `5 0.1 ОП` keeps «0.1 ОП» as text. Lines with no prefix → comment without seats.
- Seat numbers outside 1–10 make the line a comment without seats.
- Labels are not comments: «Номер», «Коментарі до дод балів», «Додаткові бали:», «Відстріл»,
  «Голоси», «Голосування N», «Гравець». Empty and whitespace-only cells are skipped.

### Event labels and tables (17+)

A row with only column A filled, within the 3 rows above a «Дата» row, is the label of that game
(seasons 19–30 have ≈40: «1 стіл», «2-ИЙ СТІЛ», «МІНІКАП», «Family Combat DAY 1», «Гра 3»,
«Максікап 2025-11-25», «Стіл 1, гра 1»…). A label naming a table (`стіл` with a 1 or 2, any case,
«1-ИЙ»/«2-ИЙ» included) sets `table` for that game **and the following games of the same date**
until another table label; such a label is not also shown as an event label. Any other label is
stored in `label` for that one game.

### Aligning sheet extras with games

The game parser never sees these rows: `_filterRawData` drops rows with an empty A or C (17+) or a
non-numeric A (≤16) before chunking. So the extras come from a separate pure function over the
**unfiltered** rows:

```dart
/// Comments, label and table of each game in sheet order, from the raw rows.
List<SheetGameExtras> sheetGameExtras(int seasonId, List<GamesDataSeason> raw);
```

It walks the raw rows and cuts games at the same anchors the chunker relies on: the «Дата» row
(17+), the seat-1 row (2–16 and 0–1). `_parseSeasonGames` zips the result onto the parsed games by
index. A test asserts, for every bundled and prefetched season, that the number of anchors equals
the number of parsed games — if a sheet ever breaks that, the test names the season rather than the
site silently attaching comments to the wrong game.

### Firestore games

`gamesFromFirestoreSnapshot` maps the document's `comments` (`{slot, text}` → `seats: [slot]`,
`slot: 0` → no seats) and `table`. No label.

### Export (`lib/site_export/games_export.dart`)

Writes `site/data/games/N.json` per season, from the same loaded games the rest of the export uses:

```
{ season: N, columns: { auto: 'КХ' | 'ЛХ' | 'ОП' },
  players: [{ name, slug? }],                 // for the filter
  hosts: [name],
  days: [{ date: 'YYYY-MM-DD' | null,
           games: [{ id, n, table?, label?, host?, result: 'city'|'mafia'|'unrated',
                     seats: [{ n, player?, slug?, role, fouls?, won, add, auto, pen, prAdd, prPen, total }],
                     firstKilled?, bestMove?: { seats: [int], points },
                     supportFive?: [{ seat, black }],
                     protocol?: [{ killed, version?, colors: [{ seat, black }] }],
                     comments?: [{ seats: [int], text }] }] }] }
```

- `id` = `g-YYYY-MM-DD-<table or 1>-<n>`, where `n` is the game's order within its date and
  table; games with no date: `g-x-<index>`. Unique within the season (asserted).
- Numbers are written as the site shows them (2 decimals, trailing zeros dropped), like the other
  exports. Empty values are omitted so old seasons stay small.
- Blank seats (`_blank_*`) are written without `player`.

### Site (`site/`)

- `src/pages/season/[id]/games/index.astro` — renders the page from `data/games/N.json` at build
  time; tab link added to `SeasonPage.astro`.
- `src/components/GameCard.astro` — one game (`<details>` + seat table + blocks under it).
- `src/scripts/games.ts` — filters from/to the query string, open-on-hash, copy link. Pure parts
  (`parseFilters`, `matchesFilters`, `gameIdFromHash`) in `src/lib/games.ts` with unit tests.
- `src/pages/players/[slug].astro` — games count per season links to the filtered page.
- `scripts/check-dist.mjs` already fails on broken links; it now also covers the profile →
  games links (anchors are not checked; the query string is ignored).

## Error handling

- A season whose games JSON is missing fails the build (as other data does), not the page.
- A comment the parser can't attribute is kept without seats, never dropped.
- A malformed Firestore comment (missing text) is skipped; the game still loads.

## Testing

Dart:
- `sheetGameExtras` on real row fixtures cut from the snapshots, one per format: S0 standalone
  row, S13 sidebar note, S18 «Додаткові бали:» multi-line, S21 pairs in B/C + H/I, S26 G/H,
  S29 one-cell multi-line «5 0.1 ОП…», S30 `6.9`, S28 date-in-number cell, S18 host chat ignored,
  S25 «СТІЛ 1» setting the table for following games, S27 «Гра 1» as a label.
- Anchor count == parsed game count for every bundled and prefetched season.
- Firestore comments and table mapping.
- `games_export`: per season, game count == season summary games; 10 seats per game; ids unique;
  totals equal the sum of the columns.

Site:
- `src/lib/games.ts` unit tests (vitest, as the existing `*.test.ts`).
- `npm run build` + `check-dist` pass; manual look at S5, S22, S31 at desktop and phone width.

## Out of scope

- Editing games from this page (stays on `/host/`).
- Per-game pages / OG previews per game.
- «Відстріл» (not filled in recent seasons) and the S23 voting rows.
- Host score («Бал ведучого») — separate item.
