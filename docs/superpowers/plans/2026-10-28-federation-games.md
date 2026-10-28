# Federation games in player stats — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `/players/` can show Games and WR with federation tournament games added (toggle), without counting a game twice.

**Architecture:** Everything lives in `site/` (TypeScript), next to the federation matching code; the Dart export is untouched.
A nightly-only CI step (`scripts/fetch-federation-games.ts`) downloads the games of every confirmed profile's
tournaments into a cache directory kept in the GitHub Actions cache. Every build then runs
`scripts/federation-games.ts`, which reads that cache, the club games (`data/games/*.json`), `data/players.json` and live
`config/federations` (links + decisions), and writes `data/federation_games.json` (per-player tournament games/wins +
the possible-duplicate review list). `/players/` and `/federations/edit/` read that file at build time.

**Tech Stack:** Node 24 (runs `.ts` directly), Astro, vitest, Firebase JS SDK, Firestore rules + `@firebase/rules-unit-testing`, GitHub Actions (`actions/cache`).

**Spec:** `docs/superpowers/specs/2026-10-28-federation-games-design.md`

## Global Constraints

- Only profiles in `config/federations.links` contribute games; other seats are used only for duplicate detection.
- Full match (all 10 seats: same player + same role) = duplicate, **no date check**.
- Partial match: ≥ 7 of 10 seats on player + role, club game dated within tournament `dateFrom − 3 days … dateTo + 3 days` → possible duplicate, **excluded from counts until reviewed**. Undated club games take part in full matching only.
- Decisions: `config/federations.gameDecisions["<fed>:<tournamentId>:<gameKey>"] = 'same' | 'different'`.
- Only club **rating** games are compared (`result` `city`/`mafia`; `unrated` skipped).
- Online tournaments and series count like any other.
- `/players/` copy is English: toggle labels «Season games» / «+ Tournaments»; URL param `t=1` when tournaments are on.
- The players-page JS keeps finding the Games column by header text `Games`.
- A federation that fails never fails the build (warn + use cache / empty output).
- Only the nightly `schedule` run (and a manual dispatch with the input set) fetches; it saves the cache on `master`. All other builds only restore it.
- Polite fetching: sequential, 300 ms delay, `User-Agent: Mozilla/5.0 (FamilyMafiaClub federation matcher)`; fetch budget default 12 min (env `FED_BUDGET_MIN`) inside the 30-min job.
- Publish the rule change in the console **before** pushing code that writes `gameDecisions`; ask the owner before clicking Publish. Push both `feature/flutter_migration` and `master`.

## Review Focus

1. **Saving a link (or a roster rename/merge) wipes `gameDecisions`** — both `saveFedOp` and `saveRosterOp` `tx.set` the whole doc from `toFedDoc`; it must carry `gameDecisions` through. → Task 1 tests.
2. **A stranger's nick equals a club nick** (e.g. a "Braun" from another city): attribution must come only from `fedPlayerId ∈ links`, never from nick. → Task 4 test `does not attribute by nick`.
3. **Ambiguous nicks** (two roster players share a normalised alias): resolver returns no player for that seat instead of picking one. → Task 4 test.
4. **Same game in two tournaments' copies / same fiim game on two club players' pages** must be one game. → Task 4 test `merges parts by game key`.
5. **Toggle while a column is sorted or the min-games pill is active**: rows must re-sort by the new values and the pill filter must use shown games. → Task 6 manual check + `resort` unit.

---

## File Structure

