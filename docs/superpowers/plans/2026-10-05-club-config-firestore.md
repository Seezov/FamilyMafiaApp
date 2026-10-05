# Tournaments in Firestore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The tournament list (and later final thresholds) lives in Firestore `config/club`; admins edit it on `/debug/` with Google sign-in; the app and the site build read it.

**Architecture:** One public-read, admin-write document. Dart reads it over REST (`FirestoreService.fetchClubConfig`) with the existing cache layer (file cache in the app, the prefetched snapshot in the site build); `tournamentsProvider` prefers it and falls back to the JSON config's block until that block is removed. `/debug/` swaps its GitHub token flow for the Firebase SDK the `/host/` page already uses, saving pending ops in a transaction and bumping `meta/state.updatedAt`.

**Tech Stack:** Dart/Flutter + Riverpod + Dio; Astro/TypeScript + Firebase JS SDK 12; `@firebase/rules-unit-testing` + vitest.

**Spec:** `docs/superpowers/specs/2026-10-05-club-config-firestore-design.md`

## Global Constraints

- Document path `config/club`; fields exactly `tournaments`, `rejectedCandidates`, `gameLimits`, `updatedAt`, `updatedBy`, `updatedByEmail`.
- Read: anyone. Write: `isAdmin()` only (existing rules function).
- Tournament entries keep today's shape and key order: `season, type, name, games, date?, status?, podium` (`normalize` in `site/src/lib/config-edit.ts`).
- Firebase project id: `familymafiaapp`.
- `tool/prefetch_seasons.dart` stays pure Dart (a test guards its import graph — no Flutter imports).
- No push, no rules publish, no Firestore writes by the implementer; Task 5 is the controller's rollout with the user.
- Site chrome is English.

## Review Focus

1. Firestore REST 404 for a missing `config/club` must read as "no club config", not an error, until the JSON block is removed — Task 2 tests it.
2. Firestore rejects `undefined` field values: every entry written from `/debug/` goes through `normalize` (drops empty optionals) — Task 3 test on `clubBody`.
3. A non-admin host signed in on `/debug/` must see a disabled Save with the reason, and the rules must deny them even if the button is forced — Tasks 1 and 4.
4. The site export must wait for the club config before exporting (else tournaments silently vanish from the build) — Task 2 `loadSiteContainer` + export test.
5. The import must not overwrite an existing `config/club` (two admins, or a second click) — Task 3 transaction checks existence.

---

### Task 1: Firestore rules for `config/club`

**Files:**
- Modify: `firestore.rules` (new `match /config/club` block, before `match /meta/state`)
- Modify: `firebase/rules-test/rules.test.ts`

- [ ] **Step 1: Failing tests** — append to `rules.test.ts` (it already seeds HOST, OTHER, ADMIN in `hosts`; STRANGER is not a host):

```ts
describe('config/club', () => {
  const body = (who: User, extra: Record<string, unknown> = {}) => ({
    tournaments: [{ season: 31, type: 'minicap', name: 'Cup', games: 4, podium: ['A'] }],
    rejectedCandidates: [], gameLimits: {},
    updatedAt: serverTimestamp(), updatedBy: who.uid, updatedByEmail: who.email, ...extra,
  });
  const club = (db: ReturnType<typeof as>) => doc(db, 'config', 'club');

  it('anyone reads', async () => {
    await assertSucceeds(getDoc(club(env.unauthenticatedContext().firestore())));
  });
  it('admin writes', async () => {
    await assertSucceeds(setDoc(club(as(ADMIN)), body(ADMIN)));
  });
  it('a host who is not an admin cannot', async () => {
    await assertFails(setDoc(club(as(HOST)), body(HOST)));
  });
  it('a signed-in stranger and anonymous cannot', async () => {
    await assertFails(setDoc(club(as(STRANGER)), body(STRANGER)));
    await assertFails(setDoc(club(env.unauthenticatedContext().firestore()), body(ADMIN)));
  });
  it('extra keys, wrong types or a forged author are denied', async () => {
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { seasons: [] })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { tournaments: 'x' })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { gameLimits: [] })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { updatedBy: HOST.uid })));
    await assertFails(setDoc(club(as(ADMIN)), body(ADMIN, { updatedByEmail: HOST.email })));
  });
  it('admin cannot delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'club'), { tournaments: [] }));
    await assertFails(deleteDoc(club(as(ADMIN))));
  });
});
```

