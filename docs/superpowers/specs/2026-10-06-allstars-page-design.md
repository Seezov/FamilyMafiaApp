# Annual tournaments («Річні турніри») page — design

Date: 2026-10-06
Status: approved in chat, awaiting written-spec review

## Goal

A separate site page for the club's yearly all-star tournaments: who won each year, the full
final table and the nominations. Today they are scattered over season sheets, a standalone sheet
and the federation site; only two of the five are on `/tournaments/` at all.

User decisions (2026-10-06): nominations for the years without official ones are **computed from
the games**; fantasy leagues and Rookie of the Year 2019 are **not shown**; URL `/allstars/`,
page title «Річні турніри».

## The events (verified 2026-10-06)

| Year | Event | Played | Winner | Final table | Games | Nominations |
|---|---|---|---|---|---|---|
| 2019 | Royal Battle '19 | Dec 2019 (no dates in sheet) | Рауль | sheet 0–9 tab `Royal Battle '19` | tab `Royal Battle 2019 Games`, 15 per player | computed |
| 2022 | Family All Stars 2022 | 14–15.01.2023, host Саймон | Луна | sheet `1ITv-laaBJnzoSTPsTPrPkkyJJI6MZBaMFljx8PJf0AY` tab `Рейтинг` | same sheet, tab `Игры` | computed |
| 2023 | Family All Stars 2023 | Dec 2023 (sheet dates are a template 05.09.2023), host Катана | Seezov | S20 sheet tab `FAS 2023` | S20 tab `FAS 2023 Ігри` | computed |
| 2024 | Family All Stars 2024 | 17–19.01.2025, judge Jf | Braun | emotion.games/ua/tournament/385/results | federation only | official |
| 2025 | Family All Stars 2025 | 16–18.01.2026, judge Темна Фурія, organiser Braun | Tina | emotion.games/ua/tournament/572/results | federation only | official |

A year is the year the event belongs to (FAS 2024 was played in January 2025). No events in
2020–2021.

## Data: a committed snapshot

`assets/raw/allstars.json` — one entry per event, written once by a one-off script
(`tool/snapshot_allstars.py`, kept in the repo) from the sheets and, for 2024–2025, by hand from
the federation pages. Nothing is fetched at build time: the federation site is JS-rendered and
the sheets are historical.

```jsonc
{
  "events": [
    {
      "year": 2025,
      "name": "Family All Stars 2025",
      "date": "16–18.01.2026",          // free-form, like Tournament.date
      "host": "Темна Фурія",            // ведучий or суддя
      "hostLabel": "Суддя",             // «Ведучий» | «Суддя»
      "source": "https://emotion.games/ua/tournament/572/results", // optional
      "columns": ["Бали", "Ігри", "Перемоги", "Доп", "Штрафи", "ЛХ", "Ci"],
      "standings": [ { "player": "Tina", "values": ["11.3", "15", "7", "4.3", "0", "0", "0"] } ],
      "nominations": [                  // present only when official
        { "key": "mvp", "top": [ { "player": "Tina", "value": "4.30" } ] }
      ],
      "games": [                        // present only when nominations are computed
        { "seats": [ { "player": "Тян", "role": "civilian", "add": 0, "bestMove": 0 } ],
          "firstKilled": 1 }
      ]
    }
  ]
}
```

- **Standings** are copied from the event's final table as they are, in its order and with its
  own columns ("sheets are truth" — no recomputation, values stay strings formatted as in the
  source). Player names are kept as written; the export resolves them with the roster
  (`PlayerResolver`), so «Железный»/«Залізний» and «StoneCold Steve Austin 316»/«StoneCold» link to
  one profile. Unresolvable names render as plain text.
- **Games** (2019, 2022, 2023) keep only what nominations need: per seat the player, role,
  additional points (`add`, negative = penalty, as the sheets store it) and best-move points, plus
  the first-killed seat. The script reads the three layouts:
  - Royal Battle '19 / FAS 2022 (old layout): 10-row blocks; `Роль`, `Допы`, `ЛХ` columns per seat;
    `ПУ` = first-killed seat; `ЛХ` row lists the best-move picks.
  - FAS 2023 (S17+ layout): `Роль`, `Доп` (ДБ), `КХ` per seat; `ПУ` row = first-killed seat.
    Its `АД` column (automatic points for every player) is **not** additional points.
- The script checks each event: game count per player equals the final table's «games» column,
  and per-player sum of `add` equals the table's «Допы»/«ДБ» column. It refuses to write the
  file if either check fails.
- Adding next year's FAS = append an entry (federation results copied by hand). Documented in
  CLAUDE.md.

## Nominations

Four, top 3 each, matching the federation's results page:

| Key | Label | Value |
|---|---|---|
| `mvp` | 🏅 MVP | Σ additional points = add (incl. negative penalties) + best-move points |
| `firstKilled` | 💀 Найчастіше убитий першим | times killed first |
| `bestRed` | 👍 Кращий червоний | Σ additional points in civilian/sheriff games |
| `bestMafia` | 👎 Краща мафія | Σ additional points in mafia/don games |

Federation compensation for first-kill (`Ci`) is not part of any nomination — the federation's
own numbers confirm it: in FAS 2024 and 2025, best red + best mafia = MVP for each player
(Braun 2024: 3.2 + 1.3 = 4.5; Tina 2025: 3.0 + 1.3 = 4.3).

Computed in `lib/services/stats/allstars_nominations.dart` (pure function, games → four ranked
lists). Ties: equal values share the order of the final table (better-placed player first); a
nomination shows top 3 rows, plus any rows tied with the 3rd. Values formatted to 2 decimals
(counts as integers). Events with official nominations use them unchanged.

## Export

`lib/site_export/allstars_export.dart` → `site/data/allstars.json`, wired into `writeSiteData`
like the other pages. Display-ready, as everywhere else:

- `events`: newest first — year, name, date, host + label, source URL, podium (3 player cells),
  player and game counts, the final table as a `SiteTable` (rank, player, the event's columns;
  not re-sortable — its order is the result), and nominations (label, icon, rows of player cell +
  value, `official: true|false`).
- `champions`: a `SiteTable` of players with a podium — 1st/2nd/3rd counts, podiums, years won.

## Pages

- **`/allstars/`** — header «Річні турніри»; one card per year (newest first): year, event name,
  winner prominent, 2nd/3rd, date, host/judge, «14 гравців · 15 ігор», link to the year page.
  Below: the champions table.
- **`/allstars/<year>/`** — event header (name, date, host/judge, link «Результати на
  emotion.games» when `source` is set), nomination cards (reusing `AwardCards.astro`'s look; a
  small «пораховано з ігор» note on computed ones), then the full final table (`DataTable`).
- Header nav gets «All Stars» between Tournaments and Annual (nav labels are English).
- Player names via `PlayerName.astro`, so claimed nicknames/avatars apply.

## Out of scope

Fantasy leagues, Rookie of the Year 2019, per-game cards for these events, adding FAS 2022/2024/
2025 to Firestore `config/club` (would change `/tournaments/` and players' podium counts — a
separate decision), the app UI.

## Testing

- `test/services/stats/allstars_nominations_test.dart`: small hand-made games → expected values,
  role split, penalties, ties at 3rd place.
- `test/site_export/allstars_snapshot_test.dart` on the committed snapshot: each event's winner
  is the expected player (Рауль, Луна, Seezov, Braun, Tina); for 2019–2023, per-player computed
  MVP equals the final table's «Допы»/«ДБ» + ЛХ/КХ columns; every standings name resolves to a
  roster player (or is listed in the test as a known non-roster name).
- Site: `npm run build` + `check-dist.mjs` (no broken links, every linked player has a page);
  a Vitest for any new TS helper.
- Manual: open both pages locally in dark and light themes and at phone width.