| File | Responsibility |
|---|---|
| `site/src/lib/federations/core.ts` (modify) | `FedDoc.gameDecisions`, `FedOp` `decide`, move `nickVariants` here |
| `site/src/lib/federations/store.ts` (modify) | `toFedDoc` reads `gameDecisions`; `decide` save bumps `meta/state` |
| `firestore.rules`, `firebase/rules-test/rules.test.ts` (modify) | allow `gameDecisions` map |
| `site/src/lib/federations/games.ts` (create) | types `FedTournament`, `FedGame`, `FedSeat`, `FedGamesFile`; pure matching/dedupe/stats |
| `site/scripts/federations/games-parse.ts` (create) | per-site parsers: tournament lists + games pages → `FedTournament` |
| `site/scripts/federations/http.ts` (create) | `politeGet` extracted from `find-federation-players.ts` |
| `site/scripts/fetch-federation-games.ts` (create) | nightly fetch into the cache dir |
| `site/scripts/federation-games.ts` (create) | build step: cache + club games + config → `data/federation_games.json` |
| `site/src/lib/data.ts` (modify) | `loadFederationGames()` |
| `site/src/pages/players/index.astro`, `site/src/components/table.ts` (modify) | toggle, `resort` |
| `site/src/pages/federations/edit.astro`, `site/src/scripts/federations-edit.ts`, `site/src/lib/federations/render.ts` (modify) | review section |
| `.github/workflows/web.yml`, `site/package.json`, `.gitignore`, `CLAUDE.md` (modify) | CI cache + steps, build chain, docs |

---

### Task 1: `gameDecisions` in the document, ops and rules

**Files:**
- Modify: `site/src/lib/federations/core.ts`, `site/src/lib/federations/core.test.ts`, `site/src/lib/federations/store.ts`, `site/src/scripts/federations-edit.ts` (initial `feds` value), `firestore.rules:195-205`, `firebase/rules-test/rules.test.ts:370-399`

**Interfaces:**
- Produces: `FedDoc = { links; rejected; gameDecisions: Record<string, 'same' | 'different'> }`; `FedOp` gains `{ kind: 'decide'; key: string; value: 'same' | 'different' | null }` (null removes); `gameKey(fed: Fed, tournamentId: string, key: string): string` → `` `${fed}:${tournamentId}:${key}` ``; `nickVariants` exported from `core.ts` (re-exported by `scripts/federations/parse.ts`); `toFedDoc` returns `gameDecisions` (`{}` when absent).

- [ ] **Step 1: Failing tests in `core.test.ts`**
  - `applyFedOp(d, {kind:'decide', key:'eg:716:q-1-2', value:'same'}).gameDecisions` equals `{'eg:716:q-1-2':'same'}`; `value:null` removes it; `d` is not mutated.
  - `applyFedOp` with `link` keeps an existing `gameDecisions` unchanged.
  - `moveForRosterOp` (rename and merge) keeps `gameDecisions` unchanged.
  - `decide` does not create an empty `rejected[undefined]` entry (`Object.keys(next.rejected)` unchanged).
- [ ] **Step 2:** `cd site && npx vitest run src/lib/federations/core.test.ts` → FAIL.
- [ ] **Step 3: Implement** — `copy()` copies `gameDecisions`; in `applyFedOp` handle `decide` before touching `rejected[op.player]`. Move `nickVariants` into `core.ts`; `parse.ts` does `export { nickVariants } from '../../src/lib/federations/core.ts'`.
- [ ] **Step 4:** `toFedDoc` reads `gameDecisions`; `saveFedOp` for `decide` also does `tx.set(doc(db,'meta','state'), { updatedAt: serverTimestamp() })` (the hourly build then applies it). Edit page's initial `feds` gets `gameDecisions: {}`.
- [ ] **Step 5: Rules tests** in `describe('config/federations')`: admin can write a body with `gameDecisions: {'eg:716:q-1-2': 'same'}`; a body without `gameDecisions` still succeeds; `gameDecisions: 'x'` fails.
- [ ] **Step 6: Rule** — `hasOnly([... , 'gameDecisions'])` and `&& (!('gameDecisions' in request.resource.data) || request.resource.data.gameDecisions is map)`.
- [ ] **Step 7:** `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test` → all pass; `cd site && npx vitest run && npm run check` → pass.
- [ ] **Step 8: Commit** `feat(federations): gameDecisions in config/federations`.

---

### Task 2: Shared types + JSON-API parsers (emotion.games, mafgame.org)

**Files:**
- Create: `site/src/lib/federations/games.ts` (types only in this task), `site/scripts/federations/games-parse.ts`, `site/scripts/federations/games-parse.test.ts`, fixtures under `site/scripts/federations/fixtures/games/`

