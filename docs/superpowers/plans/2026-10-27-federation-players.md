# Federation Player Matching Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Find candidate profiles of every roster player on imafia.org, emotion.games, fiim.world and mafgame.org, and let an admin confirm them on `/federations/edit/`.

**Architecture:** A manual Node script (`site/scripts/find-federation-players.ts`) scrapes the four sites with pure, fixture-tested parsers and writes the committed `assets/raw/federation_candidates.json`. The static admin page bakes that file in and reads/writes confirmations in Firestore `config/federations` (public read, admin write). Roster rename/merge on `/players/edit/` moves a player's federation entries in the same transaction.

**Tech Stack:** TypeScript (Node 24 type-stripping for scripts), Astro 7, Firebase JS SDK 12, vitest 5, `@firebase/rules-unit-testing`.

**Spec:** `docs/superpowers/specs/2026-10-27-federation-players-design.md`

## Global Constraints

- Federation keys, everywhere: `'imafia' | 'eg' | 'fiim' | 'mafgame'`; ids are strings.
- Candidate key string: `` `${fed}:${id}` ``.
- Profile URLs: imafia `https://imafia.org/u/<id>`, eg `https://emotion.games/ua/players/<player_id>`, fiim `https://fiim.world/user/<id>/show`, mafgame `https://mafgame.org/user/<id>/view`.
- Club sources: eg `GET https://api-v1.emotion.games/club/clubs/13?page=N` (`members`, `members_pagination.total_pages`); mafgame `https://mafgame.org/clubs/9/members?page=N` (Inertia JSON in the `data-page` attribute, `props.search_results`).
- Nick search: imafia `https://imafia.org/rating?f[name]=<q>` (HTML, `/u/<id>` links, nick + «(Ім'я Прізвище)»); fiim `https://fiim.world/rating/search?year=all&name=<q>&masters=global` (JSON `{success: html}` with nick, real name, start year, club, «(Місто, Країна)», tournaments); eg `https://api-v1.emotion.games/year_points/summary?year=Y` for Y = 2024..current year (crawl once, match locally); mafgame `https://mafgame.org/rating?year=Y&page=N` for Y in `props.years` (crawl once, match locally).
- Strong candidate (`strength: 'club'`): eg/mafgame club members, fiim results whose club contains "Family Mafia" or whose city is Черкассы/Черкаси. Everything else `'nick'`.
- Requests sequential, `delayMs` default 300, one retry; a federation that fails keeps its candidates from the previous file.
- Firestore `config/federations` = `{links: {[rosterName]: {[fed]: string[]}}, rejected: {[rosterName]: string[]}, updatedAt, updatedBy, updatedByEmail}`; public read, admin create/update, no delete.
- Every value from the candidates file or Firestore goes through `esc()` (`site/src/lib/annual/render.ts`) before `innerHTML`.
- Page copy in Ukrainian badges: «в нашому клубі» (club), «збіг ніку» (nick). Filters: «Не переглянуті» (default), «Підтверджені», «Нічого не знайдено», «Усі».
- Push both `feature/flutter_migration` and `master`; publish the Firestore rule before pushing code that reads `config/federations`.

## Review Focus

1. Nick differs only by case, surrounding spaces, or a Latin/Cyrillic look-alike letter (`Tina` vs `Тina`) → still matches; `Luna` vs `Луна` → does not. Pinned in Task 1.
2. Roster name containing `.`, `/`, `'` or spaces used as a map key in `config/federations` → saves and reloads intact. Pinned in Tasks 1 and 4.
3. One federation unreachable during a run → its old candidates survive, others refresh, script exits 0 with a warning. Pinned in Task 3.
4. A player renamed since the last search run → the page still shows his candidates via `nicknames`. Pinned in Task 1 (`candidatesFor`).
5. Pasted profile URL with a language prefix, trailing slash or query (`https://emotion.games/en/players/87?tab=x`, `imafia.org/u/1003/`) → parsed; an unrelated URL → clear error, no write. Pinned in Task 1.

---

### Task 1: Pure core — types, matching, ops

**Files:**
- Create: `site/src/lib/federations/core.ts`
- Test: `site/src/lib/federations/core.test.ts`

**Interfaces:**
- Produces:
  - `type Fed = 'imafia' | 'eg' | 'fiim' | 'mafgame'`; `const FEDS: Fed[]` in that order.
  - `interface Candidate { fed: Fed; id: string; nick: string; realName?: string; club?: string; city?: string; games?: number; url: string; strength: 'club' | 'nick' }`
  - `interface CandidatesFile { generatedAt: string; players: Record<string, Candidate[]>; unmatched: Candidate[] }`
  - `interface FedDoc { links: Record<string, Partial<Record<Fed, string[]>>>; rejected: Record<string, string[]> }`
  - `type FedOp = { kind: 'link' | 'unlink'; player: string; fed: Fed; id: string } | { kind: 'reviewed'; player: string; keys: string[] } | { kind: 'unreject'; player: string; key: string }`
  - `normNick(s: string): string`, `profileUrl(fed: Fed, id: string): string`, `parseProfileUrl(url: string): { fed: Fed; id: string } | null`, `candKey(c: { fed: Fed; id: string }): string`
  - `candidatesFor(file: CandidatesFile, entry: RosterEntry): Candidate[]` (deduped by key)
  - `applyFedOp(d: FedDoc, op: FedOp): FedDoc`
  - `moveForRosterOp(d: FedDoc, op: RosterOp): FedDoc`
  - `rowStatus(d: FedDoc, player: string, cands: Candidate[]): 'unreviewed' | 'confirmed' | 'nothing' | 'reviewed'`
  - `sharedLinks(d: FedDoc): Map<string, string[]>` (candidate key → players, only where ≥ 2)

- [ ] **Step 1: Write the failing tests** (`core.test.ts`)

```ts
it('normNick folds case, spaces and look-alike letters, not transliteration', () => {
  expect(normNick('  Tina ')).toBe(normNick('Тina'));      // Cyrillic Т
  expect(normNick('Seezov')).toBe(normNick('SEEZOV'));
  expect(normNick('Luna')).not.toBe(normNick('Луна'));
});
it('parseProfileUrl handles prefixes, slashes, queries; rejects others', () => {
  expect(parseProfileUrl('https://emotion.games/en/players/87?tab=x')).toEqual({ fed: 'eg', id: '87' });
  expect(parseProfileUrl('imafia.org/u/1003/')).toEqual({ fed: 'imafia', id: '1003' });
  expect(parseProfileUrl('https://fiim.world/user/9169/show')).toEqual({ fed: 'fiim', id: '9169' });
  expect(parseProfileUrl('https://mafgame.org/user/899/view')).toEqual({ fed: 'mafgame', id: '899' });
  expect(parseProfileUrl('https://example.com/u/1')).toBeNull();
});
it('candidatesFor finds entries stored under an old name via nicknames', () => {
  const c = { fed: 'eg', id: '87', nick: 'Seezov', url: '', strength: 'club' } as const;
  const file = { generatedAt: '', players: { 'Old': [c], 'Seezov': [c] }, unmatched: [] };
  expect(candidatesFor(file, { name: 'Seezov', nicknames: ['Old'] })).toEqual([c]);
});
it('link/unlink/reviewed/unreject', () => {
  let d: FedDoc = { links: {}, rejected: { 'P.1': ['eg:1'] } };
  d = applyFedOp(d, { kind: 'link', player: 'P.1', fed: 'eg', id: '1' });
  expect(d.links['P.1'].eg).toEqual(['1']); expect(d.rejected['P.1']).toEqual([]);   // link un-rejects
  d = applyFedOp(d, { kind: 'reviewed', player: 'P.1', keys: ['imafia:5'] });
  expect(d.rejected['P.1']).toEqual(['imafia:5']);
  d = applyFedOp(d, { kind: 'unlink', player: 'P.1', fed: 'eg', id: '1' });
  expect(d.links['P.1'].eg).toEqual([]); expect(d.rejected['P.1']).toEqual(['imafia:5']); // unlink ≠ reject
});
it('moveForRosterOp renames keys and unions on merge', () => {
  const d: FedDoc = { links: { A: { eg: ['1'] }, B: { eg: ['2'], fiim: ['3'] } }, rejected: { A: ['x:1'], B: ['x:1', 'x:2'] } };
  expect(moveForRosterOp(d, { kind: 'rename', player: 'A', to: 'A2' }).links).toEqual({ A2: { eg: ['1'] }, B: { eg: ['2'], fiim: ['3'] } });
  const m = moveForRosterOp(d, { kind: 'merge', from: 'A', into: 'B' });
  expect(m.links).toEqual({ B: { eg: ['2', '1'], fiim: ['3'] } });
  expect(m.rejected).toEqual({ B: ['x:1', 'x:2'] });
});
it('rowStatus and sharedLinks', () => {
  const c = (id: string) => ({ fed: 'eg' as const, id, nick: 'n', url: '', strength: 'nick' as const });
  const d: FedDoc = { links: { A: { eg: ['1'] }, B: { eg: ['1'] } }, rejected: { C: ['eg:2'] } };
  expect(rowStatus(d, 'A', [c('1'), c('9')])).toBe('unreviewed');
  expect(rowStatus(d, 'A', [c('1')])).toBe('confirmed');
  expect(rowStatus(d, 'C', [c('2')])).toBe('reviewed');
  expect(rowStatus(d, 'D', [])).toBe('nothing');
  expect(sharedLinks(d).get('eg:1')).toEqual(['A', 'B']);
});
```

- [ ] **Step 2: Run to verify failure** — `cd site && npx vitest run src/lib/federations/core.test.ts` → FAIL (module not found).

- [ ] **Step 3: Implement `core.ts`.** `normNick`: NFC, trim, collapse inner spaces, lower-case, then map Latin look-alikes `a c e i o p x y` to Cyrillic `а с е і о р х у` (ASCII lower-case only; nothing else). `rowStatus`: `unreviewed` if any candidate is neither linked nor rejected; else `confirmed` if any link; else `nothing` if no candidates; else `reviewed`. Ops never mutate the input; `link` dedupes ids. Import `RosterEntry`, `RosterOp` from `../roster/roster`.

- [ ] **Step 4: Run tests** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(federations): pure matching core"`.

---

### Task 2: Federation parsers with fixtures

**Files:**
- Create: `site/scripts/federations/parse.ts`, `site/scripts/federations/parse.test.ts`
- Create: `site/scripts/federations/fixtures/` — `eg-club-13-p1.json`, `eg-summary-2026.json` (trim to ~20 rows incl. a club 13 row), `mafgame-members-9.html`, `mafgame-rating.html`, `fiim-search-seezov.json`, `imafia-search-seezov.html`, `imafia-u-1003.html`, `imafia-u-640.html`

**Interfaces:**
- Consumes: `Candidate`, `profileUrl` (Task 1).
- Produces (all pure, return `Candidate[]` unless noted):
  - `parseEgClub(json): { members: Candidate[]; totalPages: number }` (strength club; `games` = `tournaments`; id = `player_id`)
  - `parseEgSummary(json): Candidate[]` (strength club when `club_id === 13`; id = `player_id`; `club` = `club`)
  - `inertiaProps(html: string): any` (decodes `data-page`)
  - `parseMafgameMembers(html): { members: Candidate[]; lastPage: number }` (realName = `display_name`)
  - `parseMafgameRating(html): { rows: Candidate[]; lastPage: number; years: number[] }` (club unknown → strength nick)
  - `parseFiimSearch(json): Candidate[]` (strength club per Global Constraints)
  - `parseImafiaSearch(html): Candidate[]` (nick + realName from «(…)»)
  - `parseImafiaProfile(html): { realName?: string; club?: string; country?: string; games?: number }` (club «Поза клубом» → undefined; games from «G/S/T <g>/…»)

- [ ] **Step 1: Save fixtures** with `curl -gsL -A "Mozilla/5.0"` from the URLs in Global Constraints (Seezov = imafia 1003, fiim 9169, eg 87).

- [ ] **Step 2: Write failing tests** — one per parser, asserting concrete values from the fixtures, at least:

```ts
expect(parseEgClub(eg).members[0]).toMatchObject({ fed: 'eg', id: '87', nick: 'Seezov', strength: 'club', url: 'https://emotion.games/ua/players/87' });
expect(parseEgClub(eg).totalPages).toBe(6);
expect(parseFiimSearch(fiim)[0]).toMatchObject({ id: '9169', nick: 'Seezov', realName: 'Олександр Сізов', club: 'Family Mafia Club', strength: 'club' });
expect(parseImafiaSearch(im)[0]).toMatchObject({ fed: 'imafia', id: '1003', nick: 'Seezov' });
expect(parseImafiaProfile(u1003)).toMatchObject({ realName: 'Сізов Олександр', club: undefined });
expect(parseImafiaProfile(u640).club).toBe('Big Ben Mafia Club');
expect(parseMafgameMembers(mg).members.find((m) => m.nick === 'Majest')).toMatchObject({ id: '899', realName: 'Anton', strength: 'club' });
```

- [ ] **Step 3: Run** `cd site && npx vitest run scripts/federations` → FAIL.
- [ ] **Step 4: Implement `parse.ts`** with regex/string parsing only (no DOM library; keep dependencies unchanged). HTML entities decoded for text.
- [ ] **Step 5: Run** → PASS.
- [ ] **Step 6: Commit** — `feat(federations): site parsers with fixtures`.

---

### Task 3: Search script → `assets/raw/federation_candidates.json`

**Files:**
- Create: `site/scripts/find-federation-players.ts`, `site/scripts/find-federation-players.test.ts`
- Create (by running it): `assets/raw/federation_candidates.json`

**Interfaces:**
- Consumes: Task 1 (`normNick`, `candKey`, `CandidatesFile`), Task 2 parsers.
- Produces: `findCandidates(opts: { fetch: typeof fetch; roster: RosterEntry[]; previous: CandidatesFile | null; log: (s: string) => void; delayMs?: number; year?: number }): Promise<CandidatesFile>`; CLI writes `../assets/raw/federation_candidates.json` (path relative to `site/`), roster read from `https://firestore.googleapis.com/v1/projects/familymafiaapp/databases/(default)/documents/config/players` (REST field shape as in `fetch-profiles.ts`).

- [ ] **Step 1: Write failing tests** with a fake `fetch` routing URLs to Task 2 fixtures:
  - a roster player whose nickname normalises to a club member gets that candidate under his display name;
  - an eg club member matching no roster nick lands in `unmatched`;
  - imafia/fiim are queried once per distinct normalised nick (assert request count), imafia profile fetched only for exact-nick hits;
  - when every `imafia.org` request throws, the result's imafia candidates equal `previous`'s and `log` got a line containing `imafia`;
  - `delayMs: 0` in tests.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.** Order: eg club (all pages) → eg summaries → mafgame members → mafgame rating crawl per year → per distinct nick: fiim search, imafia search (+ profile for exact hits). Keep only results with `normNick(result.nick) === normNick(rosterNick)`. Dedupe by `candKey`; a club-strength copy wins over nick. Sort each player's list by fed order then strength. `unmatched` = club-strength candidates assigned to nobody.
- [ ] **Step 4: Run tests** → PASS.
- [ ] **Step 5: Real run** — `cd site && node scripts/find-federation-players.ts` (≈10–20 min). Expected: log per federation, file written; Seezov has eg 87, fiim 9169, imafia 1003. Spot-check 3 other names by hand.
- [ ] **Step 6: Commit** script, test and the JSON — `feat(federations): candidate search script + first run`.

---

### Task 4: Firestore rule + store

**Files:**
- Modify: `firestore.rules` (add `match /config/federations` next to `config/players`)
- Modify: `firebase/rules-test/rules.test.ts` (new `describe('config/federations')`)
- Create: `site/src/lib/federations/store.ts`

**Interfaces:**
- Consumes: `FedDoc`, `FedOp`, `applyFedOp` (Task 1); `ClubAdmin` from `../club/store`.
- Produces: `loadFeds(): Promise<FedDoc>` (missing doc → empty), `saveFedOp(op: FedOp, u: ClubAdmin): Promise<FedDoc>` (transaction; creates the doc if missing; does **not** bump `meta/state`).

- [ ] **Step 1: Rules tests** mirroring `config/players`: anyone reads; admin creates/updates; non-admin host and guest can't write; rejects extra keys, `links`/`rejected` not a map, forged `updatedBy`/`updatedByEmail`, client `updatedAt`; nobody deletes; an admin write whose `links` key is `"P.1 / O'Neil"` succeeds.
- [ ] **Step 2: Run** `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="$JAVA_HOME/bin:$PATH" npm test` → new tests FAIL.
- [ ] **Step 3: Add the rule** (`keys().hasOnly(['links','rejected','updatedAt','updatedBy','updatedByEmail'])`, both `is map`, stamp checks, `allow delete: if false`).
- [ ] **Step 4: Run** → PASS (whole file).
- [ ] **Step 5: Write `store.ts`** following `roster/store.ts` (`tx.set` of the whole doc so odd keys never become field paths).
- [ ] **Step 6: Commit** — `feat(federations): config/federations rule and store`.

---

### Task 5: Rename/merge carry federation entries

**Files:**
- Modify: `site/src/lib/roster/store.ts` (`saveRosterOp`)

**Interfaces:**
- Consumes: `moveForRosterOp` (Task 1).

- [ ] **Step 1:** In `saveRosterOp`, also `tx.get(doc(db,'config','federations'))` before any write; when `op.kind` is `rename` or `merge` and that doc exists, `tx.set` it with `moveForRosterOp(...)` plus the stamp. Other ops untouched. (Logic is covered by Task 1's `moveForRosterOp` tests; this step is wiring only.)
- [ ] **Step 2:** `cd site && npx vitest run && npx astro check` → PASS, 0 errors.
- [ ] **Step 3: Commit** — `feat(roster): rename/merge moves federation links`.

---

### Task 6: `/federations/edit/` page

**Files:**
- Modify: `site/src/lib/data.ts` — `loadFederationCandidates(): CandidatesFile` reads `../assets/raw/federation_candidates.json` relative to `process.cwd()` (site/); missing file → `{ generatedAt: '', players: {}, unmatched: [] }`.
- Create: `site/src/lib/federations/render.ts`, `site/src/lib/federations/render.test.ts`
- Create: `site/src/pages/federations/edit.astro`, `site/src/scripts/federations-edit.ts`
- Modify: `site/src/pages/players/edit.astro` — hint gets a link to `/federations/edit/` (use the site's base-URL helper from `src/lib/url.ts`).

**Interfaces:**
- Consumes: Tasks 1, 4; `loadRoster`, `autocompleteNames` from roster; `onClubUser`, `signIn`, `signOutUser` from `club/store`.
- Produces: `fedRow(entry: RosterEntry, cands: Candidate[], d: FedDoc, o: { canSave: boolean; showRejected: boolean; shared: Map<string,string[]> }): string`, `unmatchedRow(c: Candidate, d: FedDoc, canSave: boolean): string`, `filterRows(...)` for the four filters + text search.

- [ ] **Step 1: Failing render tests:**
  - row has four columns in `FEDS` order; a candidate card shows nick, realName, `club · city`, games, badge «в нашому клубі»/«збіг ніку», `<a href=url target=_blank rel=noopener>`, and a checkbox `data-act="toggle"` `checked` iff linked;
  - rejected cards hidden unless `showRejected`;
  - a key in `shared` renders a warning naming the other player;
  - `<script>` in nick/realName comes out escaped;
  - `canSave: false` → checkboxes `disabled`, no «Переглянуто» button, no URL field;
  - unmatched row hidden once its key is linked to anyone.
- [ ] **Step 2: Run** → FAIL. **Step 3: Implement `render.ts`.** **Step 4: Run** → PASS.
- [ ] **Step 5: Page + script.** Shell/auth like `players/edit.astro` (same `.access` panel, `#msg`, Ukrainian labels per Global Constraints). Candidates baked via `<script type="application/json" id="cands">` with `<` escaped. Actions: checkbox → `link`/`unlink`; «Переглянуто» → `reviewed` with all unlinked, unrejected candidate keys of the row; «Показати відхилені» toggle → `unreject` per card; URL field → `parseProfileUrl` → `link` (null → error in `#msg`, no write); unmatched row: roster-name input with `<datalist>` from `autocompleteNames` → `link`. Show counters per filter; render at most 100 rows like `/players/edit/`. Header shows `generatedAt`.
- [ ] **Step 6: Verify** — `cd site && npm test && npx astro check && npm run build` (export data must exist locally; build passes `check-dist`). Then `npm run dev`, open `/federations/edit/` in Chrome, sign in as admin, link and unlink Seezov's eg 87, reload, confirm it persisted.
- [ ] **Step 7: Commit** — `feat(federations): /federations/edit/ review page`.

---

### Task 7: Ship

- [ ] **Step 1:** Publish the `config/federations` rule in the Firebase console Rules tab (owner authorized clicking Publish); verify by reading the doc anonymously over REST (404 or 200, not 403).
- [ ] **Step 2:** Update `CLAUDE.md` Web site section with one bullet: script, JSON, page, Firestore doc, re-run command.
- [ ] **Step 3:** Push `feature/flutter_migration`, fast-forward and push `master`; watch `web.yml` go green; open the live `/federations/edit/`.
- [ ] **Step 4: Commit** docs change before the push — `docs: federation matching in CLAUDE.md`.
