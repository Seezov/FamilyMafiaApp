# Federation player matching — design

## Intent

The club wants games its players played at federation tournaments (imafia.org, emotion.games,
fiim.world, mafgame.org) to appear in the club's statistics. Before any games can be parsed we need a
trustworthy link "roster player ↔ federation profile". Nicknames collide across clubs and cities, so
links are found automatically but **confirmed by a person** (the owner) on an admin page.

This project builds the matching + review step only. Parsing federation games is the next project
and reads the confirmed links this one produces.

## Goals

- Find candidate federation profiles for **every** roster player (all 643, every nickname in their
  `nicknames` list, not just recent players).
- An admin page where each roster player is a row, with candidates grouped by federation, each with a
  checkbox to confirm "this is him/her".
- Confirmed links and rejections persist; a re-run of the search does not bring rejected candidates back.

## Non-goals

- Importing / parsing federation games or showing federation stats anywhere public.
- Automatic confirmation: nothing becomes a link without a click (even strong candidates).
- Keeping candidates live: the search is re-run on demand, not on every build.

## Anti-goals

- A wrong link silently mixing a stranger's games into club stats. When unsure, show more info, never
  auto-pick.
- Hammering federation sites: the search is a manual script with polite pacing, never part of CI's
  every-build path.

## Data sources (recon 2026-10-27, all public, no login)

