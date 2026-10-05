# Game Appeals Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players appeal for an additional point on a current-season game they played; admins accept / partially accept / reject on `/account/admin/`, accepted points go straight into the game, and admins see the full appeal history.

**Architecture:** New Firestore collection `appeals/{gameId}_{uid}` guarded by `firestore.rules`. Pure logic in `site/src/lib/appeals/core.ts`, HTML in `render.ts`, Firestore calls in `store.ts`. The player UI is a new section on `/account/`, the admin UI a new section on `/account/admin/`. A decision is one transaction: game seat `additional` + comment, appeal status, `meta/state` bump.

**Tech Stack:** Astro 7 static site, TypeScript, Firebase JS SDK 12 (Auth + Firestore), vitest 5, `@firebase/rules-unit-testing` on the Firestore emulator.

**Spec:** `docs/superpowers/specs/2026-10-05-game-appeals-design.md`

## Global Constraints

- Appeals only for Firestore games (`/host/`, season 32+), only the **current** season = newest `config/seasons` entry whose `startDate` has come (`hostDefaultSeason(list, today, null)`).
- A player appeals only for themselves, only on a game they sat in, only with an **approved** claim; seat's `player` must equal the claim's `player`.
- `text`: 1–1000 chars (trimmed). `requested`: number, 0 < x ≤ 5, rounded to 2 decimals. `adminComment` ≤ 1000.
- `accepted` ⇒ `granted == requested`; `partial` ⇒ 0 < `granted` < `requested`; `rejected` ⇒ no `granted`.
- Accepted/partial adds `granted` to the seat's `additional` (rounded to 2 decimals) and appends comment `{ slot: seat, text: "Апеляція: +X" }` in the same transaction.
- One appeal per (game, player): doc id `${gameId}_${uid}`. Player edits only `text`/`requested` while `pending`; withdraw = delete while `pending`.
- History visible to admins only; player sees only own appeals.
- UI copy is Ukrainian. Escape every interpolated value in HTML (`esc`).
- Rules must be published in the Firebase console **before** pushing code. Push `feature/flutter_migration`, then fast-forward `master` (no force-push).

## Review Focus

1. Host edits the game after filing and moves/renames the player's seat → decision must look the seat up by name, not by the stored seat index, and fail cleanly if the player is gone (Task 2 test `applyGrant … moved` / `… gone`).
2. Floating-point sums (0.1 + 0.2) → stored `additional` must be `0.3`, not `0.30000000000000004` (Task 2 `round2` test).
3. Two admins deciding the same appeal at once → second must fail, not double-add points (Task 4: transaction re-reads status; Task 1 rules test "decided appeal cannot be decided again").
4. Input with a comma decimal ("0,5") from Ukrainian keyboards → parsed as 0.5 (Task 2 `parseRequested` test).
5. Admin decides after the season ended → still allowed (rules only gate filing/editing by current season, not decisions) (Task 1 test "admin decides on a past season").

---

## File Structure

| File | Responsibility |
|---|---|
| `firestore.rules` (modify) | `match /appeals/{id}` |
| `firebase/rules-test/rules.test.ts` (modify) | `describe('appeals')` |
| `site/src/lib/appeals/core.ts` (create) | types, validation, grant math, game list for a player, history filter/totals |
| `site/src/lib/appeals/core.test.ts` (create) | unit tests |
| `site/src/lib/appeals/render.ts` (create) | HTML strings for player rows, pending cards, history, totals |
| `site/src/lib/appeals/render.test.ts` (create) | escaping + labels |
| `site/src/lib/appeals/store.ts` (create) | Firestore reads/writes, decision transaction, error text |
| `site/src/pages/account/index.astro`, `site/src/scripts/account.ts` (modify) | player section |
| `site/src/pages/account/admin.astro`, `site/src/scripts/account-admin.ts` (modify) | admin section (Нові / Історія) |
| `CLAUDE.md` (modify) | one bullet under Web site |

---

### Task 1: Firestore rules for appeals

**Files:**
- Modify: `firestore.rules` (add block after `match /profiles/{key} { … }`)
- Test: `firebase/rules-test/rules.test.ts` (append a `describe('appeals')`)

**Interfaces:**
- Produces: collection `appeals/{gameId}_{uid}` with fields `gameId, season, date, table, gameNumber, host, seat, player, uid, email, text, requested, status, createdAt, updatedAt` (+ `granted, adminComment, decidedBy, decidedAt` after a decision). Later tasks write exactly these.

- [ ] **Step 1: Write the failing tests** — append to `firebase/rules-test/rules.test.ts`:

```ts
describe('appeals', () => {
  // Braun (PLAYER, approved) sits in seat 1 of G1, season 32 which started and is the newest.
  const AID = `${G1}_${PLAYER.uid}`;
  const seasons = (list: { id: number; startDate: string }[]) =>
    env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'seasons'),
      { seasons: list.map((s) => ({ ...s, title: `Season ${s.id}`, smallLeagueMinGames: 15 })) }));
  const seedGame = (extra: Record<string, unknown> = {}) =>
    env.withSecurityRulesDisabled((ctx) => {
      const g = game(HOST, extra);
      g.seats[0] = seat('Braun', 'Мирний');
      return setDoc(doc(ctx.firestore(), 'games', G1), { ...g, createdAt: new Date(), updatedAt: new Date() });
    });
  const appeal = (extra: Record<string, unknown> = {}) => ({
    gameId: G1, season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень', seat: 1,
    player: 'Braun', uid: PLAYER.uid, email: PLAYER.email, text: 'Знайшов шерифа', requested: 0.5,
    status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...extra,
  });
  const file = (u: User, extra: Record<string, unknown> = {}, id = AID) => setDoc(doc(as(u), 'appeals', id), appeal(extra));
  const decide = (u: User, d: Record<string, unknown>) =>
    updateDoc(doc(as(u), 'appeals', AID), { decidedBy: u.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...d });
  const grant = (u: User, d: Record<string, unknown>, additional = 0.5) => {
    const db = as(u);
    const b = writeBatch(db);
    const seats = game(HOST).seats.map((s, i) => (i === 0 ? { ...seat('Braun', 'Мирний'), additional } : s));
    b.update(doc(db, 'games', G1), { seats, updatedBy: u.uid, updatedAt: serverTimestamp() });
    b.update(doc(db, 'appeals', AID), { decidedBy: u.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(), ...d });
    return b.commit();
  };

  beforeEach(async () => {
    await seasons([{ id: 32, startDate: '2026-01-01' }]);
    await seedGame();
    await seedApproved(PLAYER);
  });

  it('an approved player files on their own current-season game', async () => {
    await assertSucceeds(file(PLAYER));
  });
  it('id must be gameId_uid', async () => {
    await assertFails(file(PLAYER, {}, `${G1}_${RIVAL.uid}`));
    await assertFails(file(PLAYER, {}, 'whatever'));
  });
  it('not for someone else’s seat or name', async () => {
    await assertFails(file(PLAYER, { seat: 2 }));
    await assertFails(file(PLAYER, { player: 'P2', seat: 2 }));
  });
  it('not without an approved claim', async () => {
    await setDoc(doc(as(RIVAL), 'claims', RIVAL.uid), claim(RIVAL));
    await assertFails(file(RIVAL, { uid: RIVAL.uid, email: RIVAL.email }, `${G1}_${RIVAL.uid}`));
  });
  it('not on an unrated game', async () => {
    await seedGame({ result: 'unrated' });
    await assertFails(file(PLAYER));
  });
  it('not on a past or not-yet-started season', async () => {
    await seasons([{ id: 32, startDate: '2026-01-01' }, { id: 33, startDate: '2026-02-01' }]);
    await assertFails(file(PLAYER));
    await seasons([{ id: 32, startDate: '2099-01-01' }]);
    await assertFails(file(PLAYER));
  });
  it('snapshot must match the game', async () => {
    await assertFails(file(PLAYER, { host: 'Інший' }));
    await assertFails(file(PLAYER, { gameNumber: 2 }));
    await assertFails(file(PLAYER, { season: 33 }));
  });
  it('bad text, amount, status or extra fields are denied', async () => {
    for (const extra of [{ text: '' }, { text: 'x'.repeat(1001) }, { requested: 0 }, { requested: 5.5 },
      { requested: '1' }, { status: 'accepted' }, { granted: 1 }, { extra: 1 }, { email: RIVAL.email }])
      await assertFails(file(PLAYER, extra));
  });
  it('owner and admins read; others do not', async () => {
    await file(PLAYER);
    await assertSucceeds(getDoc(doc(as(PLAYER), 'appeals', AID)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'appeals', AID)));
    await assertFails(getDoc(doc(as(RIVAL), 'appeals', AID)));
    await assertFails(getDoc(doc(as(HOST), 'appeals', AID)));
  });
  it('owner edits text and amount while pending, nothing else', async () => {
    await file(PLAYER);
    const ref = doc(as(PLAYER), 'appeals', AID);
    await assertSucceeds(updateDoc(ref, { text: 'Інакше', requested: 0.3, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { seat: 2, updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { status: 'accepted', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(ref, { requested: 9, updatedAt: serverTimestamp() }));
  });
  it('owner withdraws while pending; not after a decision', async () => {
    await file(PLAYER);
    await assertSucceeds(deleteDoc(doc(as(PLAYER), 'appeals', AID)));
    await file(PLAYER);
    await decide(ADMIN, { status: 'rejected' });
    await assertFails(deleteDoc(doc(as(PLAYER), 'appeals', AID)));
    await assertFails(updateDoc(doc(as(PLAYER), 'appeals', AID), { text: 'x', updatedAt: serverTimestamp() }));
  });
  it('admin rejects, with a comment; not with granted or a forged decidedBy', async () => {
    await file(PLAYER);
    await assertFails(decide(ADMIN, { status: 'rejected', granted: 0.5 }));
    await assertFails(decide(ADMIN, { status: 'rejected', decidedBy: HOST.email }));
    await assertSucceeds(decide(ADMIN, { status: 'rejected', adminComment: 'Ні' }));
  });
  it('non-admins cannot decide', async () => {
    await file(PLAYER);
    await assertFails(decide(HOST, { status: 'rejected' }));
    await assertFails(decide(PLAYER, { status: 'rejected' }));
  });
  it('admin accepts with the game written in the same batch', async () => {
    await file(PLAYER);
    await assertFails(decide(ADMIN, { status: 'accepted', granted: 0.5 }));
    await assertFails(grant(ADMIN, { status: 'accepted', granted: 0.4 }));
    await assertSucceeds(grant(ADMIN, { status: 'accepted', granted: 0.5 }));
  });
  it('partial: 0 < granted < requested', async () => {
    await file(PLAYER);
    await assertFails(grant(ADMIN, { status: 'partial', granted: 0.5 }));
    await assertFails(grant(ADMIN, { status: 'partial', granted: 0 }));
    await assertSucceeds(grant(ADMIN, { status: 'partial', granted: 0.2 }, 0.2));
  });
  it('a decided appeal cannot be decided again', async () => {
    await file(PLAYER);
    await decide(ADMIN, { status: 'rejected' });
    await assertFails(grant(ADMIN, { status: 'accepted', granted: 0.5 }));
  });
  it('admin decides on a past season', async () => {
    await file(PLAYER);
    await seasons([{ id: 32, startDate: '2026-01-01' }, { id: 33, startDate: '2026-02-01' }]);
    await assertSucceeds(decide(ADMIN, { status: 'rejected' }));
  });
  it('admin may delete any appeal', async () => {
    await file(PLAYER);
    await assertSucceeds(deleteDoc(doc(as(ADMIN), 'appeals', AID)));
  });
});
```