- [ ] **Step 2: Run** (from `firebase/rules-test`, with `JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr"` and `$JAVA_HOME/bin` on `PATH`; see the existing `package.json` test script) → the new tests FAIL.
- [ ] **Step 3: Rules** — add inside `match /databases/{database}/documents`:

```
    // The club's tournament list and final thresholds, edited on /debug/.
    match /config/club {
      allow read: if true;
      allow create, update: if isAdmin()
        && request.resource.data.keys().hasOnly(['tournaments', 'rejectedCandidates', 'gameLimits',
             'updatedAt', 'updatedBy', 'updatedByEmail'])
        && request.resource.data.tournaments is list
        && request.resource.data.rejectedCandidates is list
        && request.resource.data.gameLimits is map
        && request.resource.data.updatedAt == request.time
        && request.resource.data.updatedBy == request.auth.uid
        && request.resource.data.updatedByEmail == email();
    }
```

- [ ] **Step 4: Run** → all rules tests PASS (old ones too).
- [ ] **Step 5: Commit** `git add firestore.rules firebase/rules-test/rules.test.ts && git commit -m "feat(rules): config/club — public read, admin write"`

---

### Task 2: Dart reads `config/club`

**Files:**
- Create: `lib/models/club_config.dart`
- Modify: `lib/services/firestore_service.dart` (`kFirebaseProjectId`, `fetchClubConfig`)
- Modify: `lib/services/prefetch_paths.dart` (`prefetchedClubConfigFile`)
- Modify: `lib/services/season_cache_service.dart`, `io_season_cache_service.dart`, `asset_season_cache_service.dart` (club config cache)
- Modify: `lib/providers/app_providers.dart` (`clubConfigProvider`, `tournamentsProvider`)
- Modify: `lib/site_export/load_container.dart` (await club config)
- Modify: `tool/prefetch_seasons.dart` (snapshot `config/club`)
- Modify: every test fake implementing `SeasonCacheService` (`test/services/firestore_service_test.dart` `_MemCache`, any others: `grep -rn "implements SeasonCacheService" test`)
- Test: `test/models/club_config_test.dart`, `test/services/firestore_service_test.dart`, `test/providers/club_config_provider_test.dart`, the prefetch test (find with `grep -rln prefetchSeasons test`)

**Interfaces:**
- Produces:
  - `class ClubConfig { final List<Tournament> tournaments; final List<String> rejectedCandidates; final Map<int, int> gameLimits; factory ClubConfig.fromJson(Map<String, dynamic>); }`
  - `const kFirebaseProjectId = 'familymafiaapp';`
  - `Future<String?> FirestoreService.fetchClubConfig(String projectId)` — decoded fields as a JSON string (`tournaments`, `rejectedCandidates`, `gameLimits` only), `null` on 404.
  - `SeasonCacheService.getCachedClubConfig()` / `cacheClubConfig(String json)`
  - `const prefetchedClubConfigFile = 'club_config.json';`
  - `final clubConfigProvider = FutureProvider<ClubConfig?>`

- [ ] **Step 1: Failing tests.**

`test/models/club_config_test.dart`:

```dart
import 'package:family_mafia_app/models/club_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the document', () {
    final c = ClubConfig.fromJson({
      'tournaments': [
        {'season': 31, 'type': 'minicap', 'name': 'Cup', 'games': 4, 'date': '01.09.2026', 'podium': ['A', 'B']},
      ],
      'rejectedCandidates': ['31|2026-09-08'],
      'gameLimits': {'31': 41},
    });
    expect(c.tournaments.single.type, TournamentType.minicap);
    expect(c.tournaments.single.podium, ['A', 'B']);
    expect(c.rejectedCandidates, ['31|2026-09-08']);
    expect(c.gameLimits, {31: 41});
  });
  test('missing fields are empty', () {
    final c = ClubConfig.fromJson({});
    expect((c.tournaments, c.rejectedCandidates, c.gameLimits), (isEmpty, isEmpty, isEmpty));
  });
}
```

