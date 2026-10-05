# Player Profiles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Club players sign in with Google on the site, claim their player, get admin approval, then set an avatar and a display nickname that the static site shows after the next rebuild.

**Architecture:** Firestore holds private `claims/{uid}` and public `profiles/{playerKey}`; `firestore.rules` enforce ownership, one-player-one-account and admin approval. A pre-build script reads `profiles` over public REST into `site/data/profiles.json` + `site/public/avatars/*`; Astro components swap linked player names for nicks at build time. Two new client pages (`/account/`, `/account/admin/`) talk to Firestore with the Firebase JS SDK already used by `/host/`.

**Tech Stack:** Astro 7 static site, TypeScript, Firebase JS SDK 12 (Auth + Firestore), vitest 5, `@firebase/rules-unit-testing` + Firestore emulator, Node 24 (runs `.ts` scripts natively by type stripping).

**Spec:** `docs/superpowers/specs/2026-10-05-player-profiles-design.md`

## Global Constraints

- Site only; no changes under `lib/` (Flutter) or to the export JSON.
- Nick: trimmed, inner whitespace collapsed, 2–24 characters; empty = show the sheet name.
- Avatar: square 256×256, data URL `data:image/webp;base64,…` (or `data:image/jpeg;base64,…` where the browser cannot encode WebP), ≤ 140 000 characters.
- `playerKey(name) = encodeURIComponent(name.trim().toLowerCase())`; the "player" is the `name` in `site/data/players.json` (the app's display name).
- Admin = `hosts/{email}.admin == true` (existing). Hosts are still managed in the console.
- Player URLs never change because of a nick (slugs stay as exported).
- `/host/` keeps sheet names.
- Nothing from `claims` and no `uid` ends up in `site/dist`.
- UI copy in Ukrainian; existing English nav labels stay.
- Every Firestore write from a profile change also sets `meta/state.updatedAt` (triggers the hourly rebuild).
- Rules are published by the owner in the Firebase console (Rules tab); the implementer only edits `firestore.rules` and runs the emulator tests.
- Rules tests: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" npm test`. Site tests: `cd site && npm test`; type check: `npm run check`.

## Review Focus

1. **Safari/iOS cannot encode WebP from a canvas** (`toDataURL('image/webp')` returns PNG) → avatar must fall back to JPEG, not fail or upload a 1 MB PNG. Pinned in Task 6 (`encodeAvatar` test with a fake canvas returning PNG).
2. **A player re-claims after rejection / cancels while pending** → claim overwrite and delete must work, approved claims must not be overwritable by the owner. Pinned in Task 2 rules tests.
3. **Nick that equals another player's sheet name or nick, in different case or with extra spaces** → rejected on the page and dropped at build. Pinned in Task 1 (`nickError`) and Task 3 (`selectProfiles`).
4. **Firestore REST unavailable or empty during the CI build** → build still succeeds with sheet names. Pinned in Task 3 (script test on fetch failure).
5. **Players-list filter typed with the sheet name while a nick is shown** → still finds the player. Pinned in Task 4 (`matchesFilter` test).

---

### Task 1: Shared profile core (key, nick, avatar checks)

**Files:**
- Create: `site/src/lib/profiles/core.ts`
- Test: `site/src/lib/profiles/core.test.ts`

**Interfaces:**
- Produces:
  - `NICK_MIN = 2`, `NICK_MAX = 24`, `AVATAR_MAX_CHARS = 140_000`, `AVATAR_RE: RegExp`
  - `playerKey(name: string): string`
  - `cleanNick(s: string): string`
  - `nickError(nick: string, own: string, taken: Iterable<string>): string | null` — `nick` already cleaned; `''` → `null`; `taken` = other players' names and other profiles' nicks.
  - `isAvatar(s: unknown): s is string`
  - `matchesFilter(needle: string, shown: string, alt: string | undefined): boolean` — players-list filter (browser-safe, no Node imports).

- [ ] **Step 1: Write the failing test**

```ts
// site/src/lib/profiles/core.test.ts
import { describe, expect, it } from 'vitest';
import { AVATAR_MAX_CHARS, cleanNick, isAvatar, matchesFilter, nickError, playerKey } from './core.ts';

describe('playerKey', () => {
  it('is lower-case, trimmed and safe as a Firestore id', () => {
    expect(playerKey(' Braun ')).toBe('braun');
    expect(playerKey('Don`Tright')).toBe('don%60tright');
    expect(playerKey('A/B')).not.toContain('/');
    expect(playerKey('Залізний')).toBe(encodeURIComponent('залізний'));
  });
});

describe('nicks', () => {
  it('cleans whitespace', () => {
    expect(cleanNick('  Big   Boss ')).toBe('Big Boss');
  });
  it('accepts empty (= sheet name) and the own sheet name', () => {
    expect(nickError('', 'Braun', ['Залізний'])).toBeNull();
    expect(nickError('braun', 'Braun', ['Залізний'])).toBeNull();
  });
  it('checks length', () => {
    expect(nickError('X', 'Braun', [])).toMatch(/від 2 до 24/);
    expect(nickError('X'.repeat(25), 'Braun', [])).toMatch(/від 2 до 24/);
    expect(nickError('X'.repeat(24), 'Braun', [])).toBeNull();
  });
  it('rejects a name or nick of another player, any case', () => {
    expect(nickError('ЗАЛІЗНИЙ', 'Braun', ['Залізний'])).toMatch(/інший гравець/);
    expect(nickError('Boss', 'Braun', ['boss'])).toMatch(/інший гравець/);
  });
});

describe('isAvatar', () => {
  it('accepts webp and jpeg data URLs within the limit', () => {
    expect(isAvatar('data:image/webp;base64,UklGRg==')).toBe(true);
    expect(isAvatar('data:image/jpeg;base64,/9j/4A==')).toBe(true);
  });
  it('rejects other types, junk and oversize', () => {
    expect(isAvatar('data:image/png;base64,iVBO')).toBe(false);
    expect(isAvatar('https://x/y.webp')).toBe(false);
    expect(isAvatar(`data:image/webp;base64,${'A'.repeat(AVATAR_MAX_CHARS)}`)).toBe(false);
    expect(isAvatar(42)).toBe(false);
  });
});