- [ ] **Step 2: Run to verify they fail**

```bash
cd firebase/rules-test && export JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" && export PATH="$JAVA_HOME/bin:$PATH" && npm test
```
Expected: the `appeals` tests that call `assertSucceeds` FAIL (no rule → denied); all older tests PASS.

- [ ] **Step 3: Add the rules** — in `firestore.rules`, after the `match /profiles/{key} { … }` block:

```
    // Appeals for an additional point (season 32+ games). Id = gameId + '_' + uid: one per player per game.
    match /appeals/{id} {
      function gameAt(gid) { return get(/databases/$(database)/documents/games/$(gid)).data; }
      function seasonStart(s) {
        let p = s.startDate.split('-');
        return timestamp.date(int(p[0]), int(p[1]), int(p[2]));
      }
      // config/seasons is ordered by id and contiguous. Keep in sync with hostDefaultSeason (seasons.ts).
      function isCurrentSeason(season) {
        let list = get(/databases/$(database)/documents/config/seasons).data.seasons;
        let i = season - list[0].id;
        return i >= 0 && i < list.size() && list[i].id == season && seasonStart(list[i]) <= request.time
          && (i == list.size() - 1 || seasonStart(list[i + 1]) > request.time);
      }
      function validAmount(n) { return (n is int || n is float) && n > 0 && n <= 5; }
      function validText(t) { return t is string && t.size() >= 1 && t.size() <= 1000; }
      function claimPlayer() { return get(/databases/$(database)/documents/claims/$(request.auth.uid)).data.player; }
      function validFiling(d) {
        let fields = ['gameId', 'season', 'date', 'table', 'gameNumber', 'host', 'seat', 'player', 'uid', 'email',
          'text', 'requested', 'status', 'createdAt', 'updatedAt'];
        return d.keys().hasOnly(fields) && d.keys().hasAll(fields)
          && d.gameId is string && d.gameId.matches('^[A-Za-z0-9]{20}$')
          && id == d.gameId + '_' + request.auth.uid
          && d.uid == request.auth.uid && d.email == email() && d.player == claimPlayer()
          && d.seat is int && d.seat >= 1 && d.seat <= 10
          && gameAt(d.gameId).seats[d.seat - 1].player == d.player
          && d.season == gameAt(d.gameId).season && d.date == gameAt(d.gameId).date
          && d.table == gameAt(d.gameId).table && d.gameNumber == gameAt(d.gameId).gameNumber
          && d.host == gameAt(d.gameId).host
          && gameAt(d.gameId).result != 'unrated' && isCurrentSeason(d.season)
          && validText(d.text) && validAmount(d.requested)
          && d.status == 'pending' && d.createdAt == request.time && d.updatedAt == request.time;
      }
      function playerEdit(d) {
        return resource.data.uid == request.auth.uid && resource.data.status == 'pending'
          && d.diff(resource.data).affectedKeys().hasOnly(['text', 'requested', 'updatedAt'])
          && validText(d.text) && validAmount(d.requested) && d.updatedAt == request.time
          && isCurrentSeason(resource.data.season);
      }
      function gameWritten(gid) { return getAfter(/databases/$(database)/documents/games/$(gid)).data.updatedAt == request.time; }
      function decision(d) {
        return isAdmin() && resource.data.status == 'pending'
          && d.diff(resource.data).affectedKeys().hasOnly(['status', 'granted', 'adminComment', 'decidedBy', 'decidedAt', 'updatedAt'])
          && d.decidedBy == email() && d.decidedAt == request.time && d.updatedAt == request.time
          && (!('adminComment' in d) || (d.adminComment is string && d.adminComment.size() <= 1000))
          && ((d.status == 'rejected' && !('granted' in d))
            || (d.status == 'accepted' && d.get('granted', null) == d.requested && gameWritten(d.gameId))
            || (d.status == 'partial' && validAmount(d.get('granted', null)) && d.granted < d.requested && gameWritten(d.gameId)));
      }
      allow read: if (signedIn() && resource.data.uid == request.auth.uid) || isAdmin();
      allow create: if approvedPlayer() && validFiling(request.resource.data);
      allow update: if (approvedPlayer() && playerEdit(request.resource.data)) || decision(request.resource.data);
      allow delete: if (signedIn() && resource.data.uid == request.auth.uid && resource.data.status == 'pending') || isAdmin();
    }
```

- [ ] **Step 4: Run all rules tests**