(If the record-of-matchers line doesn't compile, assert the three separately.)

In `firestore_service_test.dart`, following its existing fake-Dio pattern: a GET of `.../documents/config/club` returning `{"name": "...", "fields": {"tournaments": {"arrayValue": {"values": [{"mapValue": {"fields": {"season": {"integerValue": "31"}, "type": {"stringValue": "minicap"}, "name": {"stringValue": "Cup"}, "games": {"integerValue": "4"}, "podium": {"arrayValue": {"values": [{"stringValue": "A"}]}}}}}]}}, "gameLimits": {"mapValue": {"fields": {"31": {"integerValue": "41"}}}}, "updatedAt": {"timestampValue": "2026-10-05T10:00:00Z"}, "updatedBy": {"stringValue": "u"}}}` → `jsonDecode(result!)` equals `{'tournaments': [{'season': 31, 'type': 'minicap', 'name': 'Cup', 'games': 4, 'podium': ['A']}], 'rejectedCandidates': [], 'gameLimits': {'31': 41}}`; a 404 response → `null`.

`test/providers/club_config_provider_test.dart`: a `ProviderContainer` overriding `seasonCacheServiceProvider` with an in-memory cache and `firestoreServiceProvider` with (a) a fake whose `fetchClubConfig` returns a document with one tournament → `tournamentsProvider` (after `await container.read(clubConfigProvider.future)`) has it and the cache now holds it; (b) a fake that throws → the cached copy is used; (c) `null` service + empty cache → `clubConfigProvider` is `null` and `tournamentsProvider` falls back to `parsedConfigProvider`'s tournaments (override `parsedConfigProvider` is private-typed — instead seed the memory cache's remote config with a config JSON holding one tournament and `envJsonProvider` with `{}`, as `test/providers/parsed_config_snapshot_test.dart` does).

Prefetch test: with a fake Dio answering the config URL (with a `"tournaments"` block) and `config/club` 404 → no `club_config.json` written, no error; with `config/club` 200 → `club_config.json` written; with a config WITHOUT `"tournaments"` and a 404 → throws `FormatException`.

- [ ] **Step 2: Run** the four test files → FAIL.
- [ ] **Step 3: `lib/models/club_config.dart`:**

```dart
import 'package:family_mafia_app/models/tournament.dart';

/// Firestore `config/club`: the club's tournament list, candidates the Debug
/// page rejected, and admins' final thresholds by season id.
class ClubConfig {
  final List<Tournament> tournaments;
  final List<String> rejectedCandidates;
  final Map<int, int> gameLimits;

  const ClubConfig({
    this.tournaments = const [],
    this.rejectedCandidates = const [],
    this.gameLimits = const {},
  });

  /// From the document's decoded fields or the prefetched snapshot (same shape).
  factory ClubConfig.fromJson(Map<String, dynamic> json) => ClubConfig(
        tournaments: parseTournaments(json),
        rejectedCandidates:
            (json['rejectedCandidates'] as List?)?.cast<String>() ?? const [],
        gameLimits: {
          for (final e in ((json['gameLimits'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as int,
        },
      );
}
```

- [ ] **Step 4: `FirestoreService`:**

```dart
/// The Firebase project behind /host/ and config/club.
const kFirebaseProjectId = 'familymafiaapp';

  /// `config/club` as JSON (tournaments, rejectedCandidates, gameLimits), or
  /// null when the document doesn't exist yet.
  Future<String?> fetchClubConfig(String projectId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '$projectId/databases/(default)/documents/config/club');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final fields = decodeFirestoreFields(
          response.data?['fields'] as Map<String, dynamic>? ?? const {});
      return jsonEncode({
        'tournaments': fields['tournaments'] ?? const [],
        'rejectedCandidates': fields['rejectedCandidates'] ?? const [],
        'gameLimits': fields['gameLimits'] ?? const {},
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
```