**Interfaces:**
- Produces (in `games.ts`):
  ```ts
  export type FedRole = 'citizen' | 'sheriff' | 'mafia' | 'don';
  export interface FedSeat { seat: number; nick: string; fedPlayerId?: string; role: FedRole }
  export interface FedGame { key: string; round?: string; table?: number; result: 'city' | 'mafia'; seats: FedSeat[] }
  export interface FedTournament { fed: Fed; tournamentId: string; name: string; dateFrom: string; dateTo: string; online?: boolean; alsoOn?: { fed: Fed; id: string }; games: FedGame[] }
  export interface TournamentRef { fed: Fed; tournamentId: string; date?: string }
  ```
  Dates are `YYYY-MM-DD`. `key` is stable per tournament (e.g. `q-<line>-<table>` / `f-<n>` on eg; `<part>-<table>-<n>` on mafgame). A game without 10 seats or without a result is skipped by the parser.
- Produces (in `games-parse.ts`): `parseEgPlayerYear(j): TournamentRef[]`, `parseEgInfo(j): Omit<FedTournament,'games'>` (uses `is_imafia`/`im_id` → `alsoOn: {fed:'imafia', id}`), `parseEgGames(j): FedGame[]` (qualifiers + finals), `parseMafgameHistory(html): TournamentRef[]`, `parseMafgameTournament(html): FedTournament` (Inertia `data-page`, reuse `inertiaProps` from `parse.ts`).

- [ ] **Step 1: Save fixtures** with curl (UTF-8 via file, not stdin): eg `year_points/player/<a linked id>?year=2025`, `json_info/716`, `seating_games_tab/716`; mafgame `/user/<a linked id>/view` and `/tournaments/<id>/game_results` for one tournament in that history. Read each fixture and note role/result value spellings.
- [ ] **Step 2: Failing tests:** eg 716 → `parseEgGames` length 75, every game 10 seats with seats 1..10, roles only from `FedRole`, `fedPlayerId` = `profile_id`; `parseEgInfo` dates as in `json_info`; `parseEgPlayerYear` returns the fixture's tournament ids. mafgame → game count and first game's seats/roles/result equal to what the page shows (write the literal values read in Step 1); `fedPlayerId` = `player_id`.
- [ ] **Step 3:** `cd site && npx vitest run scripts/federations/games-parse.test.ts` → FAIL.
- [ ] **Step 4:** Implement the parsers. Role mapping table per site in one `const` each; an unknown role/result string makes the game skipped (not thrown).
- [ ] **Step 5:** tests PASS.
- [ ] **Step 6: Commit** `feat(federations): emotion.games and mafgame game parsers`.

---

### Task 3: HTML parsers (imafia.org, fiim.world)

**Files:** Modify `site/scripts/federations/games-parse.ts` + test; fixtures.