describe('matchesFilter', () => {
  it('matches the shown nick or the sheet name', () => {
    expect(matchesFilter('bos', 'Boss', 'Braun')).toBe(true);
    expect(matchesFilter('brau', 'Boss', 'Braun')).toBe(true);
    expect(matchesFilter('flop', 'Boss', 'Braun')).toBe(false);
    expect(matchesFilter('', 'Boss', undefined)).toBe(true);
    expect(matchesFilter(' BRA ', 'Braun', undefined)).toBe(true);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd site && npx vitest run src/lib/profiles/core.test.ts`
Expected: FAIL — cannot resolve `./core.ts`.

- [ ] **Step 3: Write minimal implementation**

```ts
// site/src/lib/profiles/core.ts
// Profile rules shared by the account pages, the build script and the site.
// Keep in sync with firestore.rules (nick length, avatar pattern and size).
export const NICK_MIN = 2;
export const NICK_MAX = 24;
export const AVATAR_MAX_CHARS = 140_000;
export const AVATAR_RE = /^data:image\/(webp|jpeg);base64,[A-Za-z0-9+/]+=*$/;

/** Firestore id of a player's profile: the display name, case-insensitive like the app's resolver. */
export const playerKey = (name: string) => encodeURIComponent(name.trim().toLowerCase());

export const cleanNick = (s: string) => s.trim().replace(/\s+/g, ' ');

export function nickError(nick: string, own: string, taken: Iterable<string>): string | null {
  if (nick === '') return null;
  if (nick.length < NICK_MIN || nick.length > NICK_MAX) return `Нік має бути від ${NICK_MIN} до ${NICK_MAX} символів.`;
  const low = nick.toLowerCase();
  if (low === own.trim().toLowerCase()) return null;
  for (const t of taken) if (t.trim().toLowerCase() === low) return 'Такий нік чи імʼя вже має інший гравець.';
  return null;
}

export const isAvatar = (s: unknown): s is string =>
  typeof s === 'string' && s.length <= AVATAR_MAX_CHARS && AVATAR_RE.test(s);

/** Players-list filter: the nick that is shown, or the sheet name kept in data-alt. */
export function matchesFilter(needle: string, shown: string, alt: string | undefined) {
  const n = needle.trim().toLowerCase();
  return !n || shown.toLowerCase().includes(n) || (alt ?? '').toLowerCase().includes(n);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd site && npx vitest run src/lib/profiles/core.test.ts`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/profiles/core.ts site/src/lib/profiles/core.test.ts
git commit -m "feat(site): profile core — player key, nick and avatar checks"
```

---

### Task 2: Firestore rules for claims and profiles

**Files:**
- Modify: `firestore.rules` (add helpers, `claims`, `profiles`; widen `meta/state`)
- Test: `firebase/rules-test/rules.test.ts` (append `describe` blocks)

**Interfaces:**
- Consumes: nothing from code; mirrors Task 1 constants (24 chars, 140 000, pattern).
- Produces (document shapes later tasks write):
  - `claims/{uid}` owner write: `{player, playerKey, email, googleName, status: 'pending', createdAt: serverTimestamp()}`
  - admin decision: `update({status: 'approved'|'rejected', decidedBy: adminEmail, decidedAt: serverTimestamp()})`
  - `profiles/{playerKey}` admin create: `{player, uid, updatedAt: serverTimestamp()}`
  - profile edit: `nick`/`avatar` set or `deleteField()`, plus `updatedAt: serverTimestamp()`
  - approve batch = claim update + profile create (+ meta); unlink batch = profile delete + claim delete (+ meta)

- [ ] **Step 1: Write the failing tests** — append to `firebase/rules-test/rules.test.ts`; also add `deleteField, writeBatch` to the `firebase/firestore` import at the top.

```ts
const PLAYER = { uid: 'u-player', email: 'player@x.com' };
const RIVAL = { uid: 'u-rival', email: 'rival@x.com' };
const claim = (who: User, extra: Record<string, unknown> = {}) => ({
  player: 'Braun', playerKey: 'braun', email: who.email, googleName: 'B', status: 'pending',
  createdAt: serverTimestamp(), ...extra,
});
const approve = (db: ReturnType<typeof as>, who: User, key = 'braun', player = 'Braun') => {
  const b = writeBatch(db);
  b.update(doc(db, 'claims', who.uid), { status: 'approved', decidedBy: ADMIN.email, decidedAt: serverTimestamp() });
  b.set(doc(db, 'profiles', key), { player, uid: who.uid, updatedAt: serverTimestamp() });
  return b.commit();
};
const seedApproved = (who: User, extra: Record<string, unknown> = {}) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'claims', who.uid), { ...claim(who), status: 'approved', createdAt: new Date() });
    await setDoc(doc(db, 'profiles', 'braun'), { player: 'Braun', uid: who.uid, updatedAt: new Date(), ...extra });
  });

describe('claims', () => {
  it('a signed-in user claims a player for themselves', async () => {
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER)));
  });
  it('not for another uid', async () => {
    await assertFails(setDoc(doc(as(PLAYER), 'claims', RIVAL.uid), claim(PLAYER)));
  });
  it('not with someone else’s email, a non-pending status or extra fields', async () => {
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { email: RIVAL.email })));
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { status: 'approved' })));
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { admin: true })));
  });
  it('a guest cannot claim', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'claims', PLAYER.uid), claim(PLAYER)));
  });
  it('owner and admin read; others do not', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(getDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
    await assertSucceeds(getDoc(doc(as(ADMIN), 'claims', PLAYER.uid)));
    await assertFails(getDoc(doc(as(RIVAL), 'claims', PLAYER.uid)));
    await assertFails(getDoc(doc(as(HOST), 'claims', PLAYER.uid)));
  });
  it('owner cancels or re-claims while pending or rejected', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { player: 'Floppy', playerKey: 'floppy' })));
    await updateDoc(doc(as(ADMIN), 'claims', PLAYER.uid), { status: 'rejected', decidedBy: ADMIN.email, decidedAt: serverTimestamp() });
    await assertSucceeds(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER)));
    await assertSucceeds(deleteDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
  });
  it('owner cannot touch an approved claim', async () => {
    await seedApproved(PLAYER);
    await assertFails(setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER, { player: 'Floppy', playerKey: 'floppy' })));
    await assertFails(deleteDoc(doc(as(PLAYER), 'claims', PLAYER.uid)));
  });
  it('only an admin rejects, with their own email', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    const reject = (who: User, by = who.email) =>
      updateDoc(doc(as(who), 'claims', PLAYER.uid), { status: 'rejected', decidedBy: by, decidedAt: serverTimestamp() });
    await assertFails(reject(HOST));
    await assertFails(reject(PLAYER));
    await assertFails(reject(ADMIN, HOST.email));
    await assertSucceeds(reject(ADMIN));
  });
});

describe('profiles', () => {
  it('admin approves: claim and profile in one batch', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertSucceeds(approve(as(ADMIN), PLAYER));
  });
  it('approval without a profile, or a profile without approval, fails', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(updateDoc(doc(as(ADMIN), 'claims', PLAYER.uid), { status: 'approved', decidedBy: ADMIN.email, decidedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as(ADMIN), 'profiles', 'braun'), { player: 'Braun', uid: PLAYER.uid, updatedAt: serverTimestamp() }));
  });
  it('profile key and player must match the claim', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(approve(as(ADMIN), PLAYER, 'floppy', 'Braun'));
    await assertFails(approve(as(ADMIN), PLAYER, 'braun', 'Floppy'));
  });
  it('a non-admin cannot approve', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(approve(as(HOST), PLAYER));
    await assertFails(approve(as(PLAYER), PLAYER));
  });
  it('a second account cannot get the same player', async () => {
    await seedApproved(PLAYER);
    await setDoc(doc(as(RIVAL), 'claims', RIVAL.uid), claim(RIVAL));
    await assertFails(approve(as(ADMIN), RIVAL));
  });
  it('everyone reads profiles', async () => {
    await seedApproved(PLAYER);
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'profiles', 'braun')));
  });
  it('owner sets and clears nick and avatar', async () => {
    await seedApproved(PLAYER);
    const ref = doc(as(PLAYER), 'profiles', 'braun');
    await assertSucceeds(updateDoc(ref, { nick: 'Boss', avatar: 'data:image/webp;base64,UklGRg==', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { nick: deleteField(), avatar: deleteField(), updatedAt: serverTimestamp() }));
  });
  it('owner limits: nick length, avatar type and size, no other fields', async () => {
    await seedApproved(PLAYER);
    const ref = doc(as(PLAYER), 'profiles', 'braun');
    const up = (d: Record<string, unknown>) => updateDoc(ref, { ...d, updatedAt: serverTimestamp() });
    await assertFails(up({ nick: 'X' }));
    await assertFails(up({ nick: 'X'.repeat(25) }));
    await assertFails(up({ avatar: 'data:image/png;base64,iVBO' }));
    await assertFails(up({ avatar: `data:image/webp;base64,${'A'.repeat(140_000)}` }));
    await assertFails(up({ player: 'Floppy' }));
    await assertFails(up({ uid: RIVAL.uid }));
  });
  it('others cannot edit a profile', async () => {
    await seedApproved(PLAYER);
    await assertFails(updateDoc(doc(as(RIVAL), 'profiles', 'braun'), { nick: 'Boss', updatedAt: serverTimestamp() }));
    await assertFails(updateDoc(doc(as(HOST), 'profiles', 'braun'), { nick: 'Boss', updatedAt: serverTimestamp() }));
  });
  it('admin resets nick/avatar but cannot set them', async () => {
    await seedApproved(PLAYER, { nick: 'Boss', avatar: 'data:image/webp;base64,UklGRg==' });
    const ref = doc(as(ADMIN), 'profiles', 'braun');
    await assertFails(updateDoc(ref, { nick: 'Admin-made', updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(ref, { nick: deleteField(), avatar: deleteField(), updatedAt: serverTimestamp() }));
  });
  it('admin unlinks: profile and claim deleted together; owner cannot delete', async () => {
    await seedApproved(PLAYER);
    await assertFails(deleteDoc(doc(as(PLAYER), 'profiles', 'braun')));
    const db = as(ADMIN);
    const b = writeBatch(db);
    b.delete(doc(db, 'profiles', 'braun'));
    b.delete(doc(db, 'claims', PLAYER.uid));
    await assertSucceeds(b.commit());
  });
});

describe('meta/state by players', () => {
  it('an approved player bumps updatedAt', async () => {
    await seedApproved(PLAYER);
    await assertSucceeds(setDoc(doc(as(PLAYER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('a pending player cannot', async () => {
    await setDoc(doc(as(PLAYER), 'claims', PLAYER.uid), claim(PLAYER));
    await assertFails(setDoc(doc(as(PLAYER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" npm test`
Expected: the new `claims`/`profiles`/`meta/state by players` "succeeds" cases FAIL (no rules → denied); existing tests still pass.

- [ ] **Step 3: Implement the rules** — in `firestore.rules`, add after `isAdmin()`:

```
    function approvedPlayer() {
      return signedIn() && exists(/databases/$(database)/documents/claims/$(request.auth.uid))
        && get(/databases/$(database)/documents/claims/$(request.auth.uid)).data.status == 'approved';
    }
    // Keep in sync with site/src/lib/profiles/core.ts.
    function validNick(d) { return !('nick' in d) || (d.nick is string && d.nick.size() >= 2 && d.nick.size() <= 24); }
    function validAvatar(d) {
      return !('avatar' in d) || (d.avatar is string && d.avatar.size() <= 140000
        && d.avatar.matches('^data:image/(webp|jpeg);base64,[A-Za-z0-9+/]+=*$'));
    }
```

Add before `match /meta/state`:

```
    match /claims/{uid} {
      function own() { return signedIn() && uid == request.auth.uid; }
      function validClaim(d) {
        return d.keys().hasOnly(['player', 'playerKey', 'email', 'googleName', 'status', 'createdAt'])
          && d.keys().hasAll(['player', 'playerKey', 'email', 'googleName', 'status', 'createdAt'])
          && d.player is string && d.player.size() > 0 && d.player.size() <= 60
          && d.playerKey is string && d.playerKey.size() > 0 && d.playerKey.size() <= 400
          && d.email == email()
          && d.googleName is string && d.googleName.size() <= 100
          && d.status == 'pending'
          && d.createdAt == request.time;
      }
      function decision(d) {
        return d.diff(resource.data).affectedKeys().hasOnly(['status', 'decidedBy', 'decidedAt'])
          && d.decidedBy == email() && d.decidedAt == request.time
          && (d.status == 'rejected'
            || (d.status == 'approved'
              && existsAfter(/databases/$(database)/documents/profiles/$(resource.data.playerKey))));
      }
      allow read: if own() || isAdmin();
      allow create: if own() && validClaim(request.resource.data);
      allow update: if (own() && resource.data.status != 'approved' && validClaim(request.resource.data))
        || (isAdmin() && decision(request.resource.data));
      allow delete: if (own() && resource.data.status != 'approved') || isAdmin();
    }

    match /profiles/{key} {
      function validProfile(d) {
        return d.keys().hasOnly(['player', 'uid', 'nick', 'avatar', 'updatedAt'])
          && d.player is string && d.uid is string
          && validNick(d) && validAvatar(d)
          && d.updatedAt == request.time;
      }
      function claimAfter(uid) { return getAfter(/databases/$(database)/documents/claims/$(uid)).data; }
      function onlyStyle() {
        return request.resource.data.diff(resource.data).affectedKeys().hasOnly(['nick', 'avatar', 'updatedAt'])
          && request.resource.data.player == resource.data.player
          && request.resource.data.uid == resource.data.uid;
      }
      // A reset removes a field or leaves it; it never sets a new value.
      function onlyResets() {
        return (!('nick' in request.resource.data) || request.resource.data.nick == resource.data.get('nick', null))
          && (!('avatar' in request.resource.data) || request.resource.data.avatar == resource.data.get('avatar', null));
      }
      allow read: if true;
      allow create: if isAdmin()
        && request.resource.data.keys().hasOnly(['player', 'uid', 'updatedAt'])
        && validProfile(request.resource.data)
        && claimAfter(request.resource.data.uid).status == 'approved'
        && claimAfter(request.resource.data.uid).playerKey == key
        && claimAfter(request.resource.data.uid).player == request.resource.data.player;
      allow update: if validProfile(request.resource.data) && onlyStyle()
        && ((signedIn() && resource.data.uid == request.auth.uid) || (isAdmin() && onlyResets()));
      allow delete: if isAdmin();
    }
```

In `match /meta/state`, change `allow write: if isHost()` to `allow write: if (isHost() || approvedPlayer())` (the rest of that condition stays).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" npm test`
Expected: all tests PASS (existing + new).

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firebase/rules-test/rules.test.ts
git commit -m "feat(rules): player claims and profiles with admin approval"
```

---

### Task 3: Build step — fetch profiles into the site

**Files:**
- Create: `site/src/lib/profiles/build.ts` (pure: REST parsing, selection, file plan)
- Create: `site/scripts/fetch-profiles.ts` (I/O wrapper)
- Test: `site/src/lib/profiles/build.test.ts`, `site/scripts/fetch-profiles.test.ts`
- Modify: `site/package.json` (`build` script), root `.gitignore`, `site/scripts/check-dist.mjs`

**Interfaces:**
- Consumes: `playerKey`, `cleanNick`, `isAvatar` from `./core.ts` (Task 1).
- Produces:
  - `site/data/profiles.json`: `Record<playerKey, { nick?: string; avatar?: string }>` where `avatar` is a site-relative path like `avatars/1a2b3c4d.webp`.
  - `site/public/avatars/<sha1-8>.(webp|jpg)`.
  - `export interface RestProfile { player: string; nick?: string; avatar?: string }`
  - `parseRestPage(json: unknown): { docs: RestProfile[]; next?: string }`
  - `selectProfiles(names: string[], docs: RestProfile[]): { profiles: Record<string, { nick?: string; avatar?: string }>; files: { path: string; bytes: Uint8Array }[]; warnings: string[] }`
  - `fetchProfiles(opts: { fetch: typeof fetch; dataDir: string; publicDir: string; log: (s: string) => void }): Promise<void>` (exported from the script for tests).

- [ ] **Step 1: Write the failing tests**

```ts
// site/src/lib/profiles/build.test.ts
import { describe, expect, it } from 'vitest';
import { parseRestPage, selectProfiles } from './build.ts';

const WEBP = 'data:image/webp;base64,UklGRg==';
const restDoc = (fields: Record<string, string>) => ({
  name: 'projects/familymafiaapp/databases/(default)/documents/profiles/x',
  fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, { stringValue: v }])),
});

describe('parseRestPage', () => {
  it('reads string fields and the page token', () => {
    const page = parseRestPage({ documents: [restDoc({ player: 'Braun', uid: 'u1', nick: 'Boss', avatar: WEBP })], nextPageToken: 't' });
    expect(page).toEqual({ docs: [{ player: 'Braun', nick: 'Boss', avatar: WEBP }], next: 't' });
  });
  it('an empty collection has no documents key', () => {
    expect(parseRestPage({})).toEqual({ docs: [], next: undefined });
  });
  it('drops documents without a player and never keeps uid', () => {
    const page = parseRestPage({ documents: [restDoc({ uid: 'u1' }), restDoc({ player: 'Floppy', uid: 'u2' })] });
    expect(page.docs).toEqual([{ player: 'Floppy' }]);
  });
});

describe('selectProfiles', () => {
  const names = ['Braun', 'Залізний', 'Floppy'];
  it('maps by player key and writes avatars as files', () => {
    const out = selectProfiles(names, [{ player: 'Braun', nick: ' Big  Boss ', avatar: WEBP }]);
    expect(out.profiles.braun.nick).toBe('Big Boss');
    expect(out.profiles.braun.avatar).toMatch(/^avatars\/[0-9a-f]{8}\.webp$/);
    expect(out.files).toHaveLength(1);
    expect(out.files[0].path).toBe(out.profiles.braun.avatar);
    expect([...out.files[0].bytes.slice(0, 4)]).toEqual([0x52, 0x49, 0x46, 0x46]); // "RIFF"
  });
  it('jpeg avatars get a .jpg file', () => {
    const out = selectProfiles(names, [{ player: 'Braun', avatar: 'data:image/jpeg;base64,/9j/4A==' }]);
    expect(out.profiles.braun.avatar).toMatch(/\.jpg$/);
  });
  it('ignores players no longer on the site', () => {
    const out = selectProfiles(names, [{ player: 'Ghost', nick: 'Boo' }]);
    expect(out.profiles).toEqual({});
  });
  it('drops a nick that collides with another name or an earlier nick, case-insensitively', () => {
    const out = selectProfiles(names, [
      { player: 'Floppy', nick: 'boss' },
      { player: 'Braun', nick: 'ЗАЛІЗНИЙ' },
      { player: 'Залізний', nick: 'Boss' },
    ]);
    // Keys are processed in code-point order: '%D0…' (Залізний) < 'braun' < 'floppy'.
    expect(out.profiles[encodeURIComponent('залізний')]).toEqual({ nick: 'Boss' });
    expect(out.profiles.braun).toBeUndefined();  // 'ЗАЛІЗНИЙ' is another player's sheet name
    expect(out.profiles.floppy).toBeUndefined(); // 'boss' was taken by Залізний first
    expect(out.warnings).toHaveLength(2);
  });
  it('drops an invalid avatar or nick with a warning', () => {
    const out = selectProfiles(names, [{ player: 'Braun', nick: 'X', avatar: 'data:image/png;base64,AA==' }]);
    expect(out.profiles.braun).toBeUndefined();
    expect(out.warnings).toHaveLength(2);
  });
});
```

```ts
// site/scripts/fetch-profiles.test.ts
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, expect, it } from 'vitest';
import { fetchProfiles } from './fetch-profiles.ts';

const tmp = () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'profiles-'));
  const dataDir = path.join(root, 'data');
  fs.mkdirSync(dataDir);
  fs.writeFileSync(path.join(dataDir, 'players.json'), JSON.stringify({ players: [{ name: 'Braun', slug: 'braun' }] }));
  return { dataDir, publicDir: path.join(root, 'public') };
};
const json = (body: unknown) => new Response(JSON.stringify(body), { status: 200 });