- [ ] **Step 5: Cache.** Interface: `Future<String?> getCachedClubConfig();` `Future<void> cacheClubConfig(String jsonData);`. Io: `club_config.json` in the cache dir (same pattern as `remote_config.json`). Asset: `getCachedClubConfig() => _tryLoad(prefetchedClubConfigFile)`, `cacheClubConfig` no-op. Test fakes: memory field.
- [ ] **Step 6: Providers** (`app_providers.dart`):

```dart
/// Firestore `config/club` (see [ClubConfig]): live, else the cached copy
/// (the build's snapshot on the web/export), else null — then the JSON
/// config's tournaments still apply.
final clubConfigProvider = FutureProvider<ClubConfig?>((ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  if (firestore != null) {
    try {
      final json = await firestore.fetchClubConfig(kFirebaseProjectId);
      if (json != null) {
        await cache.cacheClubConfig(json);
        return ClubConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Club config fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedClubConfig();
    if (cached != null) return ClubConfig.fromJson(jsonDecode(cached) as Map<String, dynamic>);
  } catch (e) {
    debugPrint('Cached club config unavailable: $e');
  }
  return null;
});

final tournamentsProvider = Provider<List<Tournament>>((ref) =>
    ref.watch(clubConfigProvider).valueOrNull?.tournaments ??
    ref.watch(parsedConfigProvider).valueOrNull?.tournaments ??
    const []);
```

In `initialLoadProvider`, start it early without awaiting: `ref.read(clubConfigProvider.future).ignore();` right after `parsedConfigProvider` resolves. In `backgroundLoadProvider`, before setting `LoadingPhase.allLoaded`: `await ref.read(clubConfigProvider.future);` so `appDataProvider` completes only with the club config settled.
- [ ] **Step 7: `load_container.dart`** — after `await container.read(appDataProvider.future);` add `await container.read(clubConfigProvider.future);` (belt and braces; cheap).
- [ ] **Step 8: Prefetch.** In `prefetchSeasons`, after the seasons loop (before writing anything):

```dart
  final club = await firestore.fetchClubConfig(kFirebaseProjectId);
  final configHasTournaments =
      (jsonDecode(configJson) as Map<String, dynamic>).containsKey('tournaments');
  if (club == null && !configHasTournaments) {
    throw const FormatException('config/club is missing and the config has no tournaments');
  }
```

and when writing: `if (club != null) await File('${outDir.path}/$prefetchedClubConfigFile').writeAsString(club);`. Keep the "fetch everything, then write" order.
- [ ] **Step 9: Run** the new tests → PASS; `flutter test` and `flutter analyze` → clean.
- [ ] **Step 10: Commit** `git add lib tool test && git commit -m "feat: read tournaments from Firestore config/club"`

---

### Task 3: Site data layer for `config/club`

**Files:**
- Modify: `site/src/lib/config-edit.ts` (add `ClubDoc`, `clubBody`; remove `rewriteConfig`, `describe`)
- Modify: `site/src/lib/config-edit.test.ts` (drop `rewriteConfig`/`describe` tests, add `clubBody`)
- Create: `site/src/lib/club/store.ts`
- Delete: `site/src/lib/github.ts` (and its test file if any — `ls site/src/lib/github*`)

**Interfaces:**
- Produces (config-edit.ts):
  - `export type ClubDoc = { tournaments: ConfigEntry[]; rejectedCandidates: string[]; gameLimits: Record<string, number> };`
  - `export function clubBody(file: SeasonConfigFile, gameLimits?: Record<string, number>): ClubDoc`
- Produces (club/store.ts):
  - `export type ClubAdmin = { uid: string; email: string; name: string; admin: boolean };`
  - `export function onClubUser(cb: (u: ClubAdmin | null | 'not-host') => void): void`
  - `export async function loadClub(): Promise<ClubDoc | null>`
  - `export async function saveClub(ops: Op[], u: ClubAdmin): Promise<void>` — throws `Error('config/club does not exist yet — import it first')` when missing.
  - `export async function importClub(file: SeasonConfigFile, u: ClubAdmin): Promise<void>` — throws `Error('config/club already exists')` when present.
  - re-exports `signIn`, `signOutUser`.

