# Annual rating — design

Date: 2026-10-05
Status: approved in chat, awaiting written-spec review

## Goal

Move the club's annual rating («Річний рейтинг клубу за <рік>») off the Google Sheets. The
site shows it per year; admins enter external tournaments, series and marathons on a site page
instead of the sheet's «Турніри» tab. Club seasons feed the rating automatically.

## How the sheet works today (verified 2026-10-05)

Each season sheet (S21+) has a «Турніри» tab of blocks and a «Річний рейтинг» tab. A block:

```
<kind> | <name> | Дата | <date>
К-сть зірок | <stars> | К-сть учасників | <participants>
Гравець | Місце | Формула | Бали
<player> | <place> | … | <points>        (one row per player)
```

`kind` is one of `Турнір`, `Серія`, `Марафон`, `Сезон`. Points per row:

| Kind | Points by place |
|---|---|
| Сезон | 1→18, 2→15, 3→12, 4→9, 5→6, 6–10→4, 11+ (main league)→2; small league top 5 entered as places 101–105 → 5, 4, 3, 2, 1 |
| Серія | 1→10, 2→8, 3→6, 4→4, 5→3, 6→2, 7→2, 8+→1 |
| Марафон | 1→6, 2→4, 3→3, 4→2, 5→2, 6+→1 |
| Турнір | `b = 1 + stars/3`; place < 1 → 0; place ≤ 10 → `b + (N − place)·b/4`; place < N/2 → `b + (N − place)·b/5`; else `b + (N − place)·b/10` (N = participants) |

Places 101–105 are checked before the «11+ → 2» rule. Points are kept unrounded per event.

A player's annual score = sum of their 12 best event points (all of them if fewer than 12),
rounded to 2 decimals. Shown with it: wins (place 1), top-3 (place < 4), top-10 (place < 11),
participations (place > 0). Ranking is by score, descending.

Recomputing every row from the blocks of the 2024 (S23 sheet), 2025 (S27) and 2026 (S31)
tabs reproduces the sheet's points and annual totals exactly (242, 269 and 217 rows).

Seasons in a year: winter (Dec–Feb, counts in the year it ends), spring, summer, autumn. 2024
has all four; 2025 has no autumn block (S27) — imported as is. The 2026 season blocks equal
the site's computed league tables for S28–S30 (only nickname spellings differ).

## Decisions

| Topic | Decision |
|---|---|
| Scope | Site only; the Flutter app is unchanged. |
| Years | 2024, 2025, 2026 and later. 2023 is not migrated (no «Турніри» tab). |
| Storage | Firestore collection `events`, one document per event. |
| Who edits | Admins only (`hosts/{email}.admin == true`), Google sign-in, as on `/debug/`. |
| History | 2024 and 2025 imported verbatim from the sheets, season blocks included. 2026 imports only its non-season blocks. |
| Club seasons from 2026 | Not stored. The export derives a «Сезон» event for each finished club season with id ≥ 28: main league ranks 1…N, small league top 5 as places 101–105. Its year = the year of the season's last month (S28 Dec 2025–Feb 2026 → 2026; S32 → 2027). A season in progress (`thresholdLive`, i.e. `seasonInProgress`) gives no event yet. |
| Names | Event rows store the name as entered. The export resolves it with the app's `PlayerResolver` (aliases like Скай → Rathma, Luna → Луна, RedFox → Red Fox); unresolved names are kept as written and shown without a profile link. |
| Publishing | Every save also sets `meta/state.updatedAt`; `games-watch.yml` rebuilds the site within the hour. |
| Points in TS | The edit page previews points with a TS port of the formulas. A shared JSON fixture of cases runs in both the Dart and the TS tests so the two cannot drift. |

## Data

`events/{id}` (auto id):

```
{
  year: int,                       // 2024…
  kind: 'tournament' | 'series' | 'marathon' | 'season',
  name: string,                    // non-empty
  date: string | null,             // 'YYYY-MM-DD'
  stars: int | null,               // 0–5, tournament only
  participants: int | null,        // ≥ 1, tournament only
  results: [{ player: string, place: int }],   // place ≥ 1; 101–105 only for season
  updatedAt: timestamp, updatedBy: uid, updatedByEmail: string
}
```