**Interfaces:**
- Produces: `parseImafiaProfileTournaments(html): TournamentRef[]`, `parseImafiaTournament(html, id): FedTournament` (`#tournament-tables`, `games_item_*`, seat link `/u/<id>` → `fedPlayerId`, `role_1..4`, `result_1/2`); `parseFiimProfileTournaments(html, userId): TournamentRef[]` (links `/user/<id>/games/<tid>`), `parseFiimUserGames(html, tid, userId): FedTournament` — one user's games of one tournament; the owner's seat gets `fedPlayerId: userId` (owner found by the page's highlight, or by the nick in the page header), others nick only; game `key` = `t<table>-g<game>` so two users' pages of the same tournament merge.

- [ ] **Step 1: Save fixtures:** imafia `/u/<linked id>` and one `/tournament/<id>` from it; fiim `/user/<linked id>/show` and one `/user/<id>/games/<tid>` (UMC 2023 Західна конференція if a linked player has it). Determine on the page which `role_N` is which role and which `result_N` is city; write that mapping as a comment next to the const.
- [ ] **Step 2: Failing tests:** counts and the first game's seats/roles/result as literal values read from the fixtures; imafia every seat with a `/u/` link has `fedPlayerId`; fiim exactly one seat per game has `fedPlayerId === userId`; tournament dates parsed to `YYYY-MM-DD`.
- [ ] **Step 3:** FAIL → **Step 4:** implement (reuse `decode`/`text` from `parse.ts`, export them) → **Step 5:** PASS.
- [ ] **Step 6: Commit** `feat(federations): imafia and fiim game parsers`.

---

### Task 4: Matching, dedupe and stats (pure)

**Files:** Modify `site/src/lib/federations/games.ts`; Create `site/src/lib/federations/games.test.ts`

**Interfaces:**
- Consumes: Task 1 `FedDoc`, `gameKey`, `normNick`, `nickVariants`; Task 2 types.
- Produces:
  ```ts
  export interface ClubPlayer { name: string; slug: string; aliases: string[] }      // data/players.json
  export interface ClubGame { id: string; season: number; date: string | null; result: 'city' | 'mafia'; seats: { n: number; slug?: string; player: string; role: string }[] }
  export interface ReviewItem { key: string; fed: Fed; tournament: string; tournamentId: string; date: string; round?: string; table?: number;
    matched: number; fedSeats: { seat: number; nick: string; role: FedRole; slug?: string }[];
    club: { season: number; id: string; date: string; seats: { seat: number; player: string; role: string }[] } }
  export interface FedGamesFile { generatedAt: string; players: Record<string, { games: number; wins: number }>; review: ReviewItem[];
    counts: { tournaments: number; games: number; clubDuplicates: number; crossFedDuplicates: number; possible: number; counted: number } }
  export function mergeParts(parts: FedTournament[]): FedTournament[]          // same fed+tournamentId → one, games unioned by key
  export function computeFedGames(i: { tournaments: FedTournament[]; club: ClubGame[]; players: ClubPlayer[]; doc: FedDoc; now: string }): FedGamesFile
  ```
- Rules the tests pin:
  - Seat identity for matching: roster slug if resolvable (`fedPlayerId` via `links` reverse map → player name → slug; else a `nickVariants(nick)` hit on exactly one player's normalised aliases), otherwise `'nick:' + normNick(nick)`. Club seat identity = `slug`. Roles compared after mapping club `civilian` ↔ `citizen`.
  - Attribution: a federation game counts for a player only through a seat whose `fedPlayerId` is in that player's `links[fed]`. Win = (citizen|sheriff and city) or (mafia|don and mafia).
  - Order: cross-federation dedupe first (an `alsoOn` copy is dropped when the target tournament is present; otherwise two games from different feds that fully match → keep the one with more `fedPlayerId` seats), then club full match (drop), then partial (≥7, window) → `review` unless `gameDecisions[key]` is `'different'` (count) or `'same'` (drop).

- [ ] **Step 1: Failing tests** (small hand-built fixtures, 10 seats each):
  - `counts a linked player's game and win` → `players['braun']` `{games:1, wins:1}`.
  - `drops a full club match even without a date` (club game `date: null`) → `counts.clubDuplicates === 1`, no player count.
  - `does not drop when one seat differs in role` but 9 match and club date inside window → in `review` with `matched: 9`, not counted.
  - `partial match outside ±3 days is counted` (club date = dateTo + 4).
  - `partial match with 6 seats is counted`.
  - `decision 'different' counts, 'same' drops, no review item`.
  - `cross-federation full match counted once`; `alsoOn copy dropped`.
  - `does not attribute by nick` — seat nick `Braun` without `fedPlayerId` → no count for `braun`.
  - `ambiguous alias resolves to nobody` — two players with alias `тян` → seat identity is `nick:тян`.
  - `merges parts by game key` — two fiim parts of one tournament with the same game key → one game, both owners' `fedPlayerId` kept.
  - `unrated club games are ignored` (caller filters; test via `ClubGame` built only from rating games — assert loader in Task 5).
- [ ] **Step 2:** `npx vitest run src/lib/federations/games.test.ts` → FAIL.
- [ ] **Step 3:** Implement. Full match lookup by a `Map` keyed on the joined 10 `identity:role` strings; partial match only against club games bucketed by date inside the window.
- [ ] **Step 4:** PASS. **Step 5: Commit** `feat(federations): federation game dedupe and stats`.

---

### Task 5: Fetch script, build script, CI

**Files:**
- Create: `site/scripts/federations/http.ts`, `site/scripts/fetch-federation-games.ts` (+ `.test.ts`), `site/scripts/federation-games.ts` (+ `.test.ts`)
- Modify: `site/scripts/find-federation-players.ts` (use `politeGet`), `site/src/lib/data.ts`, `site/package.json`, `.github/workflows/web.yml`, `.gitignore`

**Interfaces:**
- `politeGet(fetch, url, { delayMs, retries = 2 }): Promise<string>` — the retry loop now in `findCandidates`.
- `fedDocFromRest(doc): FedDoc` — decodes Firestore REST `mapValue`/`arrayValue`/`stringValue` for `links`, `rejected`, `gameDecisions`.
- `fetchFederationGames(o: { fetch; cacheDir: string; budgetMs: number; now: Date; log; delayMs? }): Promise<{ fetched: number; skipped: number; left: number }>`
  - Reads `config/federations` over REST; for each linked profile lists its tournaments (eg: years 2019…now), then for each tournament: skip if `<cacheDir>/t/<fed>-<tid>.json` (fiim: `fiim-<tid>-u<uid>.json`) exists and its `dateTo` is before `now − 2 days`; else fetch, parse, write. Stops starting new fetches once `budgetMs` elapsed (`left` = not done). Any per-request/parse error: log `WARNING` and continue.
- `buildFederationGames(o: { fetch; cacheDir; dataDir; log; now }): Promise<void>` — writes `data/federation_games.json` (`FedGamesFile`); club games from every `data/games/*.json` day/game with `result !== 'unrated'`; config fetch failure → empty file + warning; logs `federation-games: <counts>`.
- `loadFederationGames(): FedGamesFile` in `data.ts` — empty fallback when the file is missing.
- Cache dir: env `FED_CACHE_DIR`, default `site/.fedgames` (gitignored).

- [ ] **Step 1: Failing tests** with a fake `fetch` (map URL → fixture text from Tasks 2–3): fetch writes the tournament files; a second run with `now` after `dateTo + 2` makes 0 tournament requests; a tournament whose `dateTo` is recent is fetched again; a 500 on one federation logs `WARNING` and the others are written; `budgetMs: 0` fetches nothing and reports `left > 0`. Build script: with cache + `data/` fixtures in a temp dir writes a file whose `players` matches Task 4; config 500 → `{players:{}, review:[]}` and the build continues.
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS (`npx vitest run`).
- [ ] **Step 5:** `package.json` build: `node scripts/fetch-profiles.ts && node scripts/federation-games.ts && astro build && node scripts/check-dist.mjs`. `.gitignore`: `site/.fedgames/`.
- [ ] **Step 6: web.yml** — `workflow_dispatch.inputs.federations` (boolean, default false). After `setup-node`, before "Build site":
  ```yaml
  - name: Restore federation games cache
    uses: actions/cache/restore@v4
    with: { path: site/.fedgames, key: fedgames-${{ github.run_id }}, restore-keys: fedgames- }
  - name: Fetch federation games (nightly)
    if: github.event_name == 'schedule' || inputs.federations
    working-directory: site
    run: node scripts/fetch-federation-games.ts
  - if: github.event_name == 'schedule' || inputs.federations
    uses: actions/cache/save@v4
    with: { path: site/.fedgames, key: fedgames-${{ github.run_id }} }
  ```
- [ ] **Step 7: Live smoke run:** `cd site && FED_BUDGET_MIN=3 node scripts/fetch-federation-games.ts` then `node scripts/federation-games.ts` → files appear in `.fedgames/t/` for all four feds (or a WARNING naming the failing one); log line shows non-zero `games`. Fix parsers against anything the live pages show differently (add the page as a fixture + test).
- [ ] **Step 8: Commit** `feat(federations): nightly federation games fetch and build step`.

---

### Task 6: `/players/` toggle

**Files:** Modify `site/src/pages/players/index.astro`, `site/src/components/table.ts`

**Interfaces:**
- Consumes: `loadFederationGames().players` (keyed by slug), `players[].winRate`, `players[].games`.
- Produces: `export function resort(root: HTMLElement)` in `table.ts` — re-applies the current `aria-sort` column and direction (no-op if none).

- [ ] **Step 1:** Embed `<script type="application/json" id="fedstats">` = `{ [slug]: { games, wins, tGames, tWins } }` where `wins = Math.round(winRate * games)`, `tGames = games + fed.games`, `tWins = wins + fed.wins`.
- [ ] **Step 2:** Second pill group `#scope` with «Season games» (default) / «+ Tournaments» (`?t=1`), styled like `#games`; hidden when `fedstats` has no federation games at all.
- [ ] **Step 3:** On toggle, per row (slug from the player link's `href` last path segment): set the Games cell `textContent` + `data-s`; the WR cell's text (`Math.round(wr*100)+'%'`, same as `pct0`), `data-s`, `.bar` `--w`, and `tone-*` class via `wrTone`; WR column found by header text `WR`. Then `resort(root)` and the existing `apply()` (which reads `data-s`, so the min-games pills use shown games); URL keeps `q`, `games`, `t`.
- [ ] **Step 4:** `npm run check && npm run build`, then `npm run preview`: toggle on/off, sorted by Games desc then toggled → order follows new values; `?games=100&t=1` loads with both applied; a player without federation games shows identical values in both modes.
- [ ] **Step 5: Commit** `feat(players): season / + tournaments toggle`.

---

### Task 7: Review list on `/federations/edit/`

**Files:** Modify `site/src/pages/federations/edit.astro`, `site/src/scripts/federations-edit.ts`, `site/src/lib/federations/render.ts`, `render.test.ts`

**Interfaces:**
- Consumes: `loadFederationGames().review`, `FedOp` `decide`, `feds.gameDecisions`.
- Produces: `reviewRow(item: ReviewItem, decision: 'same' | 'different' | undefined, canSave: boolean): string` in `render.ts`.

- [ ] **Step 1: Failing render tests:** output contains both tables seat by seat (10 rows: seat, fed nick + role, club player + role), mismatching seats marked with class `diff`; buttons `data-decide="same"` / `"different"` with `data-key=<item.key>`, `disabled` when `!canSave`; current decision shown as «Рішення: та сама гра / інша гра» with a «Скасувати» button (`value: null`); all strings pass through `esc()`.
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS.
- [ ] **Step 5:** Page: section «Можливі дублікати ігор (N)» after the unmatched block, baked JSON `<script type="application/json" id="review">`; hint «Рішення застосується після наступного білду (до години).»; click → `saveFedOp({kind:'decide', ...})` → re-render. Empty list → «Немає».
- [ ] **Step 6:** `npm run check && npm run build`; preview shows the section (with a hand-made `data/federation_games.json` if the smoke run found no partial matches).
- [ ] **Step 7: Commit** `feat(federations): review possible duplicate games`.

---

### Task 8: Docs, verification, deploy

- [ ] **Step 1:** `CLAUDE.md` "Federation profiles" bullet: replace "Next step…" with the games pipeline (fetch nightly into the Actions cache `fedgames-*`, `scripts/federation-games.ts` in the build, `data/federation_games.json`, toggle on `/players/`, review on `/federations/edit/`, `FED_BUDGET_MIN`, manual first fill via "Run workflow" with `federations` checked). Spec link.
- [ ] **Step 2:** Full verification: `cd site && npm run check && npx vitest run && npm run build`; rules tests; `flutter test` not needed (no Dart change) — confirm with `git diff --stat master -- lib/ test/` empty.
- [ ] **Step 3:** Final whole-branch review (fresh reviewer, opus) against spec + Review Focus; fix findings with RED→GREEN tests.
- [ ] **Step 4:** Ask the owner to approve publishing the rule; paste only the changed `config/federations` block in the console editor; Publish after explicit yes; verify an anonymous REST read of `config/federations` still works.
- [ ] **Step 5:** Commit, push `feature/flutter_migration`, fast-forward and push `master`. Start the first fill: `gh workflow run web.yml --ref master -f federations=true`; `gh run watch`; check the log line counts and live `/players/?t=1`.
- [ ] **Step 6:** Update memory `familymafia-federation-matching.md` (games live, cache, how to refill).