Same command as Step 2. Expected: all PASS. If `timestamp.date` or `split` is rejected by the emulator, replace `seasonStart` with `timestamp.date(int(s.startDate[0:4]), int(s.startDate[5:7]), int(s.startDate[8:10]))` and re-run.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firebase/rules-test/rules.test.ts
git commit -m "feat: firestore rules for game appeals"
```

---

### Task 2: Pure appeal logic

**Files:**
- Create: `site/src/lib/appeals/core.ts`
- Test: `site/src/lib/appeals/core.test.ts`

**Interfaces:**
- Consumes: `GameDoc`, `Seat` from `site/src/lib/hosting/types.ts`.
- Produces (exact):
  - `type AppealStatus = 'pending' | 'accepted' | 'partial' | 'rejected'`
  - `interface Appeal { id: string; gameId: string; season: number; date: string; table: number; gameNumber: number; host: string; seat: number; player: string; uid: string; email: string; text: string; requested: number; status: AppealStatus; granted?: number; adminComment?: string; createdAt?: number; decidedBy?: string; decidedAt?: number }`
  - `interface Decision { status: 'accepted' | 'partial' | 'rejected'; granted?: number; adminComment: string }`
  - `MAX_TEXT = 1000`, `MAX_REQUESTED = 5`
  - `round2(n: number): number`, `parseAmount(s: string): number`, `appealId(gameId: string, uid: string): string`
  - `draftError(text: string, requested: string): string | null`
  - `decisionError(a: Appeal, d: Decision): string | null`, `grantedFor(a: Appeal, d: Decision): number | null`
  - `class SeatGoneError extends Error`, `applyGrant(g: Pick<GameDoc,'seats'|'comments'>, player: string, granted: number): Pick<GameDoc,'seats'|'comments'>`
  - `myGames<G extends GameDoc & { id: string }>(games: G[], player: string): { game: G; seat: number }[]`
  - `interface HistoryFilter { player: string; host: string; status: '' | AppealStatus; season: string }`, `filterHistory(list: Appeal[], f: HistoryFilter): Appeal[]`, `filterFromQuery(q: URLSearchParams): HistoryFilter`, `filterToQuery(f: HistoryFilter): string`
  - `interface HostTotal { host: string; total: number; pending: number; accepted: number; partial: number; rejected: number; points: number }`, `hostTotals(list: Appeal[]): HostTotal[]`

- [ ] **Step 1: Write the failing tests** — `site/src/lib/appeals/core.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import type { GameDoc } from '../hosting/types';
import {
  appealId, applyGrant, decisionError, draftError, filterFromQuery, filterHistory, filterToQuery, grantedFor,
  hostTotals, myGames, parseAmount, round2, SeatGoneError, type Appeal,
} from './core';

const seat = (player: string, additional = 0) => ({ player, role: 'Мирний' as const, fouls: 0, additional, penalty: 0, protocolAdditional: 0, protocolPenalty: 0 });
const game = (id: string, extra: Partial<GameDoc> = {}) => ({
  id, season: 32, date: '2026-12-03', table: 1 as const, gameNumber: 1, host: 'Серпень',
  seats: Array.from({ length: 10 }, (_, i) => seat(`P${i + 1}`)), firstKilled: 0, supportFive: [], protocol: [],
  result: 'city' as const, comments: [], createdBy: '', createdByEmail: '', createdAt: null, updatedBy: '', updatedAt: null, ...extra,
});
const A = (extra: Partial<Appeal> = {}): Appeal => ({
  id: 'g_u', gameId: 'g', season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень', seat: 1,
  player: 'P1', uid: 'u', email: 'p@x', text: 't', requested: 0.5, status: 'pending', createdAt: 1, ...extra,
});

describe('numbers', () => {
  it('round2 hides float noise', () => { expect(round2(0.1 + 0.2)).toBe(0.3); });
  it('parseAmount accepts a comma', () => { expect(parseAmount('0,5')).toBe(0.5); expect(parseAmount(' 1.25 ')).toBe(1.25); });
  it('parseAmount of junk is NaN', () => { expect(parseAmount('abc')).toBeNaN(); expect(parseAmount('')).toBeNaN(); });
  it('appealId', () => { expect(appealId('G', 'U')).toBe('G_U'); });
});

describe('draftError', () => {
  it('ok', () => { expect(draftError(' Знайшов шерифа ', '0,5')).toBeNull(); });
  it('empty or too long text', () => {
    expect(draftError('  ', '0.5')).toMatch(/Опиши/);
    expect(draftError('x'.repeat(1001), '0.5')).toMatch(/1000/);
  });
  it('amount bounds', () => {
    expect(draftError('t', '0')).toMatch(/більше 0/);
    expect(draftError('t', 'x')).toMatch(/більше 0/);
    expect(draftError('t', '5.01')).toMatch(/5/);
    expect(draftError('t', '5')).toBeNull();
  });
});

describe('decisions', () => {
  it('accepted grants what was asked', () => {
    expect(grantedFor(A(), { status: 'accepted', adminComment: '' })).toBe(0.5);
  });
  it('partial grants the admin amount, rounded', () => {
    expect(grantedFor(A(), { status: 'partial', granted: 0.1 + 0.2, adminComment: '' })).toBe(0.3);
  });
  it('rejected grants nothing', () => { expect(grantedFor(A(), { status: 'rejected', adminComment: '' })).toBeNull(); });
  it('partial bounds', () => {
    expect(decisionError(A(), { status: 'partial', granted: 0.5, adminComment: '' })).toMatch(/менше/);
    expect(decisionError(A(), { status: 'partial', granted: 0, adminComment: '' })).toMatch(/більше 0/);
    expect(decisionError(A(), { status: 'partial', granted: NaN, adminComment: '' })).toMatch(/більше 0/);
    expect(decisionError(A(), { status: 'partial', granted: 0.2, adminComment: '' })).toBeNull();
  });
  it('comment length', () => {
    expect(decisionError(A(), { status: 'rejected', adminComment: 'x'.repeat(1001) })).toMatch(/1000/);
  });
});

describe('applyGrant', () => {
  it('adds to the player’s seat and appends a comment', () => {
    const g = game('g');
    g.seats[2] = seat('Braun', 0.1);
    const out = applyGrant(g, 'Braun', 0.2);
    expect(out.seats[2].additional).toBe(0.3);
    expect(out.comments).toEqual([{ slot: 3, text: 'Апеляція: +0.2' }]);
    expect(g.seats[2].additional).toBe(0.1); // input untouched
  });
  it('finds the player after the host moved them (by name, not stored seat)', () => {
    const g = game('g');
    g.seats[7] = seat('Braun');
    expect(applyGrant(g, 'Braun', 0.5).seats[7].additional).toBe(0.5);
  });
  it('throws when the player is gone', () => {
    expect(() => applyGrant(game('g'), 'Braun', 0.5)).toThrow(SeatGoneError);
  });
});

describe('myGames', () => {
  it('rated games where the player sat, newest first, with the seat number', () => {
    const a = game('a', { date: '2026-12-01' }); a.seats[4] = seat('Braun');
    const b = game('b', { date: '2026-12-08', gameNumber: 2 }); b.seats[0] = seat('Braun');
    const c = game('c', { date: '2026-12-09', result: 'unrated' }); c.seats[0] = seat('Braun');
    const d = game('d', { date: '2026-12-10' });
    expect(myGames([a, b, c, d], 'Braun').map((x) => [x.game.id, x.seat])).toEqual([['b', 1], ['a', 5]]);
  });
});