`kind: 'season'` documents exist only for 2024–2025 (imported). The edit page offers the
other three kinds; it shows imported season events read-only.

## Rules (`firestore.rules`)

```
match /events/{id} {
  allow read: if true;
  allow create, update: if isAdmin() && <field checks above, hasOnly on keys,
                           updatedAt == request.time, updatedBy == uid, updatedByEmail == email()>;
  allow delete: if isAdmin();
}
```

Type checks: `year is int`, `kind in [...]`, `name is string && size() > 0`, `results is list`
(`size() <= 300`), `stars`/`participants` `int` or `null`, `date` `string` or `null`. Row
contents are validated by the build (rules cannot loop over a list). Tests in
`firebase/rules-test`.

## Build

- `tool/prefetch_seasons.dart` lists `events` over REST (paged), validates each document with
  a pure-Dart checker (kind, year, results shape, tournament has stars + participants), and
  writes `assets/prefetched/annual_events.json`. A malformed document fails the build with its
  id. An empty collection is valid (writes `[]`).
- The export tool reads the snapshot and passes it to `writeSiteData`, which adds derived season events,
  computes points and the per-year table, and writes `site/data/annual.json`:
  `{ years: [ { year, table: SiteTable, players: {<key>: [{eventId, points, counted}]},
  events: [{id, kind, name, date, stars, participants, results: [{player, link?, place, points}]}] } ] }`.
- Pure Dart: `lib/services/stats/annual_rating.dart` — `eventPoints(kind, place, stars,
  participants)` and `annualTable(events)`; no Flutter imports (prefetch guard).

## Pages

**`/annual/`** — the newest year; `/annual/<year>/` for the others; a year switcher on top.
- Table: place, player (link + nick via `PlayerName`), score, wins, top-3, top-10,
  participations. Tapping a row expands that player's events with points; the 12 counted ones
  are marked.
- Below: the year's events (newest first) with kind, name, date and the podium; each opens to
  the full results with points.
- Header nav gets an «Annual» link. Site copy stays English like the rest of the site.

**`/annual/edit/`** — admin page, signed out → read-only with a sign-in button.
- Year selector; list of that year's stored events; «Add event», «Edit», «Delete» (confirm in
  page, no browser dialog).
- Form: kind (tournament / series / marathon), name, date, stars + participants (tournament
  only), result rows «player + place» with add/remove; player input suggests club nicknames
  (from `players.json`), a name that is not a club player is highlighted but allowed; points
  per row update live.
- Validation before save: name set, at least one row, places are positive integers, no
  duplicate player, tournament needs stars 0–5 and participants ≥ the largest place.
- Save/delete in a transaction that also bumps `meta/state`.
- «Import 2024–2026»: shown only while the collection is empty; reads
  `tool/import/annual_events.json` from the repo's raw GitHub URL and writes all documents in
  batches.

## One-time import

A script run once by me reads the three «Турніри» tabs (S23 → 2024, S27 → 2025, S31 → 2026),
keeps non-empty blocks, drops 2026 season blocks, and writes `tool/import/annual_events.json`
(committed). Blocks without a date keep `date: null`. The sheet's per-player annual totals
(from the three «Річний рейтинг» tabs) go to `test/fixtures/annual_totals.json`.

## Tests

- Formula fixture `test/fixtures/annual_points_cases.json` (rows sampled from all four kinds,
  with the sheet's points) — Dart test and TS test both check every case.
- Dart: the import file with the sheet names (no alias resolution) gives exactly the sheet's
  totals for 2024 and 2025, and for 2026 together with derived S28–S30 season events (names
  compared through the resolver).
- Dart: derived season events — finished seasons only, year from the last month, small league
  101–105.
- Prefetch: valid, empty and malformed collections.
- Rules: admin create/update/delete; non-admin and signed-out denied; bad kind/fields denied.
- Site: `check-dist` link check covers the new pages.

## Out of scope

- The app (Flutter) screens.
- 2023 and earlier years.
- Editing the imported 2024–2025 season events on the page (Firestore console if ever needed).
- Adding autumn 2025 (S27) to 2025.