- [ ] **Step 1: Failing vitest** in `config-edit.test.ts`:

```ts
describe('clubBody', () => {
  it('normalizes entries and keeps order, rejected and limits', () => {
    const file: SeasonConfigFile = {
      tournaments: [
        { season: 30, type: 'minicap', name: ' A ', games: 3, date: '', podium: ['x', ' '] },
        { season: 31, type: 'maxicap', name: 'B', games: 5, date: '01.09.2026', status: 'detected', podium: [] },
      ],
      rejectedCandidates: ['31|2026-09-08'],
    };
    expect(clubBody(file, { '31': 41 })).toEqual({
      tournaments: [
        { season: 30, type: 'minicap', name: 'A', games: 3, podium: ['x'] },
        { season: 31, type: 'maxicap', name: 'B', games: 5, date: '01.09.2026', status: 'detected', podium: [] },
      ],
      rejectedCandidates: ['31|2026-09-08'],
      gameLimits: { '31': 41 },
    });
  });
  it('never emits undefined (Firestore rejects it)', () => {
    const body = clubBody({ tournaments: [{ season: 1, type: 't', name: 'n', games: 1, podium: [] }] });
    expect(JSON.stringify(body)).not.toContain('undefined');
    expect(Object.values(body.tournaments[0]).includes(undefined)).toBe(false);
    expect(body.rejectedCandidates).toEqual([]);
    expect(body.gameLimits).toEqual({});
  });
});
```

- [ ] **Step 2: Run** `cd site && npx vitest run src/lib/config-edit.test.ts` → FAIL.
- [ ] **Step 3: `config-edit.ts`** — add:

```ts
/** Firestore `config/club` minus its author/time fields. */
export type ClubDoc = { tournaments: ConfigEntry[]; rejectedCandidates: string[]; gameLimits: Record<string, number> };

/** What /debug/ writes to `config/club`: normalized entries (no undefined
 * fields — Firestore rejects them) in the file's order. */
export const clubBody = (file: SeasonConfigFile, gameLimits: Record<string, number> = {}): ClubDoc => ({
  tournaments: (file.tournaments ?? []).map(normalize),
  rejectedCandidates: [...(file.rejectedCandidates ?? [])],
  gameLimits: { ...gameLimits },
});
```

Delete `rewriteConfig`, `describe`, the `inline`/`block` helpers and their tests; update the file's top comment ("Edits to the club's tournament list (Firestore `config/club`), applied to the latest copy.").
- [ ] **Step 4: `site/src/lib/club/store.ts`:**

```ts
// Firebase client for /debug/'s club config. Access control lives in firestore.rules
// (config/club: public read, admin write).
import { onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { auth, db, signIn, signOutUser } from '../firebase';
import { applyOps, clubBody, type ClubDoc, type Op, type SeasonConfigFile } from '../config-edit';

export { signIn, signOutUser };

export type ClubAdmin = { uid: string; email: string; name: string; admin: boolean };

const clubRef = () => doc(db, 'config', 'club');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });

export function onClubUser(cb: (u: ClubAdmin | null | 'not-host') => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    if (!host?.exists()) return cb('not-host');
    cb({ uid: u.uid, email: u.email, name: String(host.data().name ?? u.email), admin: host.data().admin === true });
  });
}

export async function loadClub(): Promise<ClubDoc | null> {
  const snap = await getDoc(clubRef());
  if (!snap.exists()) return null;
  const d = snap.data();
  return { tournaments: d.tournaments ?? [], rejectedCandidates: d.rejectedCandidates ?? [], gameLimits: d.gameLimits ?? {} };
}

/** Applies [ops] to the current document and bumps meta/state so the site rebuilds. */
export async function saveClub(ops: Op[], u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    const snap = await tx.get(clubRef());
    if (!snap.exists()) throw new Error('config/club does not exist yet — import it first');
    const cur = snap.data() as ClubDoc;
    const next = applyOps({ tournaments: cur.tournaments ?? [], rejectedCandidates: cur.rejectedCandidates ?? [] }, ops);
    tx.set(clubRef(), { ...clubBody(next, cur.gameLimits ?? {}), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

/** One-time copy of the JSON config's tournament block into config/club. */
export async function importClub(file: SeasonConfigFile, u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    if ((await tx.get(clubRef())).exists()) throw new Error('config/club already exists');
    tx.set(clubRef(), { ...clubBody(file), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}
```

