# Federation games in player stats — design

## Intent

Club players also play federation tournaments (imafia.org, emotion.games, fiim.world, mafgame.org). The owner wants
those games to count on the club site's `/players/` page, behind a filter, so the table can show either club season
games only or season + tournament games. Some series/tournaments were also entered into the club rating (their games
sit in the season sheets / Firestore games); those games must not be counted twice.

Builds on the federation matching project (`2026-10-27-federation-players-design.md`): only profiles the owner
confirmed on `/federations/edit/` (Firestore `config/federations.links`) contribute games.

## Goals

- `/players/` gets a toggle «Season games» / «+ Tournaments» (page copy is English like the rest of that page). With
  tournaments on, both the **Games** and **WR** columns include federation tournament games. The toggle state lives in
  the URL like the existing `?q=` / `?games=` filters; the min-games pills apply to whichever count is shown; sorting
  works on the shown values.
- Every federation game of a confirmed profile is collected: seat, nick, role, game result (which side won), date,
  tournament, table/round.
- No double counting:
  1. **Club duplicate (owner's rule):** a federation game is the same game as a club rating game when the nicks, the
     seats and the roles match. Search window: club games dated within the tournament's dates ±1 day. Nick matching
     goes through the roster (name + nicknames, normalised like `normNick`) and through confirmed links where the
     federation gives player ids.
  2. **Cross-federation duplicate:** the same game published on two federations counts once. Detected with the same
     seat matcher as club duplicates (a full match between two federation games), across all four federations;
     emotion.games' `is_imafia` / `im_id` marker is a shortcut, not the only check. The richer source (with player ids)
     is kept.
- Partial matches (e.g. 9 of 10 seats line up) are not silently counted or dropped: they are listed for the owner to
  decide (see Review).
- Data refreshes once a day with the nightly build.

## Non-goals

- Player profile pages, records, season tables, annual rating: unchanged. Only `/players/` Games + WR.
- Federation points/ratings/nominations: not imported, only games and wins.
- Showing individual federation games on public pages other than the review list on `/federations/edit/`.

## Anti-goals

- A tournament game counted twice (club + federation, or two federations).
- A stranger's games: only confirmed links count; other seats are used only for duplicate detection.
- The nightly deploy failing because a federation site is down or changed.

## Data available (recon 2026-10-28, all public)

| Federation | Player's tournaments | Games of a tournament |
|---|---|---|
| emotion.games | `api-v1.emotion.games/year_points/player/<profile_id>?year=Y` → `tournaments[{id, start_date, name, participants…}]` per year | `/tournament/tournaments/seating_games_tab/<id>` → `qualifiers.lines[].tables[]` and `finals` with `game_result` (red/black), `game_board.rows[{place, nickname, profile_id, role, killed_first…}]`; `/tournament/tournaments/json_info/<id>` → dates, `is_imafia`, `im_id`, `online`, `time_duration` |
| imafia.org | profile `/u/<id>` lists `/tournament/<id>` links with dates | `/tournament/<id>` HTML, `#tournament-tables`: `games_item_*` blocks with seat, player link `/u/<id>`, role class (`role_1..4`), result class (`result_1/2`) |
| fiim.world | profile `/user/<id>/show` links `/user/<id>/games/<tid>` | that page: per game «Стол N, Игра N [Победа мафии/города]», seats 1–10 with nick text and role icon (`icon-red/black/sheriff/don`), first-killed marker; other players are nick text only |
| mafgame.org | `/user/<id>/view` → `history[{id, start_date, games, wins}]` | `/tournaments/<id>/game_results` (Inertia `data-page`) → `games.results["part-session-table"]` (red/black) and `games.seats[...]` `{place, player_id, original_nickname, role, killed_first}` |

Exact parsing (role class meanings on imafia, final vs qualifier keys, team tournaments) is the builder's to verify
against live pages.

## How it works (owner decided: nightly; rest is my call)

1. **Fetch (nightly CI step, before the site export):** a Node script reads `config/federations` + `config/players`
   over public REST, lists each confirmed profile's tournaments, fetches every tournament's games once (a tournament
   shared by several club players is fetched once), and normalises them into one structure:
   `{fed, tournamentId, name, dateFrom, dateTo, online, alsoOn?: {fed, id}, games: [{key, round, table, result:
   'city'|'mafia', seats: [{seat, nick, fedPlayerId?, role: 'citizen'|'sheriff'|'mafia'|'don'}]}]}`.
   - Cache: finished tournaments are stored in a GitHub Actions cache and never refetched; only unknown/unfinished
     tournaments are fetched. A federation that fails uses the cache and logs a warning; the build does not fail.
   - Only the nightly run fetches; hourly (`games-watch.yml`) and push builds restore the last cache. The nightly
     `schedule` runs on `master`, whose caches every branch can read, so the nightly writes the cache there.
   - The fetch has a time budget so the job stays inside its timeout; the first (cold) runs fill the cache over
     several nights and tournament counts grow meanwhile.
   - Output to gitignored `site/data/` (like profiles), read by the export.
2. **Match & dedupe (pure, tested):** for each confirmed player, each federation game where he sits is attributed to
   him (win = his side won). Drop it if (a) it fully matches a game already taken from another federation, or (b) it
   fully matches a club rating game: all 10 seats have the same roster player and the same role. A full match needs
   **no date check** (it can't happen by chance; this also covers ~1,000 undated club games and sheet dates that differ
   from the federation's). A game where at least 7 seats match on both player and role, but not all 10, against a
   game dated within the tournament's dates ±3 days, is a **possible duplicate**: excluded from counts until reviewed.
   Undated club games take part in full matching only.
3. **Review of possible duplicates:** the list is baked into the static page, so it is public (owner approved
   2026-10-28 — the games are public on the federation sites). A section on `/federations/edit/` lists them (federation game vs club game, seat
   by seat); admin chooses «same game» or «different game», stored in Firestore `config/federations` (new map
   `gameDecisions: {"<fed>:<tournament>:<gameKey>": 'same'|'different'}` — rule update needed). Decisions apply on the
   next build.
4. **Export:** players.json gets, per player, season `games`/`wins` (as today) plus `tournamentGames`/`tournamentWins`;
   the table carries both values (e.g. `data-` attributes) so the client toggle can swap Games/WR without a second
   page. A small build log line reports counts: fetched tournaments, games, dropped as club duplicates, cross-fed
   duplicates, possible duplicates.

## Constraints

- Static site, no secrets in the output; Firestore read over public REST (config docs are public read).
- Nightly build stays within its 30-minute timeout; polite pacing per site (sequential, small delay).
- The existing players-page JS finds the Games column by its header text `Games` — keep that working.
- Club rating games for dedupe: all rating games of all seasons, with dates and seats (season JSON / Firestore games);
  non-rating games are not counted on `/players/`, so they need no dedupe.
- Push both `feature/flutter_migration` and `master`; publish the rule change before pushing code that writes it.

## Decided by the owner

- Toggle on `/players/` between season-only and season + tournament games; affects Games and WR.
- Duplicate = same nicks, seats and roles.
- Refresh once a day with the nightly build.
- The possible-duplicates review list may be public (baked into `/federations/edit/`).

## My calls (owner may override)

- Per-game dedupe (not whole-tournament); full 10-seat matches need no date; partial-match window ±3 days.
- Cross-federation duplicates found by the same seat matcher across all four federations.
- Partial matches (≥7 of 10 seats on player + role) held out of counts until reviewed on `/federations/edit/`.
- Hourly/push builds reuse the nightly cache; cold start fills over several nights under a time budget.
- Online tournaments and series count like any other tournament games.
- Fetch in CI with a per-tournament cache, nothing committed.

## Left to the builder

- Whether matching/dedupe runs in Dart (`lib/site_export/`, next to the club games) or in the Node fetch script.
- Exact parsers per site, finals/team-tournament handling, role mapping, and the cache layout.
- The visual form of the toggle (pills like the games filter are fine).