describe('history', () => {
  const list = [
    A({ id: '1', host: 'Серпень', status: 'accepted', granted: 0.5, createdAt: 1 }),
    A({ id: '2', host: 'Серпень', status: 'partial', granted: 0.2, createdAt: 3 }),
    A({ id: '3', host: 'Залізний', player: 'P2', status: 'rejected', season: 33, createdAt: 2 }),
    A({ id: '4', host: 'Залізний', status: 'pending', createdAt: 4 }),
  ];
  const none = { player: '', host: '', status: '' as const, season: '' };
  it('newest first, filters combine', () => {
    expect(filterHistory(list, none).map((a) => a.id)).toEqual(['4', '2', '3', '1']);
    expect(filterHistory(list, { ...none, host: 'Серпень' }).map((a) => a.id)).toEqual(['2', '1']);
    expect(filterHistory(list, { ...none, player: 'p2' }).map((a) => a.id)).toEqual(['3']);
    expect(filterHistory(list, { ...none, status: 'pending' }).map((a) => a.id)).toEqual(['4']);
    expect(filterHistory(list, { ...none, season: '33' }).map((a) => a.id)).toEqual(['3']);
  });
  it('per-host totals', () => {
    expect(hostTotals(list)).toEqual([
      { host: 'Залізний', total: 2, pending: 1, accepted: 0, partial: 0, rejected: 1, points: 0 },
      { host: 'Серпень', total: 2, pending: 0, accepted: 1, partial: 1, rejected: 0, points: 0.7 },
    ]);
  });
  it('query round trip', () => {
    const f = { player: 'Braun', host: 'Серпень', status: 'partial' as const, season: '32' };
    expect(filterFromQuery(new URLSearchParams(filterToQuery(f)))).toEqual(f);
    expect(filterToQuery(none)).toBe('');
    expect(filterFromQuery(new URLSearchParams('status=bogus')).status).toBe('');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd site && npx vitest run src/lib/appeals/core.test.ts`
Expected: FAIL — `Cannot find module './core'`.

- [ ] **Step 3: Implement** — `site/src/lib/appeals/core.ts`:

```ts
// Appeals for an additional point: pure logic shared by /account/ and /account/admin/.
// The same limits are enforced by firestore.rules (match /appeals).
import type { GameDoc } from '../hosting/types';

export type AppealStatus = 'pending' | 'accepted' | 'partial' | 'rejected';
export const STATUSES: AppealStatus[] = ['pending', 'accepted', 'partial', 'rejected'];
export interface Appeal {
  id: string; gameId: string; season: number; date: string; table: number; gameNumber: number; host: string;
  seat: number; player: string; uid: string; email: string; text: string; requested: number; status: AppealStatus;
  granted?: number; adminComment?: string; createdAt?: number; decidedBy?: string; decidedAt?: number;
}
export interface Decision { status: 'accepted' | 'partial' | 'rejected'; granted?: number; adminComment: string }

export const MAX_TEXT = 1000;
export const MAX_REQUESTED = 5;

export const round2 = (n: number) => Math.round(n * 100) / 100;
export const parseAmount = (s: string) => (s.trim() ? round2(Number(s.trim().replace(',', '.'))) : NaN);
export const appealId = (gameId: string, uid: string) => `${gameId}_${uid}`;

export function draftError(text: string, requested: string): string | null {
  const t = text.trim();
  if (!t) return 'Опиши, за що має бути дод бал.';
  if (t.length > MAX_TEXT) return `Опис довший за ${MAX_TEXT} символів.`;
  const n = parseAmount(requested);
  if (!(n > 0)) return 'Очікуваний бал має бути більше 0.';
  if (n > MAX_REQUESTED) return `Очікуваний бал — не більше ${MAX_REQUESTED}.`;
  return null;
}

export function grantedFor(a: Appeal, d: Decision): number | null {
  if (d.status === 'accepted') return a.requested;
  if (d.status === 'partial') return round2(d.granted ?? NaN);
  return null;
}

export function decisionError(a: Appeal, d: Decision): string | null {
  if (d.adminComment.trim().length > MAX_TEXT) return `Коментар довший за ${MAX_TEXT} символів.`;
  if (d.status !== 'partial') return null;
  const g = grantedFor(a, d)!;
  if (!(g > 0)) return 'Нарахований бал має бути більше 0.';
  if (g >= a.requested) return `Частково — це менше, ніж просили (${a.requested}).`;
  return null;
}

export class SeatGoneError extends Error {}

/** The game after granting: the player's seat is found by name, since the host may have moved it. */
export function applyGrant(g: Pick<GameDoc, 'seats' | 'comments'>, player: string, granted: number): Pick<GameDoc, 'seats' | 'comments'> {
  const i = g.seats.findIndex((s) => s.player === player);
  if (i < 0) throw new SeatGoneError(player);
  return {
    seats: g.seats.map((s, j) => (j === i ? { ...s, additional: round2((s.additional || 0) + granted) } : s)),
    comments: [...g.comments, { slot: i + 1, text: `Апеляція: +${granted}` }],
  };
}

/** Rated games the player sat in, newest first, with their seat (1–10). */
export function myGames<G extends GameDoc & { id: string }>(games: G[], player: string): { game: G; seat: number }[] {
  return games
    .filter((g) => g.result !== 'unrated')
    .map((game) => ({ game, seat: game.seats.findIndex((s) => s.player === player) + 1 }))
    .filter((x) => x.seat > 0)
    .sort((a, b) => b.game.date.localeCompare(a.game.date) || b.game.table - a.game.table || b.game.gameNumber - a.game.gameNumber);
}

export interface HistoryFilter { player: string; host: string; status: '' | AppealStatus; season: string }

export function filterHistory(list: Appeal[], f: HistoryFilter): Appeal[] {
  const p = f.player.trim().toLowerCase();
  return list
    .filter((a) => (!p || a.player.toLowerCase().includes(p)) && (!f.host || a.host === f.host)
      && (!f.status || a.status === f.status) && (!f.season || String(a.season) === f.season))
    .sort((a, b) => (b.createdAt ?? 0) - (a.createdAt ?? 0));
}

export function filterFromQuery(q: URLSearchParams): HistoryFilter {
  const status = q.get('status') ?? '';
  return {
    player: q.get('player') ?? '', host: q.get('host') ?? '',
    status: (STATUSES as string[]).includes(status) ? (status as AppealStatus) : '', season: q.get('season') ?? '',
  };
}

export function filterToQuery(f: HistoryFilter): string {
  const q = new URLSearchParams();
  for (const k of ['player', 'host', 'status', 'season'] as const) if (f[k]) q.set(k, f[k]);
  return q.toString();
}

export interface HostTotal { host: string; total: number; pending: number; accepted: number; partial: number; rejected: number; points: number }

export function hostTotals(list: Appeal[]): HostTotal[] {
  const by = new Map<string, HostTotal>();
  for (const a of list) {
    const t = by.get(a.host) ?? { host: a.host, total: 0, pending: 0, accepted: 0, partial: 0, rejected: 0, points: 0 };
    t.total++; t[a.status]++; t.points = round2(t.points + (a.granted ?? 0));
    by.set(a.host, t);
  }
  return [...by.values()].sort((a, b) => b.total - a.total || a.host.localeCompare(b.host, 'uk'));
}
```

- [ ] **Step 4: Run tests**

Run: `cd site && npx vitest run src/lib/appeals/core.test.ts`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/appeals/core.ts site/src/lib/appeals/core.test.ts
git commit -m "feat: appeal validation, grant math and history filters"
```

---

### Task 3: HTML rendering

**Files:**
- Create: `site/src/lib/appeals/render.ts`
- Test: `site/src/lib/appeals/render.test.ts`

**Interfaces:**
- Consumes: `Appeal`, `HostTotal` from `./core`.
- Produces:
  - `esc(v: unknown): string`
  - `gameTitle(a: { date: string; table: number; gameNumber: number }): string` → `"03.12.2026 · Стіл 1 · Гра 1"`
  - `statusLabel(a: Appeal): string`
  - `myGameRow(r: { gameId: string; title: string; host: string; seat: number; appeal: Appeal | null }, open: boolean): string` — `data-game` on the row; buttons `data-act="open"|"save"|"withdraw"|"close"`; inputs `#ap-text`, `#ap-req`
  - `pendingCard(a: Appeal, currentAdditional: number | null, gamesHref: string): string` — buttons `data-act="accept"|"partial"|"reject"` with `data-id`; inputs `.ap-comment`, `.ap-granted` inside the card `[data-id]`
  - `historyRow(a: Appeal): string` (a `<tr>`), `totalsRows(t: HostTotal[]): string` (`<tr>`s)

- [ ] **Step 1: Write the failing tests** — `site/src/lib/appeals/render.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import type { Appeal } from './core';
import { gameTitle, historyRow, myGameRow, pendingCard, statusLabel, totalsRows } from './render';

const A = (extra: Partial<Appeal> = {}): Appeal => ({
  id: 'g_u', gameId: 'g', season: 32, date: '2026-12-03', table: 2, gameNumber: 4, host: 'Серпень', seat: 3,
  player: 'Braun', uid: 'u', email: 'p@x', text: 't', requested: 0.5, status: 'pending', createdAt: 1, ...extra,
});
const XSS = '<img src=x onerror=alert(1)>';

describe('labels', () => {
  it('game title', () => { expect(gameTitle(A())).toBe('03.12.2026 · Стіл 2 · Гра 4'); });
  it('status', () => {
    expect(statusLabel(A())).toBe('на розгляді');
    expect(statusLabel(A({ status: 'accepted', granted: 0.5 }))).toBe('прийнято +0.5');
    expect(statusLabel(A({ status: 'partial', granted: 0.2 }))).toBe('частково +0.2 з 0.5');
    expect(statusLabel(A({ status: 'rejected' }))).toBe('відхилено');
  });
});

describe('escaping', () => {
  it('every user string is escaped', () => {
    const a = A({ text: XSS, player: XSS, host: XSS, adminComment: XSS, status: 'rejected' });
    for (const html of [
      myGameRow({ gameId: 'g', title: XSS, host: XSS, seat: 1, appeal: a }, false),
      myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A({ text: XSS }) }, true),
      pendingCard(A({ text: XSS, player: XSS, host: XSS }), 0, '/x/'),
      historyRow(a),
      totalsRows([{ host: XSS, total: 1, pending: 0, accepted: 0, partial: 0, rejected: 1, points: 0 }]),
    ]) expect(html).not.toContain('<img');
  });
});

describe('player row', () => {
  it('no appeal: offers to file', () => {
    expect(myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: null }, false)).toContain('data-act="open"');
  });
  it('pending: can edit and withdraw', () => {
    const html = myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A() }, true);
    expect(html).toContain('id="ap-text"');
    expect(html).toContain('data-act="withdraw"');
  });
  it('decided: read-only with the admin comment', () => {
    const html = myGameRow({ gameId: 'g', title: 't', host: 'h', seat: 1, appeal: A({ status: 'rejected', adminComment: 'Ні' }) }, false);
    expect(html).not.toContain('data-act="open"');
    expect(html).toContain('Ні');
  });
});

describe('admin', () => {
  it('pending card has the three decisions and the current additional', () => {
    const html = pendingCard(A(), 0.3, '/season/32/games/');
    for (const act of ['accept', 'partial', 'reject']) expect(html).toContain(`data-act="${act}"`);
    expect(html).toContain('зараз дод 0.3');
    expect(html).toContain('href="/season/32/games/"');
  });
  it('history row shows who decided', () => {
    expect(historyRow(A({ status: 'accepted', granted: 0.5, decidedBy: 'admin@x', decidedAt: Date.UTC(2026, 11, 4) }))).toContain('admin@x');
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd site && npx vitest run src/lib/appeals/render.test.ts`
Expected: FAIL — `Cannot find module './render'`.

- [ ] **Step 3: Implement** — `site/src/lib/appeals/render.ts`:

```ts
// HTML for the appeal sections on /account/ and /account/admin/. Every value is escaped.
import { MAX_REQUESTED, MAX_TEXT, type Appeal, type HostTotal } from './core';

export const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const day = (iso: string) => iso.split('-').reverse().join('.');
const when = (ms?: number) => (ms ? new Date(ms).toLocaleDateString('uk-UA') : '');

export const gameTitle = (a: { date: string; table: number; gameNumber: number }) => `${day(a.date)} · Стіл ${a.table} · Гра ${a.gameNumber}`;

export function statusLabel(a: Appeal): string {
  if (a.status === 'accepted') return `прийнято +${a.granted}`;
  if (a.status === 'partial') return `частково +${a.granted} з ${a.requested}`;
  if (a.status === 'rejected') return 'відхилено';
  return 'на розгляді';
}

const form = (a: Appeal | null) => `<div class="ap-form">
  <label class="field">Чому ти заслуговуєш дод бал?
    <textarea id="ap-text" maxlength="${MAX_TEXT}" rows="4">${esc(a?.text ?? '')}</textarea></label>
  <label class="field">Очікуваний дод бал
    <input id="ap-req" inputmode="decimal" value="${esc(a?.requested ?? '')}" placeholder="0.5" /></label>
  <span class="label">Не більше ${MAX_REQUESTED}.</span>
  <div class="actions"><button class="btn sm primary" data-act="save" type="button">${a ? 'Зберегти' : 'Подати апеляцію'}</button>
    ${a ? '<button class="btn sm" data-act="withdraw" type="button">Відкликати</button>' : ''}
    <button class="btn sm" data-act="close" type="button">Скасувати</button></div></div>`;

export function myGameRow(r: { gameId: string; title: string; host: string; seat: number; appeal: Appeal | null }, open: boolean): string {
  const a = r.appeal;
  const head = `<span class="grow"><b>${esc(r.title)}</b> · ведучий ${esc(r.host)} · місце ${r.seat}</span>`;
  const state = a ? `<span class="st-${a.status}">${esc(statusLabel(a))}</span>` : '';
  const action = open ? '' : !a ? '<button class="btn sm" data-act="open" type="button">Подати апеляцію</button>'
    : a.status === 'pending' ? '<button class="btn sm" data-act="open" type="button">Змінити</button>' : '';
  const decided = a && a.status !== 'pending'
    ? `<p class="ap-note">Ти просив +${a.requested}: ${esc(a.text)}${a.adminComment ? `<br>Адмін: ${esc(a.adminComment)}` : ''}</p>` : '';
  return `<div class="box item" data-game="${esc(r.gameId)}">${head}${state}${action}${decided}${open ? form(a) : ''}</div>`;
}

export function pendingCard(a: Appeal, currentAdditional: number | null, gamesHref: string): string {
  const now = currentAdditional === null ? 'гру не знайдено' : `зараз дод ${currentAdditional}`;
  return `<div class="box ap-card" data-id="${esc(a.id)}">
    <p><b>${esc(a.player)}</b> · місце ${a.seat} · <a href="${esc(gamesHref)}">${esc(gameTitle(a))}</a> · ведучий ${esc(a.host)}
      <span class="label">подано ${when(a.createdAt)}</span></p>
    <p>Просить <b>+${a.requested}</b> (${now})</p>
    <p class="ap-text">${esc(a.text)}</p>
    <input class="ap-comment" maxlength="${MAX_TEXT}" placeholder="Коментар (необовʼязково)" />
    <div class="actions">
      <button class="btn sm primary" data-act="accept" data-id="${esc(a.id)}" type="button">Прийняти +${a.requested}</button>
      <input class="ap-granted" inputmode="decimal" placeholder="скільки" aria-label="Скільки нарахувати" />
      <button class="btn sm" data-act="partial" data-id="${esc(a.id)}" type="button">Частково</button>
      <button class="btn sm" data-act="reject" data-id="${esc(a.id)}" type="button">Відхилити</button>
      <span class="ap-msg" aria-live="polite"></span>
    </div></div>`;
}

export const historyRow = (a: Appeal) => `<tr>
  <td>${when(a.createdAt)}</td><td>${esc(a.player)}</td><td>S${a.season} · ${esc(gameTitle(a))}</td><td>${esc(a.host)}</td>
  <td class="num">+${a.requested}</td><td class="st-${a.status}">${esc(statusLabel(a))}</td>
  <td>${esc(a.decidedBy ?? '')}</td><td>${when(a.decidedAt)}</td><td>${esc(a.adminComment ?? '')}</td>
  <td class="ap-text">${esc(a.text)}</td></tr>`;

export const totalsRows = (t: HostTotal[]) => t.map((h) => `<tr><td>${esc(h.host)}</td><td class="num">${h.total}</td>
  <td class="num">${h.pending}</td><td class="num">${h.accepted}</td><td class="num">${h.partial}</td>
  <td class="num">${h.rejected}</td><td class="num">+${h.points}</td></tr>`).join('');
```

- [ ] **Step 4: Run tests**

Run: `cd site && npx vitest run src/lib/appeals`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/appeals/render.ts site/src/lib/appeals/render.test.ts
git commit -m "feat: appeal cards, history rows and host totals markup"
```

---

### Task 4: Firestore store

**Files:**
- Create: `site/src/lib/appeals/store.ts`

**Interfaces:**
- Consumes: `db` from `../firebase`; `AccountUser` from `../account/store`; `Appeal`, `Decision`, `applyGrant`, `grantedFor`, `appealId`, `round2`, `SeatGoneError` from `./core`; `GameDoc` from `../hosting/types`.
- Produces:
  - `listMyAppeals(uid: string): Promise<Appeal[]>`
  - `listAllAppeals(): Promise<Appeal[]>`
  - `getGames(ids: string[]): Promise<Map<string, GameDoc>>`
  - `fileAppeal(u: AccountUser, player: string, game: GameDoc & { id: string }, seat: number, text: string, requested: number): Promise<void>`
  - `editAppeal(id: string, text: string, requested: number): Promise<void>`
  - `withdrawAppeal(id: string): Promise<void>`
  - `decideAppeal(a: Appeal, d: Decision, admin: AccountUser): Promise<void>`
  - `class StaleAppealError extends Error`, `explainAppealError(e: unknown): string`

No unit test (thin Firestore wrapper; rules tests in Task 1 cover the shapes, logic is in `core.ts`). Verified by `astro check` here and manually in Task 7.

- [ ] **Step 1: Implement** — `site/src/lib/appeals/store.ts`:

```ts
// Firestore calls for appeals. Shapes must match firestore.rules (match /appeals).
import {
  collection, deleteDoc, doc, getDoc, getDocs, query, runTransaction, serverTimestamp, setDoc, updateDoc, where, type Timestamp,
} from 'firebase/firestore';
import { db } from '../firebase';
import type { AccountUser } from '../account/store';
import type { GameDoc } from '../hosting/types';
import { appealId, applyGrant, grantedFor, round2, SeatGoneError, type Appeal, type Decision } from './core';

export class StaleAppealError extends Error {}

const ms = (t: unknown) => (t as Timestamp | undefined)?.toMillis?.();
const toAppeal = (id: string, d: Record<string, unknown>): Appeal => ({
  id, gameId: String(d.gameId), season: Number(d.season), date: String(d.date), table: Number(d.table),
  gameNumber: Number(d.gameNumber), host: String(d.host), seat: Number(d.seat), player: String(d.player),
  uid: String(d.uid), email: String(d.email), text: String(d.text), requested: Number(d.requested),
  status: d.status as Appeal['status'],
  ...(typeof d.granted === 'number' ? { granted: d.granted } : {}),
  ...(typeof d.adminComment === 'string' ? { adminComment: d.adminComment } : {}),
  createdAt: ms(d.createdAt),
  ...(typeof d.decidedBy === 'string' ? { decidedBy: d.decidedBy } : {}),
  decidedAt: ms(d.decidedAt),
});

export async function listMyAppeals(uid: string) {
  const s = await getDocs(query(collection(db, 'appeals'), where('uid', '==', uid)));
  return s.docs.map((d) => toAppeal(d.id, d.data()));
}

export async function listAllAppeals() {
  const s = await getDocs(collection(db, 'appeals'));
  return s.docs.map((d) => toAppeal(d.id, d.data()));
}

export async function getGames(ids: string[]) {
  const out = new Map<string, GameDoc>();
  await Promise.all([...new Set(ids)].map(async (id) => {
    const s = await getDoc(doc(db, 'games', id));
    if (s.exists()) out.set(id, s.data() as GameDoc);
  }));
  return out;
}

export const fileAppeal = (u: AccountUser, player: string, g: GameDoc & { id: string }, seat: number, text: string, requested: number) =>
  setDoc(doc(db, 'appeals', appealId(g.id, u.uid)), {
    gameId: g.id, season: g.season, date: g.date, table: g.table, gameNumber: g.gameNumber, host: g.host,
    seat, player, uid: u.uid, email: u.email, text: text.trim(), requested: round2(requested),
    status: 'pending', createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });

export const editAppeal = (id: string, text: string, requested: number) =>
  updateDoc(doc(db, 'appeals', id), { text: text.trim(), requested: round2(requested), updatedAt: serverTimestamp() });

export const withdrawAppeal = (id: string) => deleteDoc(doc(db, 'appeals', id));

/** One transaction: the game's seat + comment (accepted/partial), the appeal's decision, meta/state. */
export async function decideAppeal(a: Appeal, d: Decision, admin: AccountUser) {
  const aRef = doc(db, 'appeals', a.id);
  const gRef = doc(db, 'games', a.gameId);
  await runTransaction(db, async (tx) => {
    const cur = await tx.get(aRef);
    const g = await tx.get(gRef);
    if (!cur.exists() || cur.data().status !== 'pending') throw new StaleAppealError();
    const granted = grantedFor(toAppeal(cur.id, cur.data()), d);
    if (granted !== null) {
      if (!g.exists()) throw new SeatGoneError(a.player);
      tx.update(gRef, { ...applyGrant(g.data() as GameDoc, a.player, granted), updatedBy: admin.uid, updatedAt: serverTimestamp() });
    }
    const comment = d.adminComment.trim();
    tx.update(aRef, {
      status: d.status, ...(granted !== null ? { granted } : {}), ...(comment ? { adminComment: comment } : {}),
      decidedBy: admin.email, decidedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

export function explainAppealError(e: unknown): string {
  if (e instanceof StaleAppealError) return 'Апеляцію вже розглянули або відкликали — онови сторінку.';
  if (e instanceof SeatGoneError) return 'Гравця вже немає в цій грі — перевір гру на /host/.';
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав (сезон закінчився, гру змінили або апеляцію вже розглянули).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання — спробуй ще.';
  return `Помилка: ${code || (e as Error).message}`;
}
```

- [ ] **Step 2: Type-check**

Run: `cd site && npx astro check`
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add site/src/lib/appeals/store.ts
git commit -m "feat: appeals Firestore store with the decision transaction"
```

---

### Task 5: Player section on `/account/`

**Files:**
- Modify: `site/src/pages/account/index.astro` (add a section after the `settings` section; styles)
- Modify: `site/src/scripts/account.ts` (load + handlers)

**Interfaces:**
- Consumes: `loadClubSeasons` (`../lib/seasons/store`), `hostDefaultSeason` (`../lib/seasons/seasons`), `eveningDate` (`../lib/hosting/form`), `listSeasonGames` (`../lib/hosting/store`), Task 2 `myGames`, `draftError`, `parseAmount`, `appealId`, Task 3 `myGameRow`, `gameTitle`, Task 4 `listMyAppeals`, `fileAppeal`, `editAppeal`, `withdrawAppeal`, `explainAppealError`.

- [ ] **Step 1: Markup** — in `site/src/pages/account/index.astro`, right after `</section>` of `data-view="settings"`:

```astro
  <section id="appeals" hidden>
    <h2 class="label">Апеляції</h2>
    <p class="label">Не погоджуєшся з дод балами за гру поточного сезону? Опиши, чому, і скільки балів очікуєш — адмін розгляне.</p>
    <p id="appeals-msg" aria-live="polite"></p>
    <div id="appeal-games" class="list"></div>
  </section>
```

Add to the `<style is:global>` block:

```css
  #appeals[hidden] { display: none; }
  #appeals .list { display: grid; gap: 6px; }
  #appeals .item { display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: center; }
  #appeals .item .grow { flex: 1 1 220px; }
  .ap-form, .ap-note { flex-basis: 100%; }
  #ap-text, #ap-req { background: var(--panel-2); border: 1px solid var(--border); border-radius: 6px; color: var(--text);
    padding: 6px 10px; font: inherit; width: min(520px, 100%); box-sizing: border-box; }
  #ap-req { width: 120px; }
  .st-pending { color: var(--mid); } .st-accepted, .st-partial { color: var(--good); } .st-rejected { color: var(--muted); }
```

- [ ] **Step 2: Script** — in `site/src/scripts/account.ts` add imports:

```ts
import { loadClubSeasons } from '../lib/seasons/store';
import { hostDefaultSeason } from '../lib/seasons/seasons';
import { eveningDate } from '../lib/hosting/form';
import { listSeasonGames } from '../lib/hosting/store';
import type { GameDoc } from '../lib/hosting/types';
import { draftError, myGames, parseAmount, type Appeal } from '../lib/appeals/core';
import { gameTitle, myGameRow } from '../lib/appeals/render';
import { editAppeal, explainAppealError, fileAppeal, listMyAppeals, withdrawAppeal } from '../lib/appeals/store';
```

State and functions (after `let avatar …`):

```ts
let rows: { game: GameDoc & { id: string }; seat: number }[] = [];
let appeals = new Map<string, Appeal>(); // by gameId
let openGame: string | null = null;
const appealsMsg = (text: string, kind: 'error' | 'ok' = 'ok') => { $('appeals-msg').className = kind === 'error' ? 'msg-error' : ''; $('appeals-msg').textContent = text; };

async function loadAppeals() {
  $('appeals').hidden = false;
  const player = mine!.player; // the claim's player name (the profile mirrors the claim)
  try {
    const season = hostDefaultSeason(await loadClubSeasons(), eveningDate(), null);
    if (season === null) { rows = []; appealsMsg('Апеляції відкриються з першим сезоном, що ведеться на сайті.'); return renderAppeals(); }
    const [games, mine] = await Promise.all([listSeasonGames(season), listMyAppeals(user!.uid)]);
    rows = myGames(games, player);
    appeals = new Map(mine.filter((a) => a.season === season).map((a) => [a.gameId, a]));
    appealsMsg(rows.length ? '' : `У сезоні ${season} ще немає твоїх рейтингових ігор.`);
  } catch (e) { appealsMsg(explainAppealError(e), 'error'); }
  renderAppeals();
}

function renderAppeals() {
  $('appeal-games').innerHTML = rows.map(({ game, seat }) => myGameRow(
    { gameId: game.id, title: gameTitle(game), host: game.host, seat, appeal: appeals.get(game.id) ?? null }, openGame === game.id)).join('');
}
```

In `show()`, after `if (view === 'settings') renderSettings();` add:

```ts
  if (view === 'settings') loadAppeals(); else $('appeals').hidden = true;
```

Handler (before `onAccount(...)`):

```ts
$('appeal-games').addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-act]');
  const gameId = b?.closest<HTMLElement>('[data-game]')?.dataset.game;
  if (!b || !gameId || !user || !mine) return;
  const act = b.dataset.act;
  if (act === 'open') { openGame = gameId; return renderAppeals(); }
  if (act === 'close') { openGame = null; return renderAppeals(); }
  const row = rows.find((r) => r.game.id === gameId)!;
  const existing = appeals.get(gameId) ?? null;
  // Withdraw arms on the first tap and runs on the second.
  if (act === 'withdraw' && !b.dataset.armed) { b.dataset.armed = '1'; b.textContent = 'Точно відкликати?'; return; }
  b.disabled = true;
  try {
    if (act === 'withdraw' && existing) await withdrawAppeal(existing.id);
    if (act === 'save') {
      const text = $<HTMLTextAreaElement>('ap-text').value;
      const req = $<HTMLInputElement>('ap-req').value;
      const err = draftError(text, req);
      if (err) { b.disabled = false; return appealsMsg(err, 'error'); }
      if (existing) await editAppeal(existing.id, text, parseAmount(req));
      else await fileAppeal(user, mine.player, row.game, row.seat, text, parseAmount(req));
    }
    openGame = null;
    appealsMsg(act === 'withdraw' ? 'Апеляцію відкликано.' : 'Апеляцію надіслано. Адмін розгляне її.');
    await loadAppeals();
  } catch (err) { appealsMsg(explainAppealError(err), 'error'); b.disabled = false; }
});
```

- [ ] **Step 3: Type-check and unit tests**

Run: `cd site && npx astro check && npx vitest run`
Expected: 0 errors; all tests PASS.

- [ ] **Step 4: Manual smoke (emulator-free)**

Run: `cd site && npm run dev`, open `http://localhost:4321/FamilyMafiaApp/account/` signed in as an approved player. Expected now (no season 32 yet): section «Апеляції» shows «Апеляції відкриються з першим сезоном, що ведеться на сайті.» and no console errors. Stop the dev server.

- [ ] **Step 5: Commit**

```bash
git add site/src/pages/account/index.astro site/src/scripts/account.ts
git commit -m "feat: players file and withdraw appeals on /account/"
```

---

### Task 6: Admin section on `/account/admin/` (Нові + Історія)

**Files:**
- Modify: `site/src/pages/account/admin.astro`
- Modify: `site/src/scripts/account-admin.ts`

**Interfaces:**
- Consumes: Task 2 `filterHistory`, `filterFromQuery`, `filterToQuery`, `hostTotals`, `decisionError`, `parseAmount`, `type Appeal`, `type Decision`; Task 3 `pendingCard`, `historyRow`, `totalsRows`; Task 4 `listAllAppeals`, `getGames`, `decideAppeal`, `explainAppealError`; `href` from `../lib/url` is server-side — pass the base via a JSON script tag.

- [ ] **Step 1: Markup** — in `site/src/pages/account/admin.astro` frontmatter add `import { href } from '../../lib/url';` and `const base = JSON.stringify({ base: href('') });`. Change the title/description to «Адмін: заявки та апеляції». Inside `<section id="admin">`, after the profiles list:

```astro
    <h2 class="label">Апеляції</h2>
    <div class="tabs" role="tablist">
      <button class="btn sm" id="tab-new" role="tab" type="button">Нові <span id="new-count"></span></button>
      <button class="btn sm" id="tab-history" role="tab" type="button">Історія</button>
    </div>
    <div id="appeals-new" class="list"></div>
    <div id="appeals-history" hidden>
      <div class="filters">
        <input id="h-player" placeholder="Гравець" aria-label="Гравець" autocomplete="off" />
        <select id="h-host" aria-label="Ведучий"><option value="">Усі ведучі</option></select>
        <select id="h-status" aria-label="Статус">
          <option value="">Усі статуси</option><option value="pending">на розгляді</option><option value="accepted">прийнято</option>
          <option value="partial">частково</option><option value="rejected">відхилено</option>
        </select>
        <select id="h-season" aria-label="Сезон"><option value="">Усі сезони</option></select>
      </div>
      <div class="scroll"><table class="tbl"><thead><tr><th>Ведучий</th><th>Усього</th><th>Чекає</th><th>Прийнято</th>
        <th>Частково</th><th>Відхилено</th><th>Нараховано</th></tr></thead><tbody id="h-totals"></tbody></table></div>
      <div class="scroll"><table class="tbl"><thead><tr><th>Подано</th><th>Гравець</th><th>Гра</th><th>Ведучий</th><th>Просив</th>
        <th>Рішення</th><th>Хто</th><th>Коли</th><th>Коментар</th><th>Опис</th></tr></thead><tbody id="h-rows"></tbody></table></div>
    </div>
  <script type="application/json" id="admin-data" set:html={base} />
```

(The `<script type="application/json">` goes just before `</Base>`.) Add styles:

```css
  #appeals-history[hidden], #appeals-new[hidden] { display: none; }
  .tabs { display: flex; gap: 6px; margin-bottom: 10px; }
  .tabs .on { border-color: var(--text); }
  .filters { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 10px; }
  .filters input, .filters select, .ap-comment, .ap-granted { background: var(--panel-2); border: 1px solid var(--border);
    border-radius: 6px; color: var(--text); padding: 4px 8px; font: inherit; }
  .ap-comment { width: min(520px, 100%); box-sizing: border-box; margin: 6px 0; }
  .ap-granted { width: 80px; }
  .ap-text { white-space: pre-wrap; }
  .scroll { overflow-x: auto; margin-bottom: 14px; }
  .tbl { border-collapse: collapse; font-size: 13px; }
  .tbl th, .tbl td { border-bottom: 1px solid var(--border); padding: 4px 8px; text-align: left; vertical-align: top; }
  .tbl .num { text-align: right; }
  .st-accepted, .st-partial { color: var(--good); }
```

- [ ] **Step 2: Script** — in `site/src/scripts/account-admin.ts` add imports:

```ts
import { decisionError, filterFromQuery, filterHistory, filterToQuery, hostTotals, parseAmount, type Appeal, type Decision, type HistoryFilter } from '../lib/appeals/core';
import { historyRow, pendingCard, totalsRows } from '../lib/appeals/render';
import { decideAppeal, explainAppealError, getGames, listAllAppeals } from '../lib/appeals/store';
import type { GameDoc } from '../lib/hosting/types';
```

State, loading and rendering:

```ts
const adminPage = JSON.parse(document.getElementById('admin-data')!.textContent!) as { base: string };
let appeals: Appeal[] = [];
let games = new Map<string, GameDoc>();
let tab: 'new' | 'history' = new URLSearchParams(location.search).has('tab') ? 'history' : 'new';
let hf: HistoryFilter = filterFromQuery(new URLSearchParams(location.search));

async function loadAppeals() {
  try {
    appeals = await listAllAppeals();
    games = await getGames(appeals.filter((a) => a.status === 'pending').map((a) => a.gameId));
  } catch (e) { $('who').textContent = explainAppealError(e); }
  renderAppeals();
}

function renderAppeals() {
  const pending = appeals.filter((a) => a.status === 'pending').sort((a, b) => (a.createdAt ?? 0) - (b.createdAt ?? 0));
  $('new-count').textContent = pending.length ? `(${pending.length})` : '';
  $('tab-new').classList.toggle('on', tab === 'new');
  $('tab-history').classList.toggle('on', tab === 'history');
  $('appeals-new').hidden = tab !== 'new';
  $('appeals-history').hidden = tab !== 'history';
  $('appeals-new').innerHTML = pending.map((a) => {
    const g = games.get(a.gameId);
    const cur = g?.seats.find((s) => s.player === a.player)?.additional ?? (g ? 0 : null);
    return pendingCard(a, cur, `${adminPage.base}season/${a.season}/games/`);
  }).join('') || '<p class="label">Нових апеляцій немає.</p>';
  fillSelect('h-host', [...new Set(appeals.map((a) => a.host))].sort((a, b) => a.localeCompare(b, 'uk')), 'Усі ведучі');
  fillSelect('h-season', [...new Set(appeals.map((a) => String(a.season)))].sort((a, b) => +b - +a), 'Усі сезони');
  $<HTMLInputElement>('h-player').value = hf.player;
  $<HTMLSelectElement>('h-host').value = hf.host;
  $<HTMLSelectElement>('h-status').value = hf.status;
  $<HTMLSelectElement>('h-season').value = hf.season;
  const shown = filterHistory(appeals, hf);
  $('h-totals').innerHTML = totalsRows(hostTotals(shown));
  $('h-rows').innerHTML = shown.map(historyRow).join('') || '<tr><td colspan="10" class="label">Нічого не знайдено.</td></tr>';
}

function fillSelect(id: string, values: string[], all: string) {
  $(id).innerHTML = `<option value="">${all}</option>` + values.map((v) => `<option value="${esc(v)}">${esc(v)}</option>`).join('');
}

function syncUrl() {
  const q = filterToQuery(hf);
  const params = new URLSearchParams(q);
  if (tab === 'history') params.set('tab', 'history');
  history.replaceState(null, '', `${location.pathname}${params.toString() ? `?${params}` : ''}`);
}

$('tab-new').addEventListener('click', () => { tab = 'new'; syncUrl(); renderAppeals(); });
$('tab-history').addEventListener('click', () => { tab = 'history'; syncUrl(); renderAppeals(); });
$('appeals-history').addEventListener('input', () => {
  hf = { player: $<HTMLInputElement>('h-player').value, host: $<HTMLSelectElement>('h-host').value,
    status: $<HTMLSelectElement>('h-status').value as HistoryFilter['status'], season: $<HTMLSelectElement>('h-season').value };
  syncUrl();
  const shown = filterHistory(appeals, hf); // re-render only the tables so the player input keeps focus
  $('h-totals').innerHTML = totalsRows(hostTotals(shown));
  $('h-rows').innerHTML = shown.map(historyRow).join('') || '<tr><td colspan="10" class="label">Нічого не знайдено.</td></tr>';
});
```

In the existing `document.addEventListener('click', …)` handler, at the top (right after `if (!b || !user) return;`), route appeal buttons:

```ts
  if (['accept', 'partial', 'reject'].includes(b.dataset.act!)) return decide(b);
```

And add:

```ts
async function decide(b: HTMLButtonElement) {
  const a = appeals.find((x) => x.id === b.dataset.id);
  const card = b.closest<HTMLElement>('.ap-card')!;
  const out = card.querySelector<HTMLElement>('.ap-msg')!;
  if (!a || !user) return;
  const d: Decision = {
    status: b.dataset.act === 'accept' ? 'accepted' : b.dataset.act === 'partial' ? 'partial' : 'rejected',
    adminComment: card.querySelector<HTMLInputElement>('.ap-comment')!.value,
    ...(b.dataset.act === 'partial' ? { granted: parseAmount(card.querySelector<HTMLInputElement>('.ap-granted')!.value) } : {}),
  };
  const err = decisionError(a, d);
  if (err) { out.className = 'ap-msg msg-error'; out.textContent = err; return; }
  card.querySelectorAll('button').forEach((x) => { x.disabled = true; });
  try { await decideAppeal(a, d, user); await loadAppeals(); }
  catch (e) {
    out.className = 'ap-msg msg-error'; out.textContent = explainAppealError(e);
    card.querySelectorAll('button').forEach((x) => { x.disabled = false; });
  }
}
```

In `onAccount`, change `if (u?.admin) load();` to `if (u?.admin) { load(); loadAppeals(); }`.

- [ ] **Step 3: Type-check and tests**

Run: `cd site && npx astro check && npx vitest run`
Expected: 0 errors; all PASS.

- [ ] **Step 4: Manual smoke**

`npm run dev`, open `/FamilyMafiaApp/account/admin/` as an admin. Expected: «Апеляції» with «Нові» showing «Нових апеляцій немає.»; «Історія» tab switches, URL gets `?tab=history`, reload keeps the tab; no console errors. Stop the dev server.

- [ ] **Step 5: Commit**

```bash
git add site/src/pages/account/admin.astro site/src/scripts/account-admin.ts
git commit -m "feat: admins decide appeals and browse their history on /account/admin/"
```

---

### Task 7: Docs, full verification, deploy

**Files:**
- Modify: `CLAUDE.md` (Web site section, after the **Player profiles** bullet)

- [ ] **Step 1: Docs** — add to `CLAUDE.md` after the **Player profiles** bullet:

```markdown
- **Appeals:** approved players appeal for an additional point on `/account/` — only their own seat in a
  rated game of the current club season (Firestore games, 32+). Firestore `appeals/{gameId}_{uid}`
  (owner + admins read). Admins decide on `/account/admin/` (accept / partial / reject); accept and
  partial add the points to the seat's `additional` and a «Апеляція: +X» comment in the same
  transaction, then bump `meta/state`. «Історія» filters by player, host, status, season (URL query)
  with per-host totals. Logic in `site/src/lib/appeals/`; rules in `firestore.rules`.
```

- [ ] **Step 2: Full verification**

```bash
cd site && npx vitest run && npx astro check && npm run build
cd ../firebase/rules-test && export JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" && export PATH="$JAVA_HOME/bin:$PATH" && npm test
```
Expected: all tests PASS, 0 type errors, build succeeds (check-dist passes).

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: game appeals in CLAUDE.md"
```

- [ ] **Step 4: Publish rules (before pushing code)** — open the Firebase console → Firestore → Rules for project `familymafiaapp`, paste the full `firestore.rules`, click **Publish**, then re-open the Rules tab and confirm the `match /appeals/{id}` block is live.

- [ ] **Step 5: Push**

```bash
git fetch origin
git merge origin/master            # no-op when master is already at our base; keeps master fast-forwardable
git push origin feature/flutter_migration
git push origin feature/flutter_migration:master   # fast-forward only; never force
```
Expected: `web.yml` run on `feature/flutter_migration` succeeds; `/account/` and `/account/admin/` show the new sections on the live site.