describe('fetchProfiles', () => {
  it('writes profiles.json and avatar files, following page tokens', async () => {
    const dirs = tmp();
    const pages = [
      { documents: [{ fields: { player: { stringValue: 'Braun' }, avatar: { stringValue: 'data:image/webp;base64,UklGRg==' } } }], nextPageToken: 'p2' },
      { documents: [{ fields: { player: { stringValue: 'Ghost' } } }] },
    ];
    const urls: string[] = [];
    await fetchProfiles({ ...dirs, log: () => {}, fetch: (async (u: string) => { urls.push(u); return json(pages.shift()); }) as typeof fetch });
    expect(urls[1]).toContain('pageToken=p2');
    const out = JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'));
    expect(Object.keys(out)).toEqual(['braun']);
    expect(fs.existsSync(path.join(dirs.publicDir, out.braun.avatar))).toBe(true);
  });
  it('on a network error writes an empty profiles.json and does not throw', async () => {
    const dirs = tmp();
    const logs: string[] = [];
    await fetchProfiles({ ...dirs, log: (s) => logs.push(s), fetch: (async () => { throw new Error('offline'); }) as typeof fetch });
    expect(JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'))).toEqual({});
    expect(logs.join('\n')).toMatch(/offline/);
  });
  it('treats a non-200 response as an error', async () => {
    const dirs = tmp();
    await fetchProfiles({ ...dirs, log: () => {}, fetch: (async () => new Response('no', { status: 500 })) as typeof fetch });
    expect(JSON.parse(fs.readFileSync(path.join(dirs.dataDir, 'profiles.json'), 'utf8'))).toEqual({});
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd site && npx vitest run src/lib/profiles/build.test.ts scripts/fetch-profiles.test.ts`
Expected: FAIL — modules not found.

- [ ] **Step 3: Implement**

```ts
// site/src/lib/profiles/build.ts
// Turns the public `profiles` collection into site data. Pure: no I/O.
import { createHash } from 'node:crypto';
import { cleanNick, isAvatar, nickError, playerKey } from './core.ts';

export interface RestProfile { player: string; nick?: string; avatar?: string }
export interface SiteProfile { nick?: string; avatar?: string }

type RestValue = { stringValue?: string };
type RestDoc = { fields?: Record<string, RestValue> };

export function parseRestPage(json: unknown): { docs: RestProfile[]; next?: string } {
  const body = (json ?? {}) as { documents?: RestDoc[]; nextPageToken?: string };
  const docs: RestProfile[] = [];
  for (const d of body.documents ?? []) {
    const f = d.fields ?? {};
    const player = f.player?.stringValue;
    if (!player) continue;
    const p: RestProfile = { player };
    if (f.nick?.stringValue !== undefined) p.nick = f.nick.stringValue;
    if (f.avatar?.stringValue !== undefined) p.avatar = f.avatar.stringValue;
    docs.push(p);
  }
  return { docs, next: body.nextPageToken };
}

export function selectProfiles(names: string[], docs: RestProfile[]) {
  const byKey = new Map(names.map((n) => [playerKey(n), n]));
  const profiles: Record<string, SiteProfile> = {};
  const files: { path: string; bytes: Uint8Array }[] = [];
  const warnings: string[] = [];
  const taken = new Set(names.map((n) => n.trim().toLowerCase()));
  // Code-point order, so the first-come nick is deterministic on every machine.
  const sorted = [...docs].sort((a, b) => (playerKey(a.player) < playerKey(b.player) ? -1 : 1));
  for (const d of sorted) {
    const key = playerKey(d.player);
    const name = byKey.get(key);
    if (!name) continue;
    const out: SiteProfile = {};
    if (d.nick !== undefined) {
      const nick = cleanNick(d.nick);
      const others = [...taken].filter((t) => t !== name.trim().toLowerCase());
      const err = nickError(nick, name, others);
      if (err) warnings.push(`profile ${name}: nick "${nick}" dropped — ${err}`);
      else if (nick && nick.toLowerCase() !== name.trim().toLowerCase()) {
        out.nick = nick;
        taken.add(nick.toLowerCase());
      }
    }
    if (d.avatar !== undefined) {
      if (!isAvatar(d.avatar)) warnings.push(`profile ${name}: avatar dropped — not a webp/jpeg data URL within the limit`);
      else {
        const [head, b64] = d.avatar.split(',');
        const bytes = Uint8Array.from(Buffer.from(b64, 'base64'));
        const ext = head.includes('jpeg') ? 'jpg' : 'webp';
        const path = `avatars/${createHash('sha1').update(bytes).digest('hex').slice(0, 8)}.${ext}`;
        files.push({ path, bytes });
        out.avatar = path;
      }
    }
    if (out.nick || out.avatar) profiles[key] = out;
  }
  return { profiles, files, warnings };
}
```

The nick-collision rule: `taken` starts with all sheet names; the player's own name is excluded from the check; an accepted nick joins `taken`, so a later identical nick is dropped.

```ts
// site/scripts/fetch-profiles.ts
// Pre-build: public `profiles` from Firestore → data/profiles.json + public/avatars/.
// Never fails the build: on any error the site is built with sheet names.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseRestPage, selectProfiles, type RestProfile } from '../src/lib/profiles/build.ts';

const URL_BASE = 'https://firestore.googleapis.com/v1/projects/familymafiaapp/databases/(default)/documents/profiles?pageSize=300';

export async function fetchProfiles(opts: { fetch: typeof fetch; dataDir: string; publicDir: string; log: (s: string) => void }) {
  const out = path.join(opts.dataDir, 'profiles.json');
  const avatarsDir = path.join(opts.publicDir, 'avatars');
  fs.rmSync(avatarsDir, { recursive: true, force: true });
  try {
    const docs: RestProfile[] = [];
    let token: string | undefined;
    do {
      const res = await opts.fetch(token ? `${URL_BASE}&pageToken=${encodeURIComponent(token)}` : URL_BASE);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const page = parseRestPage(await res.json());
      docs.push(...page.docs);
      token = page.next;
    } while (token);
    const { players } = JSON.parse(fs.readFileSync(path.join(opts.dataDir, 'players.json'), 'utf8')) as { players: { name: string }[] };
    const { profiles, files, warnings } = selectProfiles(players.map((p) => p.name), docs);
    warnings.forEach((w) => opts.log(`fetch-profiles: ${w}`));
    for (const f of files) {
      fs.mkdirSync(path.dirname(path.join(opts.publicDir, f.path)), { recursive: true });
      fs.writeFileSync(path.join(opts.publicDir, f.path), f.bytes);
    }
    fs.writeFileSync(out, JSON.stringify(profiles));
    opts.log(`fetch-profiles: ${Object.keys(profiles).length} profiles, ${files.length} avatars`);
  } catch (e) {
    opts.log(`fetch-profiles: WARNING ${(e as Error).message} — building with sheet names`);
    fs.writeFileSync(out, '{}');
  }
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  await fetchProfiles({
    fetch,
    dataDir: process.env.SITE_DATA_DIR ?? path.resolve('data'),
    publicDir: path.resolve('public'),
    log: console.log,
  });
}
```

`site/package.json` — change the build script:

```json
    "build": "node scripts/fetch-profiles.ts && astro build && node scripts/check-dist.mjs",
```

Root `.gitignore`, after `site/.astro/`:

```
site/public/avatars/
```

`site/scripts/check-dist.mjs` — before the `if (errors.length)` block:

```js
// Profiles: only nick/avatar may reach the site (no uid, no claim data).
const profilesFile = path.join(dataDir, 'profiles.json');
if (fs.existsSync(profilesFile)) {
  for (const [key, p] of Object.entries(JSON.parse(fs.readFileSync(profilesFile, 'utf8')))) {
    const extra = Object.keys(p).filter((k) => k !== 'nick' && k !== 'avatar');
    if (extra.length) errors.push(`profiles.json ${key} has ${extra.join(', ')}`);
  }
}
for (const file of files.filter((f) => f.endsWith('.html'))) {
  if (/[\w.+-]+@gmail\.com/i.test(fs.readFileSync(file, 'utf8'))) errors.push(`email address in ${path.relative(dist, file)}`);
}
```

(The spec said "email-like string or `"uid"`"; the Firebase bundle legitimately contains both patterns, so the check targets what could actually leak: extra profile keys and Gmail addresses in pages.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd site && npx vitest run src/lib/profiles scripts/fetch-profiles.test.ts && npm run check`
Expected: PASS; `astro check` reports 0 errors.
Then: `cd site && node scripts/fetch-profiles.ts`
Expected: `fetch-profiles: 0 profiles, 0 avatars` (the collection does not exist yet) and `data/profiles.json` = `{}`.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/profiles/build.ts site/src/lib/profiles/build.test.ts site/scripts/fetch-profiles.ts site/scripts/fetch-profiles.test.ts site/package.json site/scripts/check-dist.mjs .gitignore
git commit -m "feat(site): fetch player profiles into the build"
```

---

### Task 4: Show nicks and avatars on the site

**Files:**
- Create: `site/src/lib/profiles/site.ts`
- Create: `site/src/components/PlayerName.astro`
- Test: `site/src/lib/profiles/site.test.ts`
- Modify: `site/src/components/DataTable.astro`, `site/src/components/RankedList.astro`, `site/src/pages/tournaments/index.astro` (podium), `site/src/pages/players/[slug].astro`, `site/src/pages/players/index.astro` (filter)

**Interfaces:**
- Consumes: `playerKey`, `matchesFilter` (Task 1); `data/profiles.json` (Task 3); `loadPlayers()` from `src/lib/data.ts`.
- Produces:
  - `indexBySlug(players: { slug: string; name: string }[], profiles: Record<string, SiteProfile>): Map<string, SiteProfile>`
  - `profileFor(slug: string | undefined): SiteProfile | undefined` (lazy, reads files once)
  - `nameFor(slug: string | undefined, fallback: string): string`
  - `<PlayerName slug={string} name={string} />` renders the link with avatar + nick.

- [ ] **Step 1: Write the failing test**

```ts
// site/src/lib/profiles/site.test.ts
import { describe, expect, it } from 'vitest';
import { indexBySlug } from './site.ts';

describe('indexBySlug', () => {
  it('maps slugs to profiles via the player key', () => {
    const idx = indexBySlug(
      [{ slug: 'braun', name: 'Braun' }, { slug: 'zaliznyi', name: 'Залізний' }],
      { braun: { nick: 'Boss', avatar: 'avatars/1.webp' } },
    );
    expect(idx.get('braun')).toEqual({ nick: 'Boss', avatar: 'avatars/1.webp' });
    expect(idx.get('zaliznyi')).toBeUndefined();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd site && npx vitest run src/lib/profiles/site.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// site/src/lib/profiles/site.ts
// Build-time display of player profiles (nick + avatar) written by scripts/fetch-profiles.ts.
import fs from 'node:fs';
import path from 'node:path';
import { playerKey } from './core.ts';
import type { SiteProfile } from './build.ts';

export type { SiteProfile };

export function indexBySlug(players: { slug: string; name: string }[], profiles: Record<string, SiteProfile>) {
  const out = new Map<string, SiteProfile>();
  for (const p of players) {
    const prof = profiles[playerKey(p.name)];
    if (prof) out.set(p.slug, prof);
  }
  return out;
}

let cache: Map<string, SiteProfile> | undefined;
function index() {
  if (cache) return cache;
  const dir = process.env.SITE_DATA_DIR ?? path.resolve(process.cwd(), 'data');
  const read = (f: string) => (fs.existsSync(path.join(dir, f)) ? JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')) : null);
  const players = (read('players.json')?.players ?? []) as { slug: string; name: string }[];
  cache = indexBySlug(players, (read('profiles.json') ?? {}) as Record<string, SiteProfile>);
  return cache;
}

export const profileFor = (slug: string | undefined) => (slug ? index().get(slug) : undefined);
export const nameFor = (slug: string | undefined, fallback: string) => profileFor(slug)?.nick ?? fallback;
```

```astro
---
// site/src/components/PlayerName.astro — a player link showing the profile nick and avatar.
import { nameFor, profileFor } from '../lib/profiles/site';
import { href, playerHref } from '../lib/url';

interface Props { slug: string; name: string }
const { slug, name } = Astro.props;
const prof = profileFor(slug);
---
<a class="pn" href={playerHref(slug)} title={prof?.nick ? name : undefined}>{prof?.avatar && <img src={href(prof.avatar)} alt="" width="20" height="20" loading="lazy" decoding="async" />}{nameFor(slug, name)}</a>

<style>
  .pn { display: inline-flex; align-items: center; gap: 6px; }
  .pn img { width: 20px; height: 20px; border-radius: 50%; object-fit: cover; flex: none; }
</style>
```

`DataTable.astro`:
- add `import PlayerName from './PlayerName.astro';` and `import { profileFor } from '../lib/profiles/site';`
- replace `{cell.link ? <a href={playerHref(cell.link)}>{cell.t}</a> : cell.t}` with `{cell.link ? <PlayerName slug={cell.link} name={cell.t} /> : cell.t}`
- on the `<td>` add `data-alt={cell.link && profileFor(cell.link)?.nick ? cell.t : undefined}`
- remove the now-unused `playerHref` import.

`RankedList.astro`: replace the `winnerLink` branch with `<PlayerName slug={winnerLink} name={winner} />` (import it; drop `playerHref`).

`tournaments/index.astro` podium: replace `{p.link ? <a href={playerHref(p.link)}>{p.t}</a> : p.t}` with `{p.link ? <PlayerName slug={p.link} name={p.t} /> : p.t}` and import `PlayerName` (keep `playerHref` only if still used elsewhere in the file).

`players/[slug].astro`:

```astro
---
// add to imports
import { href } from '../../lib/url';
import { profileFor } from '../../lib/profiles/site';
// after `const p = loadPlayer(...)`
const prof = profileFor(p.slug);
const shown = prof?.nick ?? p.name;
---
```

- `<Base title={shown} description={`${shown}: …`}` (replace `p.name` in both).
- Avatar block: `{prof?.avatar ? <img class="avatar" src={href(prof.avatar)} alt="" width="64" height="64" /> : <div class="avatar display">{p.initials}</div>}`
- Heading: `<h1 class="display">{shown}</h1>` and, when `prof?.nick`, under it `<div class="label">у таблицях: {p.name}</div>` before the games label.
- CSS: add `img.avatar { object-fit: cover; padding: 0; }`.

`players/index.astro` filter script (runs in the browser, so import from `core`, never from `site.ts` which uses `node:fs`): add `import { matchesFilter } from '../../lib/profiles/core';` and replace

```ts
      const name = cells[0]?.textContent?.toLowerCase() ?? '';
      ...
      const match = (!needle || name.includes(needle)) && games >= min;
```

with

```ts
      const match = matchesFilter(needle, cells[0]?.textContent ?? '', cells[0]?.dataset.alt) && games >= min;
```

- [ ] **Step 4: Run tests and a local build with a fake profile**

Run: `cd site && npm test && npm run check`
Expected: PASS, 0 errors.
Then create a throwaway profile to see it render (do not commit):

```bash
cd site && node -e "require('fs').writeFileSync('data/profiles.json', JSON.stringify({braun:{nick:'Boss'}}))" && npx astro build && node scripts/check-dist.mjs && grep -o 'у таблицях: Braun' dist/players/braun/index.html && grep -c '>Boss<' dist/season/*/index.html | head -3
```

Expected: check-dist passes; the player page contains `у таблицях: Braun`; season pages contain `Boss`. Then restore: `node scripts/fetch-profiles.ts`.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/profiles site/src/components/PlayerName.astro site/src/components/DataTable.astro site/src/components/RankedList.astro site/src/pages/tournaments/index.astro site/src/pages/players
git commit -m "feat(site): show player nicks and avatars"
```

---

### Task 5: Shared Firebase client + account store

**Files:**
- Create: `site/src/lib/firebase.ts`
- Create: `site/src/lib/account/store.ts`
- Create: `site/src/lib/account/state.ts`
- Test: `site/src/lib/account/state.test.ts`
- Modify: `site/src/lib/hosting/store.ts` (use `firebase.ts`)

**Interfaces:**
- Consumes: `playerKey`, `cleanNick` (Task 1); rules shapes (Task 2).
- Produces:
  - `firebase.ts`: `auth`, `db`, `signIn(): Promise<void>`, `signOutUser(): Promise<void>`
  - `state.ts`:
    - `export interface Claim { uid: string; player: string; playerKey: string; email: string; googleName: string; status: 'pending' | 'approved' | 'rejected'; createdAt?: number }`
    - `export interface Profile { key: string; player: string; uid: string; nick?: string; avatar?: string }`
    - `export type AccountView = 'signed-out' | 'pick' | 'pending' | 'rejected' | 'settings'`
    - `accountView(signedIn: boolean, claim: Claim | null, profile: Profile | null): AccountView`
    - `takenKeys(profiles: Profile[]): Set<string>`
  - `store.ts`:
    - `onAccount(cb: (u: { uid: string; email: string; name: string; admin: boolean } | null) => void): void`
    - `getClaim(uid: string): Promise<Claim | null>`
    - `listProfiles(): Promise<Profile[]>`
    - `submitClaim(u, player: string): Promise<void>`
    - `cancelClaim(uid: string): Promise<void>`
    - `saveProfile(key: string, patch: { nick: string; avatar: string | null }): Promise<void>` (empty nick → delete field; `null` avatar → delete field)
    - `listClaims(): Promise<Claim[]>` (admin)
    - `decideClaim(c: Claim, approve: boolean, adminEmail: string): Promise<void>`
    - `resetProfile(key: string, what: 'nick' | 'avatar'): Promise<void>`
    - `unlink(p: Profile): Promise<void>`
    - `explainAccountError(e: unknown): string`

- [ ] **Step 1: Write the failing test**

```ts
// site/src/lib/account/state.test.ts
import { describe, expect, it } from 'vitest';
import { accountView, takenKeys, type Claim, type Profile } from './state.ts';

const claim = (status: Claim['status']): Claim => ({ uid: 'u', player: 'Braun', playerKey: 'braun', email: 'a@b.c', googleName: 'A', status });
const profile: Profile = { key: 'braun', player: 'Braun', uid: 'u' };

describe('accountView', () => {
  it('walks the five states', () => {
    expect(accountView(false, null, null)).toBe('signed-out');
    expect(accountView(true, null, null)).toBe('pick');
    expect(accountView(true, claim('pending'), null)).toBe('pending');
    expect(accountView(true, claim('rejected'), null)).toBe('rejected');
    expect(accountView(true, claim('approved'), profile)).toBe('settings');
  });
  it('an approved claim whose profile is gone (unlinked mid-session) goes back to picking', () => {
    expect(accountView(true, claim('approved'), null)).toBe('pick');
  });
});

describe('takenKeys', () => {
  it('collects linked player keys', () => {
    expect([...takenKeys([profile])]).toEqual(['braun']);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd site && npx vitest run src/lib/account/state.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// site/src/lib/account/state.ts
// Pure account logic for /account/ (unit-tested); Firestore calls live in store.ts.
export interface Claim {
  uid: string; player: string; playerKey: string; email: string; googleName: string;
  status: 'pending' | 'approved' | 'rejected'; createdAt?: number;
}
export interface Profile { key: string; player: string; uid: string; nick?: string; avatar?: string }
export type AccountView = 'signed-out' | 'pick' | 'pending' | 'rejected' | 'settings';

export function accountView(signedIn: boolean, claim: Claim | null, profile: Profile | null): AccountView {
  if (!signedIn) return 'signed-out';
  if (!claim) return 'pick';
  if (claim.status === 'pending') return 'pending';
  if (claim.status === 'rejected') return 'rejected';
  return profile ? 'settings' : 'pick';
}

export const takenKeys = (profiles: Profile[]) => new Set(profiles.map((p) => p.key));
```

```ts
// site/src/lib/firebase.ts
// One Firebase app per page for /host/ and /account/. Access control lives in firestore.rules.
import { initializeApp } from 'firebase/app';
import { GoogleAuthProvider, getAuth, signInWithPopup, signInWithRedirect, signOut } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { firebaseConfig } from './hosting/firebase-config';

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);

export async function signIn() {
  const provider = new GoogleAuthProvider();
  try {
    await signInWithPopup(auth, provider);
  } catch (e) {
    if ((e as { code?: string }).code === 'auth/popup-blocked') await signInWithRedirect(auth, provider);
    else throw e;
  }
}

export const signOutUser = () => signOut(auth);
```

In `site/src/lib/hosting/store.ts`: delete the `initializeApp`/`getAuth`/`getFirestore` lines, the local `signIn`/`signOutUser`, and their now-unused imports; add `import { auth, db, signIn, signOutUser } from '../firebase';` and `export { signIn, signOutUser };` so `src/scripts/host.ts` keeps working unchanged.

```ts
// site/src/lib/account/store.ts
// Firestore calls for /account/ and /account/admin/. Shapes must match firestore.rules.
import { onAuthStateChanged } from 'firebase/auth';
import {
  collection, deleteDoc, deleteField, doc, getDoc, getDocs, serverTimestamp, setDoc, writeBatch, type Timestamp,
} from 'firebase/firestore';
import { auth, db } from '../firebase';
import { playerKey } from '../profiles/core';
import type { Claim, Profile } from './state';

export type AccountUser = { uid: string; email: string; name: string; admin: boolean };

export function onAccount(cb: (u: AccountUser | null) => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    cb({ uid: u.uid, email: u.email, name: u.displayName ?? u.email, admin: host?.exists() === true && host.data().admin === true });
  });
}

const toClaim = (id: string, d: Record<string, unknown>): Claim => ({
  uid: id, player: String(d.player), playerKey: String(d.playerKey), email: String(d.email),
  googleName: String(d.googleName ?? ''), status: d.status as Claim['status'],
  createdAt: (d.createdAt as Timestamp | undefined)?.toMillis?.(),
});
const toProfile = (id: string, d: Record<string, unknown>): Profile => ({
  key: id, player: String(d.player), uid: String(d.uid),
  ...(typeof d.nick === 'string' ? { nick: d.nick } : {}),
  ...(typeof d.avatar === 'string' ? { avatar: d.avatar } : {}),
});
const bump = (b: ReturnType<typeof writeBatch>) => b.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });

export async function getClaim(uid: string) {
  const s = await getDoc(doc(db, 'claims', uid));
  return s.exists() ? toClaim(s.id, s.data()) : null;
}

export async function listProfiles() {
  const s = await getDocs(collection(db, 'profiles'));
  return s.docs.map((d) => toProfile(d.id, d.data()));
}

export const submitClaim = (u: AccountUser, player: string) =>
  setDoc(doc(db, 'claims', u.uid), {
    player, playerKey: playerKey(player), email: u.email, googleName: u.name.slice(0, 100),
    status: 'pending', createdAt: serverTimestamp(),
  });

export const cancelClaim = (uid: string) => deleteDoc(doc(db, 'claims', uid));

export async function saveProfile(key: string, patch: { nick: string; avatar: string | null }) {
  const b = writeBatch(db);
  b.update(doc(db, 'profiles', key), {
    nick: patch.nick ? patch.nick : deleteField(),
    avatar: patch.avatar ?? deleteField(),
    updatedAt: serverTimestamp(),
  });
  bump(b);
  await b.commit();
}

export async function listClaims() {
  const s = await getDocs(collection(db, 'claims'));
  return s.docs.map((d) => toClaim(d.id, d.data()));
}

export async function decideClaim(c: Claim, approve: boolean, adminEmail: string) {
  const b = writeBatch(db);
  b.update(doc(db, 'claims', c.uid), { status: approve ? 'approved' : 'rejected', decidedBy: adminEmail, decidedAt: serverTimestamp() });
  if (approve) {
    b.set(doc(db, 'profiles', c.playerKey), { player: c.player, uid: c.uid, updatedAt: serverTimestamp() });
    bump(b);
  }
  await b.commit();
}

export async function resetProfile(key: string, what: 'nick' | 'avatar') {
  const b = writeBatch(db);
  b.update(doc(db, 'profiles', key), { [what]: deleteField(), updatedAt: serverTimestamp() });
  bump(b);
  await b.commit();
}

export async function unlink(p: Profile) {
  const b = writeBatch(db);
  b.delete(doc(db, 'profiles', p.key));
  b.delete(doc(db, 'claims', p.uid));
  bump(b);
  await b.commit();
}

export function explainAccountError(e: unknown): string {
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав на цю дію (або гравця вже привʼязано).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання — спробуй ще.';
  if (code === 'auth/popup-closed-by-user') return 'Вхід скасовано.';
  return `Помилка: ${code || (e as Error).message}`;
}
```

- [ ] **Step 4: Run tests and type check**

Run: `cd site && npm test && npm run check`
Expected: PASS, 0 errors (host page still type-checks with the moved `signIn`).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/firebase.ts site/src/lib/account site/src/lib/hosting/store.ts
git commit -m "feat(site): account store and shared Firebase client"
```

---

### Task 6: Avatar crop and encode

**Files:**
- Create: `site/src/lib/account/avatar.ts`
- Test: `site/src/lib/account/avatar.test.ts`

**Interfaces:**
- Consumes: `AVATAR_MAX_CHARS` (Task 1).
- Produces:
  - `cropRect(w: number, h: number, zoom: number, dx: number, dy: number): { sx: number; sy: number; size: number }` — source square inside a `w×h` image; `zoom ≥ 1` (1 = largest centred square); `dx`,`dy` in −1…1 shift within the free space.
  - `interface Canvasish { width: number; height: number; getContext(t: '2d'): { drawImage(...a: unknown[]): void } | null; toDataURL(type: string, q?: number): string }`
  - `encodeAvatar(img: CanvasImageSource & { width: number; height: number }, rect: ReturnType<typeof cropRect>, makeCanvas: () => Canvasish): string` — throws `Error('too-big')` if nothing fits.

- [ ] **Step 1: Write the failing test**

```ts
// site/src/lib/account/avatar.test.ts
import { describe, expect, it } from 'vitest';
import { cropRect, encodeAvatar, type Canvasish } from './avatar.ts';

describe('cropRect', () => {
  it('centres the largest square at zoom 1', () => {
    expect(cropRect(400, 200, 1, 0, 0)).toEqual({ sx: 100, sy: 0, size: 200 });
    expect(cropRect(200, 400, 1, 0, 0)).toEqual({ sx: 0, sy: 100, size: 200 });
  });
  it('zoom shrinks the square; shifts stay inside the image', () => {
    expect(cropRect(400, 400, 2, 0, 0)).toEqual({ sx: 100, sy: 100, size: 200 });
    expect(cropRect(400, 400, 2, 1, -1)).toEqual({ sx: 200, sy: 0, size: 200 });
    expect(cropRect(400, 400, 2, 5, -5)).toEqual({ sx: 200, sy: 0, size: 200 });
  });
  it('zoom below 1 is treated as 1', () => {
    expect(cropRect(300, 300, 0.5, 0, 0)).toEqual({ sx: 0, sy: 0, size: 300 });
  });
});

const fakeCanvas = (urls: (type: string, q?: number) => string): (() => Canvasish) => () => ({
  width: 0, height: 0, getContext: () => ({ drawImage: () => {} }), toDataURL: urls,
});
const img = { width: 100, height: 100 } as unknown as HTMLImageElement;
const rect = { sx: 0, sy: 0, size: 100 };

describe('encodeAvatar', () => {
  it('uses WebP when the browser encodes it', () => {
    expect(encodeAvatar(img, rect, fakeCanvas(() => 'data:image/webp;base64,AAAA'))).toBe('data:image/webp;base64,AAAA');
  });
  it('falls back to JPEG when WebP comes back as PNG (Safari)', () => {
    const out = encodeAvatar(img, rect, fakeCanvas((t) => (t === 'image/webp' ? 'data:image/png;base64,AAAA' : 'data:image/jpeg;base64,BBBB')));
    expect(out).toBe('data:image/jpeg;base64,BBBB');
  });
  it('lowers quality until it fits, else throws too-big', () => {
    const qs: number[] = [];
    const big = `data:image/webp;base64,${'A'.repeat(200_000)}`;
    const out = encodeAvatar(img, rect, fakeCanvas((_t, q) => { qs.push(q!); return q! <= 0.5 ? 'data:image/webp;base64,AAAA' : big; }));
    expect(out).toBe('data:image/webp;base64,AAAA');
    expect(qs).toEqual([0.85, 0.85, 0.7, 0.5]); // first call probes WebP support
    expect(() => encodeAvatar(img, rect, fakeCanvas(() => big))).toThrow('too-big');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd site && npx vitest run src/lib/account/avatar.test.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement**

```ts
// site/src/lib/account/avatar.ts
// Square crop + 256×256 WebP (JPEG where the browser cannot encode WebP), small enough for Firestore.
import { AVATAR_MAX_CHARS } from '../profiles/core';

export const AVATAR_SIZE = 256;
const QUALITIES = [0.85, 0.7, 0.5];
const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));

export function cropRect(w: number, h: number, zoom: number, dx: number, dy: number) {
  const size = Math.round(Math.min(w, h) / Math.max(1, zoom));
  const freeX = w - size, freeY = h - size;
  return {
    sx: Math.round(freeX / 2 + clamp(dx, -1, 1) * freeX / 2),
    sy: Math.round(freeY / 2 + clamp(dy, -1, 1) * freeY / 2),
    size,
  };
}

export interface Canvasish {
  width: number; height: number;
  getContext(t: '2d'): { drawImage(...a: unknown[]): void } | null;
  toDataURL(type: string, q?: number): string;
}

export function encodeAvatar(
  img: CanvasImageSource & { width: number; height: number },
  rect: { sx: number; sy: number; size: number },
  makeCanvas: () => Canvasish = () => document.createElement('canvas') as unknown as Canvasish,
): string {
  const c = makeCanvas();
  c.width = AVATAR_SIZE;
  c.height = AVATAR_SIZE;
  c.getContext('2d')!.drawImage(img, rect.sx, rect.sy, rect.size, rect.size, 0, 0, AVATAR_SIZE, AVATAR_SIZE);
  const webp = c.toDataURL('image/webp', QUALITIES[0]).startsWith('data:image/webp');
  const type = webp ? 'image/webp' : 'image/jpeg';
  for (const q of QUALITIES) {
    const url = c.toDataURL(type, q);
    if (url.length <= AVATAR_MAX_CHARS) return url;
  }
  throw new Error('too-big');
}
```


- [ ] **Step 4: Run test to verify it passes**

Run: `cd site && npx vitest run src/lib/account/avatar.test.ts`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/account/avatar.ts site/src/lib/account/avatar.test.ts
git commit -m "feat(site): avatar crop and encode with JPEG fallback"
```

---

### Task 7: `/account/` page

**Files:**
- Create: `site/src/pages/account/index.astro`
- Create: `site/src/scripts/account.ts`
- Create: `site/src/styles/forms.css` (the `.box`/`.btn` styles moved out of `host/index.astro`)
- Modify: `site/src/pages/host/index.astro` (import `forms.css`, drop the moved rules), `site/src/lib/account/state.ts` (add `pickList`), `site/src/lib/account/state.test.ts`

**Interfaces:**
- Consumes: `accountView`, `takenKeys` (Task 5); store functions (Task 5); `cropRect`, `encodeAvatar` (Task 6); `cleanNick`, `nickError`, `playerKey` (Task 1); `loadPlayers()` at build.
- Produces:
  - `pickList(players: { name: string; slug: string; games: number; seasons: number }[], taken: Set<string>, query: string): { name: string; slug: string; games: number; seasons: number; taken: boolean }[]` — filtered by `query` (case-insensitive substring), at most 30, most games first.
  - `localStorage['fm-account']` = `JSON.stringify({ label: string, avatar?: string })` while signed in (read by Task 9's header); removed on sign-out.

- [ ] **Step 1: Write the failing test** — append to `state.test.ts`:

```ts
import { pickList } from './state.ts';

describe('pickList', () => {
  const players = [
    { name: 'Braun', slug: 'braun', games: 2750, seasons: 31 },
    { name: 'Brandon', slug: 'brandon', games: 3, seasons: 1 },
    { name: 'Floppy', slug: 'floppy', games: 900, seasons: 20 },
  ];
  it('filters case-insensitively, most games first, marks taken players', () => {
    expect(pickList(players, new Set(['braun']), 'BRA')).toEqual([
      { ...players[0], taken: true },
      { ...players[1], taken: false },
    ]);
  });
  it('empty query lists the top 30', () => {
    expect(pickList(players, new Set(), '')).toHaveLength(3);
    const many = Array.from({ length: 50 }, (_, i) => ({ name: `P${i}`, slug: `p${i}`, games: i, seasons: 1 }));
    expect(pickList(many, new Set(), '')).toHaveLength(30);
  });
});
```

Implementation for Step 2, in `state.ts`:

```ts
import { playerKey } from '../profiles/core';

export function pickList(
  players: { name: string; slug: string; games: number; seasons: number }[], taken: Set<string>, query: string,
) {
  const q = query.trim().toLowerCase();
  return players
    .filter((p) => !q || p.name.toLowerCase().includes(q))
    .sort((a, b) => b.games - a.games)
    .slice(0, 30)
    .map((p) => ({ ...p, taken: taken.has(playerKey(p.name)) }));
}
```

Run `cd site && npx vitest run src/lib/account/state.test.ts` before adding `pickList` → FAIL (`pickList` is not exported).

- [ ] **Step 2: Implement `pickList` (code above) and run the test again**

Run: `cd site && npx vitest run src/lib/account/state.test.ts`
Expected: PASS.

- [ ] **Step 3: Move shared form styles** — create `site/src/styles/forms.css` with exactly these rules cut from the `<style is:global>` block of `host/index.astro`: `.box`, `.btn`, `.btn:hover`, `.btn.primary`, `.btn.sm`, `.btn:disabled`, `.msg-error`, `.msg-warn`. In `host/index.astro` add `import '../../styles/forms.css';` to the frontmatter.

- [ ] **Step 4: Write the page**

```astro
---
// site/src/pages/account/index.astro
import Base from '../../layouts/Base.astro';
import { loadPlayers } from '../../lib/data';
import { href } from '../../lib/url';
import '../../styles/forms.css';

const players = loadPlayers().players.map((p) => ({ name: p.name, slug: p.slug, games: p.games, seasons: p.seasons }));
const data = JSON.stringify({ players, base: href('') }).replace(/</g, '\\u003c');
---
<Base title="Мій профіль" description="Профіль гравця Family Mafia Club.">
  <div class="pagehead"><h1 class="display">Мій профіль</h1><span class="label" id="who"></span></div>

  <section data-view="signed-out" class="box" hidden>
    <p>Увійди, щоб привʼязати свій акаунт до гравця клубу.</p>
    <button class="btn primary" id="sign-in" type="button">Увійти через Google</button>
  </section>

  <section data-view="pick" class="box" hidden>
    <p id="rejected-note" class="msg-warn" hidden>Попередню заявку відхилено. Можеш обрати гравця ще раз.</p>
    <p>Хто ти в таблицях клубу? Після вибору адмін підтвердить заявку.</p>
    <input id="pick-q" type="search" placeholder="Пошук гравця…" aria-label="Пошук гравця" autocomplete="off" />
    <ul id="pick-list" class="pick"></ul>
  </section>

  <section data-view="pending" class="box" hidden>
    <p>Заявку на гравця <b id="pending-player"></b> надіслано. Чекає схвалення адміна.</p>
    <button class="btn" id="cancel-claim" type="button">Скасувати заявку</button>
  </section>

  <section data-view="settings" hidden>
    <div class="box">
      <p>Ти — <a id="my-page"></a>. Зміни зʼявляться на сайті протягом години.</p>
      <label class="field">Нік на сайті
        <input id="nick" maxlength="24" autocomplete="off" />
        <span class="label">Порожньо — показувати імʼя з таблиць.</span>
      </label>
      <div class="field">Аватарка
        <div class="av-row">
          <canvas id="av-preview" width="128" height="128"></canvas>
          <div class="av-tools">
            <input id="av-file" type="file" accept="image/*" />
            <label>Масштаб <input id="av-zoom" type="range" min="1" max="3" step="0.05" value="1" /></label>
            <label>Зсув ↔ <input id="av-dx" type="range" min="-1" max="1" step="0.05" value="0" /></label>
            <label>Зсув ↕ <input id="av-dy" type="range" min="-1" max="1" step="0.05" value="0" /></label>
            <button class="btn sm" id="av-remove" type="button">Видалити аватарку</button>
          </div>
        </div>
      </div>
      <div class="actions"><button class="btn primary" id="save" type="button">Зберегти</button><span id="msg" aria-live="polite"></span></div>
    </div>
  </section>

  <p class="tools"><a id="admin-link" href={href('account/admin/')} hidden>Заявки гравців (адмін)</a>
    <button class="btn sm" id="sign-out" type="button" hidden>Вийти</button></p>
  <script type="application/json" id="account-data" set:html={data} />
</Base>

<script>
  import '../../scripts/account';
</script>

<style is:global>
  [data-view][hidden], #admin-link[hidden], #sign-out[hidden], #rejected-note[hidden] { display: none; }
  #pick-q, #nick { background: var(--panel-2); border: 1px solid var(--border); border-radius: 6px; color: var(--text);
    padding: 6px 10px; font: inherit; width: min(360px, 100%); }
  .pick { list-style: none; padding: 0; margin: 10px 0 0; display: grid; gap: 4px; }
  .pick button { all: unset; cursor: pointer; display: flex; gap: 10px; justify-content: space-between; width: 100%;
    padding: 6px 10px; border: 1px solid var(--border); border-radius: 6px; box-sizing: border-box; }
  .pick button:hover:not(:disabled) { border-color: var(--muted); }
  .pick button:disabled { opacity: .5; cursor: not-allowed; }
  .field { display: grid; gap: 6px; margin: 14px 0; color: var(--muted); }
  .av-row { display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }
  #av-preview { width: 128px; height: 128px; border-radius: 50%; background: var(--panel-2); border: 1px solid var(--border); }
  .av-tools { display: grid; gap: 8px; }
  .av-tools label { display: flex; gap: 8px; align-items: center; }
  .actions { display: flex; gap: 12px; align-items: center; flex-wrap: wrap; }
  .tools { display: flex; gap: 14px; align-items: center; }
</style>
```

```ts
// site/src/scripts/account.ts
// The /account/ page: sign-in, claiming a player, nick + avatar settings.
import { signIn, signOutUser } from '../lib/firebase';
import { cancelClaim, explainAccountError, getClaim, listProfiles, onAccount, saveProfile, submitClaim, type AccountUser } from '../lib/account/store';
import { accountView, pickList, takenKeys, type Claim, type Profile } from '../lib/account/state';
import { cropRect, encodeAvatar } from '../lib/account/avatar';
import { cleanNick, nickError, playerKey } from '../lib/profiles/core';

type P = { name: string; slug: string; games: number; seasons: number };
const page = JSON.parse(document.getElementById('account-data')!.textContent!) as { players: P[]; base: string };
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const remember = (v: { label: string; avatar?: string } | null) => {
  try { if (v) localStorage.setItem('fm-account', JSON.stringify(v)); else localStorage.removeItem('fm-account'); } catch { /* private mode */ }
};

let user: AccountUser | null = null;
let claim: Claim | null = null;
let profiles: Profile[] = [];
let mine: Profile | null = null;
let img: HTMLImageElement | null = null; // newly chosen photo, not saved yet
let avatar: string | null = null;        // what will be saved

function show() {
  const view = accountView(!!user, claim, mine);
  document.querySelectorAll<HTMLElement>('[data-view]').forEach((s) => { s.hidden = s.dataset.view !== (view === 'rejected' ? 'pick' : view); });
  $('rejected-note').hidden = view !== 'rejected';
  $('who').textContent = user?.email ?? '';
  $('sign-out').hidden = !user;
  $('admin-link').hidden = !user?.admin;
  if (view === 'pick' || view === 'rejected') renderPick();
  if (view === 'pending') $('pending-player').textContent = claim!.player;
  if (view === 'settings') renderSettings();
}

function renderPick() {
  const rows = pickList(page.players, takenKeys(profiles), $<HTMLInputElement>('pick-q').value);
  $('pick-list').innerHTML = rows.map((p) => `<li><button type="button" data-name="${esc(p.name)}" ${p.taken ? 'disabled' : ''}>
    <span>${esc(p.name)}</span><span class="label">${p.taken ? 'вже привʼязаний' : `${p.games} ігор · ${p.seasons} сез.`}</span></button></li>`).join('');
}

function renderSettings() {
  const p = page.players.find((x) => playerKey(x.name) === mine!.key);
  const a = $<HTMLAnchorElement>('my-page');
  a.textContent = mine!.player;
  a.href = p ? `${page.base}players/${p.slug}/` : '#';
  $<HTMLInputElement>('nick').value = mine!.nick ?? '';
  avatar = mine!.avatar ?? null;
  img = null;
  drawPreview();
}

function drawPreview() {
  const c = $<HTMLCanvasElement>('av-preview');
  const ctx = c.getContext('2d')!;
  ctx.clearRect(0, 0, c.width, c.height);
  if (img) {
    const r = cropRect(img.width, img.height, Number($<HTMLInputElement>('av-zoom').value),
      Number($<HTMLInputElement>('av-dx').value), Number($<HTMLInputElement>('av-dy').value));
    ctx.drawImage(img, r.sx, r.sy, r.size, r.size, 0, 0, c.width, c.height);
  } else if (avatar) {
    const saved = new Image();
    saved.onload = () => ctx.drawImage(saved, 0, 0, c.width, c.height);
    saved.src = avatar;
  }
}

const msg = (text: string, kind: 'error' | 'ok' = 'ok') => { $('msg').className = kind === 'error' ? 'msg-error' : ''; $('msg').textContent = text; };

async function refresh() {
  if (!user) { claim = null; mine = null; return show(); }
  try {
    [claim, profiles] = await Promise.all([getClaim(user.uid), listProfiles()]);
    mine = claim?.status === 'approved' ? profiles.find((p) => p.key === claim!.playerKey && p.uid === user!.uid) ?? null : null;
    remember({ label: mine?.nick ?? mine?.player ?? user.name, avatar: mine?.avatar });
  } catch (e) { alertBox(explainAccountError(e)); }
  show();
}

function alertBox(text: string) { $('who').textContent = text; }

$('sign-in').addEventListener('click', () => signIn().catch((e) => alertBox(explainAccountError(e))));
$('sign-out').addEventListener('click', async () => { remember(null); await signOutUser(); });
$('pick-q').addEventListener('input', renderPick);
$('pick-list').addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-name]');
  if (!b || b.disabled || !user) return;
  if (!confirmInline(b)) return;
  try { await submitClaim(user, b.dataset.name!); await refresh(); } catch (err) { alertBox(explainAccountError(err)); }
});
// Two-tap confirm instead of window.confirm(): first tap arms, second sends.
function confirmInline(b: HTMLButtonElement) {
  if (b.dataset.armed) return true;
  document.querySelectorAll<HTMLButtonElement>('#pick-list button[data-armed]').forEach((x) => { delete x.dataset.armed; x.querySelector('.label')!.textContent = ''; });
  b.dataset.armed = '1';
  b.querySelector('.label')!.textContent = 'Натисни ще раз — «Це я»';
  return false;
}
$('cancel-claim').addEventListener('click', async () => {
  try { await cancelClaim(user!.uid); await refresh(); } catch (e) { alertBox(explainAccountError(e)); }
});
$('av-file').addEventListener('change', () => {
  const f = $<HTMLInputElement>('av-file').files?.[0];
  if (!f) return;
  const url = URL.createObjectURL(f);
  const i = new Image();
  i.onload = () => { img = i; ['av-zoom', 'av-dx', 'av-dy'].forEach((id) => { $<HTMLInputElement>(id).value = id === 'av-zoom' ? '1' : '0'; }); drawPreview(); msg(''); };
  i.onerror = () => msg('Не вдалося прочитати зображення.', 'error');
  i.src = url;
});
['av-zoom', 'av-dx', 'av-dy'].forEach((id) => $(id).addEventListener('input', drawPreview));
$('av-remove').addEventListener('click', () => { img = null; avatar = null; $<HTMLInputElement>('av-file').value = ''; drawPreview(); });
$('save').addEventListener('click', async () => {
  if (!mine) return;
  const nick = cleanNick($<HTMLInputElement>('nick').value);
  const others = [
    ...page.players.filter((p) => playerKey(p.name) !== mine!.key).map((p) => p.name),
    ...profiles.filter((p) => p.key !== mine!.key && p.nick).map((p) => p.nick!),
  ];
  const err = nickError(nick, mine.player, others);
  if (err) return msg(err, 'error');
  try {
    if (img) {
      avatar = encodeAvatar(img, cropRect(img.width, img.height, Number($<HTMLInputElement>('av-zoom').value),
        Number($<HTMLInputElement>('av-dx').value), Number($<HTMLInputElement>('av-dy').value)));
    }
  } catch { return msg('Зображення завелике навіть після стиснення — обери інше.', 'error'); }
  $<HTMLButtonElement>('save').disabled = true;
  try {
    await saveProfile(mine.key, { nick: nick.toLowerCase() === mine.player.toLowerCase() ? '' : nick, avatar });
    mine = { ...mine, nick: nick || undefined, avatar: avatar ?? undefined };
    img = null;
    remember({ label: mine.nick ?? mine.player, avatar: mine.avatar });
    msg('Збережено. На сайті зʼявиться протягом години.');
  } catch (e) { msg(explainAccountError(e), 'error'); } finally { $<HTMLButtonElement>('save').disabled = false; }
});

onAccount((u) => { user = u; refresh(); });
```

- [ ] **Step 5: Verify**

Run: `cd site && npm test && npm run check && npm run build`
Expected: PASS; check-dist passes (the new page's links resolve).
Manual (dev server `npm run dev`, open `/FamilyMafiaApp/account/`): signed-out view shows the button; after sign-in the player list appears and filters as you type. (Writing needs the Task 2 rules published — done in Task 10.)

- [ ] **Step 6: Commit**

```bash
git add site/src/pages/account/index.astro site/src/scripts/account.ts site/src/styles/forms.css site/src/pages/host/index.astro site/src/lib/account/state.ts site/src/lib/account/state.test.ts
git commit -m "feat(site): /account/ — claim a player, set nick and avatar"
```

---

### Task 8: `/account/admin/` page

**Files:**
- Create: `site/src/pages/account/admin.astro`
- Create: `site/src/scripts/account-admin.ts`
- Modify: `site/src/lib/account/state.ts` + `state.test.ts` (add `sortClaims`)

**Interfaces:**
- Consumes: `listClaims`, `listProfiles`, `decideClaim`, `resetProfile`, `unlink`, `onAccount`, `explainAccountError` (Task 5); `signIn` (Task 5).
- Produces: `sortClaims(claims: Claim[]): Claim[]` — pending first, then newest `createdAt` first.

- [ ] **Step 1: Write the failing test** — append to `state.test.ts`:

```ts
import { sortClaims } from './state.ts';

describe('sortClaims', () => {
  it('pending first, newest first', () => {
    const c = (uid: string, status: Claim['status'], createdAt: number): Claim => ({ ...claim(status), uid, createdAt });
    expect(sortClaims([c('a', 'rejected', 3), c('b', 'pending', 1), c('c', 'pending', 2), c('d', 'approved', 4)]).map((x) => x.uid))
      .toEqual(['c', 'b', 'd', 'a']);
  });
});
```

Run: `cd site && npx vitest run src/lib/account/state.test.ts` → FAIL (`sortClaims` missing). Then add to `state.ts`:

```ts
export const sortClaims = (claims: Claim[]) => [...claims].sort((a, b) =>
  Number(b.status === 'pending') - Number(a.status === 'pending') || (b.createdAt ?? 0) - (a.createdAt ?? 0));
```

Run again → PASS.

- [ ] **Step 2: Write the page**

```astro
---
// site/src/pages/account/admin.astro
import Base from '../../layouts/Base.astro';
import '../../styles/forms.css';
---
<Base title="Заявки гравців" description="Схвалення профілів гравців.">
  <div class="pagehead"><h1 class="display">Заявки гравців</h1><span class="label" id="who"></span></div>
  <section id="gate" class="box" hidden>
    <p id="gate-text">Увійди як адмін.</p>
    <button class="btn primary" id="sign-in" type="button">Увійти через Google</button>
  </section>
  <section id="admin" hidden>
    <h2 class="label">Заявки</h2>
    <div id="claims" class="list"></div>
    <h2 class="label">Привʼязані профілі</h2>
    <div id="profiles" class="list"></div>
  </section>
</Base>

<script>
  import '../../scripts/account-admin';
</script>

<style is:global>
  #gate[hidden], #admin[hidden] { display: none; }
  .list { display: grid; gap: 6px; margin-bottom: 18px; }
  .item { display: flex; flex-wrap: wrap; gap: 6px 14px; align-items: center; }
  .item .grow { flex: 1 1 220px; }
  .item img { width: 32px; height: 32px; border-radius: 50%; object-fit: cover; }
  .st-pending { color: var(--mid); } .st-approved { color: var(--good); } .st-rejected { color: var(--muted); }
</style>
```

```ts
// site/src/scripts/account-admin.ts
// /account/admin/: approve or reject player claims; reset or unlink profiles. Rules re-check everything.
import { signIn } from '../lib/firebase';
import { decideClaim, explainAccountError, listClaims, listProfiles, onAccount, resetProfile, unlink, type AccountUser } from '../lib/account/store';
import { sortClaims, takenKeys, type Claim, type Profile } from '../lib/account/state';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const STATUS = { pending: 'чекає', approved: 'схвалено', rejected: 'відхилено' } as const;
let user: AccountUser | null = null;
let claims: Claim[] = [];
let profiles: Profile[] = [];

async function load() {
  try { [claims, profiles] = await Promise.all([listClaims(), listProfiles()]); render(); }
  catch (e) { $('who').textContent = explainAccountError(e); }
}

function render() {
  const taken = takenKeys(profiles);
  $('claims').innerHTML = sortClaims(claims).map((c) => {
    const busy = c.status !== 'approved' && taken.has(c.playerKey);
    return `<div class="box item"><span class="grow"><b>${esc(c.player)}</b> ← ${esc(c.googleName)} &lt;${esc(c.email)}&gt;
      <span class="label">${c.createdAt ? new Date(c.createdAt).toLocaleDateString('uk-UA') : ''}</span></span>
      <span class="st-${c.status}">${STATUS[c.status]}</span>
      ${c.status === 'pending' ? `<button class="btn sm primary" data-act="approve" data-uid="${esc(c.uid)}" ${busy ? 'disabled title="вже привʼязаний"' : ''}>${busy ? 'вже привʼязаний' : 'Схвалити'}</button>
      <button class="btn sm" data-act="reject" data-uid="${esc(c.uid)}">Відхилити</button>` : ''}</div>`;
  }).join('') || '<p class="label">Заявок немає.</p>';
  $('profiles').innerHTML = profiles.map((p) => `<div class="box item">
      ${p.avatar ? `<img src="${esc(p.avatar)}" alt="" />` : ''}
      <span class="grow"><b>${esc(p.player)}</b>${p.nick ? ` → ${esc(p.nick)}` : ''}</span>
      ${p.nick ? `<button class="btn sm" data-act="reset-nick" data-key="${esc(p.key)}">Скинути нік</button>` : ''}
      ${p.avatar ? `<button class="btn sm" data-act="reset-avatar" data-key="${esc(p.key)}">Скинути аватарку</button>` : ''}
      <button class="btn sm" data-act="unlink" data-key="${esc(p.key)}">Відвʼязати</button></div>`).join('')
    || '<p class="label">Профілів ще немає.</p>';
}

document.addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button[data-act]');
  if (!b || !user) return;
  // Destructive actions arm on the first tap and run on the second.
  if (b.dataset.act === 'unlink' && !b.dataset.armed) { b.dataset.armed = '1'; b.textContent = 'Точно відвʼязати?'; return; }
  b.disabled = true;
  try {
    const c = claims.find((x) => x.uid === b.dataset.uid);
    const p = profiles.find((x) => x.key === b.dataset.key);
    if (b.dataset.act === 'approve' && c) await decideClaim(c, true, user.email);
    if (b.dataset.act === 'reject' && c) await decideClaim(c, false, user.email);
    if (b.dataset.act === 'reset-nick' && p) await resetProfile(p.key, 'nick');
    if (b.dataset.act === 'reset-avatar' && p) await resetProfile(p.key, 'avatar');
    if (b.dataset.act === 'unlink' && p) await unlink(p);
    await load();
  } catch (err) {
    $('who').textContent = explainAccountError(err);
    b.disabled = false;
  }
});

$('sign-in').addEventListener('click', () => signIn().catch((e) => { $('gate-text').textContent = explainAccountError(e); }));
onAccount((u) => {
  user = u;
  $('who').textContent = u?.email ?? '';
  $('gate').hidden = !!u?.admin;
  $('admin').hidden = !u?.admin;
  if (u && !u.admin) { $('gate-text').textContent = 'Немає доступу.'; $('sign-in').hidden = true; }
  if (u?.admin) load();
});
```

- [ ] **Step 3: Verify**

Run: `cd site && npm test && npm run check && npm run build`
Expected: PASS; check-dist passes.

- [ ] **Step 4: Commit**

```bash
git add site/src/pages/account/admin.astro site/src/scripts/account-admin.ts site/src/lib/account/state.ts site/src/lib/account/state.test.ts
git commit -m "feat(site): /account/admin/ — approve claims, reset and unlink profiles"
```

---

### Task 9: Header account item

**Files:**
- Modify: `site/src/layouts/Base.astro`

**Interfaces:**
- Consumes: `localStorage['fm-account']` (Task 7).
- Produces: header link `a.account` → `/account/`.

Design refinement over the spec: the header reads the `fm-account` value that `/account/` stores instead of loading Firebase on static pages, so normal pages stay free of the Firebase bundle entirely.

- [ ] **Step 1: Add the link** — in `Base.astro`, right before the `<button class="theme" …>`:

```astro
        <a class="account" href={href('account/')} aria-label="Мій профіль" title="Мій профіль"><span>Увійти</span></a>
```

and in the existing inline script at the end of `<body>`, append:

```js
      try {
        const acc = JSON.parse(localStorage.getItem('fm-account') || 'null');
        const a = document.querySelector('.account');
        if (acc && a) {
          a.textContent = '';
          if (acc.avatar) {
            const img = document.createElement('img');
            img.src = acc.avatar; img.alt = ''; img.width = 28; img.height = 28;
            a.append(img);
          } else {
            const s = document.createElement('span');
            s.className = 'initial';
            s.textContent = (acc.label || '?').slice(0, 1).toUpperCase();
            a.append(s);
          }
          a.title = acc.label || 'Мій профіль';
        }
      } catch {}
```

CSS (in the `<style>` block): move `margin-left: auto` from `.theme` to `.account`, and add:

```css
  .account { margin-left: auto; display: grid; place-items: center; min-width: 32px; height: 32px; padding: 0 10px;
    border: 1px solid var(--border); border-radius: var(--radius); color: var(--muted); font-size: 13px; white-space: nowrap; }
  .account:hover { color: var(--text); }
  .account:has(img), .account:has(.initial) { padding: 0; width: 32px; border-radius: 50%; overflow: hidden; }
  .account img { width: 100%; height: 100%; object-fit: cover; }
  .account .initial { font-weight: 600; color: var(--text); }
```

- [ ] **Step 2: Verify**

Run: `cd site && npm run check && npm run build`
Expected: 0 errors; check-dist passes (`/account/` link resolves on every page).
Manual: `npm run preview`, open any page: «Увійти» shows; in DevTools run `localStorage.setItem('fm-account', JSON.stringify({label:'Boss'}))`, reload: a round «B» shows; at 375 px width the header still fits without horizontal scroll.

- [ ] **Step 3: Commit**

```bash
git add site/src/layouts/Base.astro
git commit -m "feat(site): account item in the header"
```

---

### Task 10: Docs, publish rules, deploy, live check

**Files:**
- Modify: `CLAUDE.md` (Web site section), memory file `familymafia-web-site.md`

- [ ] **Step 1: Document** — in `CLAUDE.md` under "Web site", after the game-hosting bullet, add:

```markdown
- **Player profiles:** `/account/` (Google sign-in → claim a player → admin approves on
  `/account/admin/` → nick + avatar). Firestore `claims/{uid}` (private) and
  `profiles/{playerKey}` (public; `playerKey` = lower-cased, URI-encoded display name).
  `site/scripts/fetch-profiles.ts` runs before `astro build`, writes `data/profiles.json` and
  `public/avatars/` (gitignored); components show nicks via `PlayerName.astro`. Changes appear
  after the next build (games-watch, ≤ 1 h). Rules for both live in `firestore.rules`.
```

- [ ] **Step 2: Full local verification**

Run:
```bash
cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/Android Studio/jbr" npm test
cd ../../site && npm test && npm run check && npm run build
```
Expected: all PASS.

- [ ] **Step 3: Commit and push both branches** (master and `feature/flutter_migration` kept at the same commit: merge, then fast-forward; no force-push)

```bash
git add CLAUDE.md && git commit -m "docs: player profiles"
git push origin feature/flutter_migration
git checkout master && git merge --ff-only feature/flutter_migration || git merge feature/flutter_migration
git push origin master && git checkout feature/flutter_migration && git merge --ff-only master && git push origin feature/flutter_migration
```

- [ ] **Step 4: Owner publishes the rules** — ask the owner to paste `firestore.rules` into Firebase console → Firestore → Rules and click Publish (the implementer cannot click Publish).

- [ ] **Step 5: Live check** after the "Web site" run succeeds (`gh run list --workflow web.yml -L 1`):
  1. Owner opens `/account/` with a second Google account, claims a player → «Чекає схвалення».
  2. Owner (admin) opens `/account/admin/`, approves.
  3. Second account sets a nick and an avatar, saves → «Збережено».
  4. After the next build (games-watch, or `gh workflow run web.yml --ref master` by the owner) the nick and avatar show in the season table and on the player page with «у таблицях: …».
  5. Admin resets the nick, then unlinks; after a rebuild the sheet name is back.

- [ ] **Step 6: Update memory** — add a "Player profiles (2026-10-05)" paragraph to `familymafia-web-site.md` with the collections, the build step and the rules-publish gotcha.