| Federation | Club-level source (strong) | Nick search (weak) | Profile URL | Shown info |
|---|---|---|---|---|
| emotion.games | `GET https://api-v1.emotion.games/club/clubs/13` → `members` (52, paginated `members_pagination`, 10/page — find the page param) | no public player search (`/player/players` is 401); fallback = `year_points/summary?year=Y` for 2024..now (has `club_id`, `nickname`, `player_id`) | `https://emotion.games/ua/player/<player_id>` (verify the path) | nick, avatar, tournaments, points |
| mafgame.org (Laravel + Inertia: JSON is in the HTML's `data-page` attribute) | `/clubs/9/members` (Family Mafia Club, 11 members; club 120 "Family mafia" is an empty duplicate) | `/rating` and `/country_rating` pages (`search_results`, filter params in `query_params`); `user/quick_search` needs auth | `https://mafgame.org/user/<id>/view` | nick, display name (first name), avatar, club start date |
| fiim.world | no member list on `/clubs/266`; search results carry club "Family Mafia Club (Черкассы, Украина)" | `GET /rating/search?year=all&name=<q>&masters=global` (JSON `{success: <html>}`) → nick, real name, start year, club, city, tournaments | `https://fiim.world/user/<id>/show` | nick, real name, club, city, year, tournaments |
| imafia.org | club not registered | `GET /rating?f[name]=<q>` (HTML; curl needs `-g`) → `/u/<id>` links | `https://imafia.org/u/<id>` — profile has «Прізвище Ім'я», country, «Клуб» | nick, real name, country, club, games |

A candidate is **strong** when the federation itself puts the person in our club (emotion members,
mafgame members, fiim club text "Family Mafia Club"/city Черкаси), otherwise **weak** (nick match).

## Parts

### 1. Search script — `site/scripts/find-federation-players.ts`

- Run by hand (`node site/scripts/find-federation-players.ts`, Node 24 strips types like
  `fetch-profiles.ts`). Reads the roster from Firestore `config/players` (REST, public read).
- Collects strong candidates from the club sources, then for each roster nickname queries imafia and
  fiim search (and matches against the emotion/mafgame lists already fetched). Match = case-insensitive
  equality after normalising (trim, lowercase, Latin/Cyrillic look-alike letters folded, e.g. `Luna` vs
  `Луна` is **not** folded — only homoglyphs like Latin `a`/Cyrillic `а`). Search results that merely
  contain the nick are kept only if equal after normalisation (builder's call to widen if it misses
  obvious ones).
- For imafia/fiim weak candidates, fetch profile details (real name, club, city/country, games) so the
  page can show them.
- Federation club members that match no roster nick are kept as **unmatched** entries.
- Output: committed `assets/raw/federation_candidates.json`:
  `{generatedAt, players: {<rosterName>: [Candidate]}, unmatched: [Candidate]}` where
  `Candidate = {fed: 'imafia'|'eg'|'fiim'|'mafgame', id, nick, realName?, club?, city?, games?, url, strength: 'club'|'nick'}`.
- Pacing: sequential requests with a small delay (~300 ms), retry once on failure, a failed federation
  is reported and its previous candidates kept (do not wipe on a partial run).
- Parsing helpers are pure functions with fixture tests (saved HTML/JSON samples), as in
  `fetch-profiles.test.ts`.

### 2. Storage — Firestore `config/federations`

```
{ links:    { <rosterName>: { imafia: [id], eg: [id], fiim: [id], mafgame: [id] } },
  rejected: { <rosterName>: ["<fed>:<id>", ...] },
  updatedAt, updatedBy, updatedByEmail }
```

- Public read, admin write; rule in `firestore.rules` modelled on `config/players` (keys `hasOnly`,
  `links`/`rejected` are maps, stamp fields checked). Rules tests in `firebase/rules-test/`.
- Several ids per federation are allowed (old + new accounts). One federation profile linked to two
  roster players is shown as a warning on the page, not blocked.
- Manual links (pasted profile URL) are stored the same way; the URL is parsed into `fed` + `id`.
- Publishing the rule happens before pushing code that reads it (deploy lesson from season creation).

### 3. Page — `/federations/edit/` (admins, Google sign-in)

- Same auth/shell as `/players/edit/` (hosts doc with `admin: true`); static page with candidates baked
  in from `federation_candidates.json` at build time, links/rejections loaded live from Firestore.
- Table: one row per roster player; columns imafia / emotion.games / fiim / mafgame; each column lists
  candidate cards: nick, real name, club · city, games/tournaments, «в нашому клубі» / «збіг ніку»
  badge, link to the profile (new tab), checkbox.
- Checked = confirmed link. Unchecking a confirmed one removes the link. A "reviewed" action per row
  marks all its remaining unchecked candidates as rejected (so they don't come back after a re-run).
  Rejected candidates are hidden by default, visible with a toggle.
- Filters: «Не переглянуті» (has unreviewed candidates — default), «Підтверджені», «Нічого не знайдено»,
  «Усі»; text search by name. Counters per filter.
- Block «Учасники клубу на федераціях без пари»: unmatched club members with a roster-player picker
  (autocomplete like `/players/edit/`) → creates a link.
- Per row: a field to paste a profile URL from any of the four sites → manual link.
- Saves are per click in a transaction (read-modify-write like `saveClub`). No need to bump `meta/state`
  — nothing public changes yet.
- Linked from the admin area (where `/players/edit/` is linked).

### 4. Roster changes

Links are keyed by roster display name. When `/players/edit/` renames or merges a player, the same
action moves that player's `links`/`rejected` entries (merge = union) in `config/federations`.
Deleting is not a roster op today; if it appears, drop the entry.

## Constraints

- Spark plan read budget: the page reads one document; fine.
- `check-dist.mjs` must keep passing (no keys in output, no broken links). The page is not linked from
  public navigation.
- Windows dev quirks from CLAUDE.md apply (stop `astro preview` before `npm ci`).
- Push both `feature/flutter_migration` and `master` (kept at the same commit).

## Decided by the owner

- Review UI = table, player nick + found profiles, a checkbox per candidate.
- Search every roster player, not just recent ones.
- Matching-only scope; game parsing is the next project.
- Candidate data may be public: the committed JSON (public repo) and the page baked from it can carry
  nicks, real names, city and club of candidates — all already public on the federation sites.

## My calls (owner may override)

- Search runs as a manual script with committed output, not in the browser or CI.
- Firestore `config/federations` keyed by roster name; rename/merge carries links.
- Unreviewed candidates are rejected only by an explicit "reviewed" click, not implicitly.
- Strong/weak badge instead of auto-confirming club members.
- Rename/merge updates `config/federations` inside the same `runTransaction` as `config/players`
  (`site/src/lib/roster/store.ts`).
- Baked candidates stored under an old name (before a re-run) are matched to the player through the
  roster's `nicknames` list, which keeps old names after a rename.
- Unchecking a confirmed link returns the candidate to unreviewed, not rejected.

## Left to the builder

- Exact emotion.games profile URL path and members pagination param; mafgame rating query params.
- Normalisation details and whether to also try transliterated nicks (Latin ↔ Cyrillic) as weak
  candidates — only if it doesn't flood the page.
- Card layout details within the site's existing admin-page style.