- [ ] **Step 5: Keep the build green.** `debug.ts` still imports `rewriteConfig`, `describe` and `../lib/github`. Remove those imports and, inside the commit handler's `try`, replace the GitHub loop with `throw new Error('Saving moves to Firestore in the next task');` (Task 4 rewrites the handler). Also drop `headSha`/`readFile` from `loadLive` by making it just `render();` for now. Then `npm run check && npm test` → PASS.
- [ ] **Step 6: Commit** `git add site/src && git commit -m "feat(site): config/club data layer; drop the GitHub config writer"`

---

### Task 4: `/debug/` signs in with Google and saves to Firestore

**Files:**
- Modify: `site/src/pages/debug/index.astro` (access panel, copy)
- Modify: `site/src/scripts/debug.ts`
- Modify: `lib/site_export/debug_export.dart` (`repo`: drop `files`) and `site/src/lib/types.ts` (`DebugData.repo`)

**Interfaces:**
- Consumes: Task 3's `club/store.ts` and `clubBody`.

- [ ] **Step 1: Page.** Replace the «GitHub access» `<details>` with:

```astro
  <div class="panel access" id="access">
    <span class="label">Editing</span> <span id="who" class="who">Read-only</span>
    <button type="button" id="sign-in" class="btn primary">Sign in with Google</button>
    <button type="button" id="sign-out" class="btn" hidden>Sign out</button>
    <button type="button" id="import" class="btn" hidden>Import from the config file</button>
    <p class="hint">Admins (hosts with <code>admin: true</code>) can save. Changes go to Firestore at once; the site rebuilds within an hour (or run the <a href={`https://github.com/${d.repo.owner}/${d.repo.name}/actions/workflows/web.yml`} target="_blank" rel="noopener">web workflow</a>).</p>
  </div>
```

Rename the pending bar's commit button text to `Save`. Update the page `description` to "Review the club's tournament list: confirm, fix or add tournaments."(unchanged) — fine as is.

- [ ] **Step 2: Script.** In `debug.ts`:
  - Remove the token storage (`TOKEN`, `token`, `login`, `refreshWho`, token form and forget listeners), the `../lib/github` import and `readFile`/`headSha`/`commitFiles` uses.
  - Import `{ importClub, loadClub, onClubUser, saveClub, signIn, signOutUser, type ClubAdmin }` from `'../lib/club/store'`.
  - State: `let user: ClubAdmin | null | 'not-host' = null; let clubMissing = false;`
  - `loadLive()`:

```ts
async function loadLive() {
  try {
    const club = await loadClub();
    clubMissing = club === null;
    live = club;
    $('live-state').textContent = club ? 'Live list from Firestore' : 'Not imported yet — showing the build\'s copy';
  } catch (e) {
    $('live-state').textContent = `Showing the build's copy (${(e as Error).message})`;
  }
  render();
}
```

  - `canSave = () => typeof user === 'object' && user !== null && user.admin;`
  - In `render()`: who text — `user === null ? 'Read-only' : user === 'not-host' ? 'Signed in, not a host — read-only' : user.admin ? `Saving as ${user.name}` : `${user.name} is not an admin — read-only``; `#sign-in` hidden when signed in, `#sign-out` hidden when not; `#import` visible only when `canSave() && clubMissing`; pending text suffix `canSave() ? '' : ' · sign in as an admin to save'`; commit disabled when `!canSave() || busy || clubMissing`.
  - Listeners: `#sign-in` → `signIn().catch((e) => { $('who').textContent = (e as Error).message; })`; `#sign-out` → `signOutUser()`; `onClubUser((u) => { user = u; render(); });`.
  - Import:

```ts
$('import').addEventListener('click', async () => {
  if (!canSave() || busy) return;
  busy = true; render();
  try {
    const raw = await fetch(`https://raw.githubusercontent.com/${repo.owner}/${repo.name}/${repo.branch}/remote_config.json`, { cache: 'no-store' });
    if (!raw.ok) throw new Error(`config file: HTTP ${raw.status}`);
    await importClub(await raw.json(), user as ClubAdmin);
    busy = false;
    await loadLive();
    $('live-state').textContent = 'Imported. The site rebuilds within an hour.';
  } catch (e) {
    busy = false; render();
    $('live-state').textContent = `Not imported: ${(e as Error).message}`;
  }
});
```

  - Commit handler body:

```ts
  if (!canSave() || busy || !ops.length) return;
  busy = true; render();
  $('pending-text').textContent = 'Saving…';
  try {
    await saveClub(ops, user as ClubAdmin);
    ops = []; saveOps();
    busy = false;
    await loadLive();
    $('live-state').textContent = 'Saved. The site rebuilds within an hour.';
  } catch (e) {
    busy = false; render();
    $('pending-text').textContent = `Not saved: ${(e as Error).message}`;
  }
```

  - Remove the final `refreshWho();` call; keep `render(); loadLive();`.
- [ ] **Step 3: Debug export / types.** `debug_export.dart` `repo` → `{'owner': 'Seezov', 'name': 'FamilyMafiaApp', 'branch': 'feature/flutter_migration'}`; `DebugData.repo` → `{ owner: string; name: string; branch: string }`. Remove `mainFile` from `debug.ts`.
- [ ] **Step 4: Verify.** `flutter test`; `cd site && npm run check && npm test && npm run build` → PASS (check-dist still allows only the Firebase web key). `grep -rn "github_pat\|commitFiles\|fm-debug-token" site/src` → nothing.
- [ ] **Step 5: Docs.** `CLAUDE.md` Web site section: replace the tournaments/Debug GitHub description with: "`/debug/` (admins, Google sign-in) edits Firestore `config/club` — tournaments, rejected candidates, final thresholds; read by the app over REST and by the build from `assets/prefetched/club_config.json`. Saves bump `meta/state`, so the site rebuilds within an hour."
- [ ] **Step 6: Commit** `git add site/src lib/site_export/debug_export.dart CLAUDE.md && git commit -m "feat(site): /debug/ edits config/club with Google sign-in"`

---

### Task 5: Rollout (controller, with the user)

Not for an implementer subagent. Each step that changes something outside the repo needs the user's go-ahead in chat.

- [ ] **Step 1:** Final whole-branch review passes; `flutter test`, rules tests, site tests and build green.
- [ ] **Step 2:** Publish `firestore.rules` in the Firebase console (owner authorized publishing rules from the console; verify the Rules tab shows the `config/club` block afterwards).
- [ ] **Step 3:** Push both branches (user says "пуш"); wait for the deploy.
- [ ] **Step 4:** An admin opens `/debug/`, signs in, clicks «Import from the config file». Verify in the console that `config/club` has the same number of tournaments as `remote_config.json`.
- [ ] **Step 5:** Remove the `"tournaments"` and `"rejectedCandidates"` blocks from `remote_config.json` and `assets/raw/season_config.json`; run `flutter test` (tests that read tournaments from the bundled config must now use a fixture or `ClubConfig` — fix them in this step); commit `chore: tournaments now live in Firestore config/club`; push both branches; verify the next deploy's `/tournaments/` lists the same entries.
- [ ] **Step 6:** Update memory (`familymafia-web-site.md`: Tournaments paragraph) and revise `docs/superpowers/plans/2026-10-05-dynamic-threshold.md` so the admin threshold reads/writes `config/club.gameLimits` (Task 5 of that plan becomes a `gameLimit` op in `applyOps`/`clubBody`, and `effectiveThreshold`'s `configured` comes from `clubConfigProvider`).
