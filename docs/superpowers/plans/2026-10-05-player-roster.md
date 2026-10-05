# Player Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the player list (`assets/raw/players.json`, sheet «Змінні» → «Гравці») into Firestore `config/players`, edited by admins on `/players/edit/`, read by the site build, the app and `/host/`.

**Architecture:** One Firestore document holds the ordered roster `{players: [{name, nicknames}]}`. A pure-Dart roster module validates it; prefetch snapshots it to `assets/prefetched/players.json` in the app's existing `players.json` shape, so the loader, resolver and export keep working unchanged; the app reads it live → cache → bundled. A TS roster module (same validation fixture) powers the editor's operations (add, nickname ±, rename, merge), saved in a transaction that also bumps `meta/state`.

**Tech Stack:** Dart/Flutter (Riverpod, Dio), Astro + TypeScript (vitest), Firebase JS SDK, Firestore rules (`@firebase/rules-unit-testing`).

**Spec:** `docs/superpowers/specs/2026-10-05-player-roster-design.md`

## Global Constraints

- Admin = `hosts/{email}.admin == true`; Google sign-in via `site/src/lib/club/store.ts` (`onClubUser`).
- Document `config/players`: keys exactly `players`, `updatedAt`, `updatedBy`, `updatedByEmail`; `players` a list of ≤ 2000 `{name: string, nicknames: string[]}`.
- Validation: no lower-cased name or nickname belongs to two different entries; a nickname equal to its own entry's name is allowed; ≤ 2000 entries; ≤ 50 nicknames per entry; junk names (`"/"`, `"17"`, blanks) are valid.
- Editor refuses a new name or nickname shorter than 2 characters after trim.
- Import drops an entry whose every name is already claimed by an earlier entry (today: second `Night`, second `Volus`).
- Rename keeps the old name as a nickname. Merge A → B: A's name + nicknames become B's nicknames, A is removed.
- Every save sets `meta/state.updatedAt`.
- App shape stays `[{id: 0, displayName, nicknames?}]`; `nicknames` is omitted when empty (the app hides players whose `nicknames` is an empty list).
- `tool/prefetch_seasons.dart` stays pure Dart (guarded by `test/tool/prefetch_pure_dart_test.dart`).
- Site copy on admin pages is English (like `/annual/edit/`, `/debug/`); `/host/` stays Ukrainian.
- Every Firestore value rendered into HTML goes through `esc`.

## Review Focus

1. Removing a player's last nickname → `nicknames: []` must not hide the player in the app/site (Task 1 test: `rosterAppJson` omits empty nicknames).
2. Two admins editing at once → ops identify players by name and are re-applied on the fresh document inside the transaction (Task 7 test: ops by name after the list shifted).
3. Renaming to a case variant or to one's own nickname (`rathma` → `Rathma`, `Скай` → own nickname) must be allowed (Task 7 tests).
4. Merging two players that both have a profile → one profile wins (the one whose `player` is the display name), the other is a build warning, never a crash (Task 6 test).
5. A malformed `config/players` (entry without a string `name`) → the build fails naming the problem; the app keeps its cached copy (Task 3 + Task 4 tests).

---

### Task 1: Pure-Dart roster model and validation

**Files:**
- Create: `lib/models/roster.dart`
- Create: `test/fixtures/roster_cases.json`
- Test: `test/models/roster_test.dart`

**Interfaces:**
- Produces:
  - `class RosterEntry { const RosterEntry(String name, [List<String> nicknames]); final String name; final List<String> nicknames; Iterable<String> get names; }`
  - `const kMaxRosterEntries = 2000; const kMaxNicknames = 50;`
  - `List<RosterEntry> parseRoster(Object? players)` — throws `FormatException('roster: …')`
  - `List<String> rosterClashes(List<RosterEntry> roster)` — sorted lower-cased names owned by two entries
  - `void checkRoster(List<RosterEntry> roster)` — throws `FormatException` on clashes/limits
  - `List<RosterEntry> dedupeRoster(List<RosterEntry> roster)`
  - `List<RosterEntry> rosterFromAppJson(String json)` / `String rosterAppJson(List<RosterEntry> roster)`

- [ ] **Step 1: Write the shared fixture** `test/fixtures/roster_cases.json`

```json
[
  {"case": "valid with own name as nickname", "roster": [{"name": "Anatolich", "nicknames": ["Anatolich", "Анатоліч"]}, {"name": "Braun", "nicknames": []}], "clashes": []},
  {"case": "nickname is another player's name", "roster": [{"name": "A", "nicknames": ["Bee"]}, {"name": "bee", "nicknames": []}], "clashes": ["bee"]},
  {"case": "same name twice", "roster": [{"name": "Night", "nicknames": []}, {"name": "Night", "nicknames": []}], "clashes": ["night"]},
  {"case": "junk names are valid", "roster": [{"name": "/", "nicknames": []}, {"name": "", "nicknames": []}, {"name": " ", "nicknames": []}], "clashes": []},
  {"case": "cyrillic case-insensitive", "roster": [{"name": "Аглая", "nicknames": []}, {"name": "X", "nicknames": ["аГЛАЯ"]}], "clashes": ["аглая"]},
  {"case": "two clashes sorted", "roster": [{"name": "Volus", "nicknames": ["Zed"]}, {"name": "volus", "nicknames": []}, {"name": "zed", "nicknames": []}], "clashes": ["volus", "zed"]}
]
```

- [ ] **Step 2: Write the failing test** `test/models/roster_test.dart`

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/roster.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

List<RosterEntry> _fromCase(List<dynamic> r) => parseRoster(r);

void main() {
  final cases = (jsonDecode(File('test/fixtures/roster_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('clashes match every shared case (same fixture as the TS test)', () {
    for (final c in cases) {
      expect(rosterClashes(_fromCase(c['roster'] as List)), c['clashes'], reason: c['case'] as String);
    }
  });

  test('parseRoster rejects malformed entries', () {
    expect(() => parseRoster('x'), throwsFormatException);
    expect(() => parseRoster([{'nicknames': []}]), throwsFormatException);
    expect(() => parseRoster([{'name': 'A', 'nicknames': [1]}]), throwsFormatException);
    expect(parseRoster([{'name': 'A'}]).single.nicknames, isEmpty);
  });

  test('checkRoster: clashes and limits', () {
    expect(() => checkRoster(_fromCase(cases[1]['roster'] as List)), throwsA(isA<FormatException>()
        .having((e) => e.message, 'message', contains('bee'))));
    expect(() => checkRoster(List.generate(kMaxRosterEntries + 1, (i) => RosterEntry('p$i'))), throwsFormatException);
    expect(() => checkRoster([RosterEntry('A', List.generate(kMaxNicknames + 1, (i) => 'n$i'))]), throwsFormatException);
    checkRoster(_fromCase(cases[0]['roster'] as List));
  });

  test('rosterAppJson omits empty nicknames and keeps order', () {
    final json = rosterAppJson([const RosterEntry('A'), const RosterEntry('B', ['b2'])]);
    expect(jsonDecode(json), [
      {'id': 0, 'displayName': 'A'},
      {'id': 0, 'displayName': 'B', 'nicknames': ['b2']},
    ]);
  });

  group('the real assets/raw/players.json', () {
    final raw = File('assets/raw/players.json').readAsStringSync();
    final roster = rosterFromAppJson(raw);

    test('only Night and Volus clash, and dedupe removes exactly their second entries', () {
      expect(rosterClashes(roster), ['night', 'volus']);
      final deduped = dedupeRoster(roster);
      expect(roster.length - deduped.length, 2);
      expect(rosterClashes(deduped), isEmpty);
      checkRoster(deduped);
    });

    test('the deduped roster resolves every name exactly like the file', () {
      List<Player> players(String json) => [
            for (final (i, m) in (jsonDecode(json) as List).cast<Map<String, dynamic>>().indexed)
              Player.fromJson(m).copyWith(id: i)
          ];
      final before = PlayerResolver(players(raw));
      final after = PlayerResolver(players(rosterAppJson(dedupeRoster(roster))));
      for (final e in roster) {
        for (final n in e.names) {
          expect(after.resolve(n).displayName, before.resolve(n).displayName, reason: n);
        }
      }
    });
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/models/roster_test.dart`
Expected: FAIL — `roster.dart` does not exist.

- [ ] **Step 4: Implement** `lib/models/roster.dart`

```dart
import 'dart:convert';

/// The club's player list as stored in Firestore `config/players`: ordered
/// (the app numbers players by position), each a display name plus the other
/// spellings games use. Pure Dart: the CI prefetch imports it.
class RosterEntry {
  const RosterEntry(this.name, [this.nicknames = const []]);

  final String name;
  final List<String> nicknames;

  Iterable<String> get names => [name, ...nicknames];
}

const kMaxRosterEntries = 2000;
const kMaxNicknames = 50;

/// Reads the `players` field. Throws [FormatException] on anything but a list
/// of `{name: string, nicknames?: [string]}`.
List<RosterEntry> parseRoster(Object? players) {
  if (players is! List) throw const FormatException('roster: players is not a list');
  return [
    for (final (i, p) in players.indexed)
      if (p is Map && p['name'] is String)
        RosterEntry(p['name'] as String, switch (p['nicknames']) {
          null => const [],
          final List l when l.every((n) => n is String) => l.cast<String>().toList(),
          _ => throw FormatException('roster: entry $i (${p['name']}) has a bad nicknames list'),
        })
      else
        throw FormatException('roster: entry $i has no string name'),
  ];
}

/// Lower-cased names or nicknames owned by more than one entry, sorted.
List<String> rosterClashes(List<RosterEntry> roster) {
  final owner = <String, int>{};
  final clashes = <String>{};
  for (final (i, e) in roster.indexed) {
    for (final n in e.names) {
      final k = n.toLowerCase();
      if (owner.putIfAbsent(k, () => i) != i) clashes.add(k);
    }
  }
  return clashes.toList()..sort();
}

void checkRoster(List<RosterEntry> roster) {
  if (roster.length > kMaxRosterEntries) {
    throw FormatException('roster: ${roster.length} players, the limit is $kMaxRosterEntries');
  }
  for (final e in roster) {
    if (e.nicknames.length > kMaxNicknames) {
      throw FormatException('roster: ${e.name} has ${e.nicknames.length} nicknames, the limit is $kMaxNicknames');
    }
  }
  final clashes = rosterClashes(roster);
  if (clashes.isNotEmpty) {
    throw FormatException('roster: names used by two players: ${clashes.join(', ')}');
  }
}

/// Drops every entry whose names are all claimed by earlier entries — the
/// resolver never reaches it, so stats do not change.
List<RosterEntry> dedupeRoster(List<RosterEntry> roster) {
  final seen = <String>{};
  final out = <RosterEntry>[];
  for (final e in roster) {
    final keys = e.names.map((n) => n.toLowerCase()).toList();
    if (keys.every(seen.contains)) continue;
    seen.addAll(keys);
    out.add(e);
  }
  return out;
}

List<RosterEntry> rosterFromAppJson(String json) => [
      for (final p in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        RosterEntry(p['displayName'] as String, (p['nicknames'] as List?)?.cast<String>() ?? const []),
    ];

/// The app's `players.json` shape. Empty nickname lists are left out: the app
/// hides a player whose `nicknames` is an empty list.
String rosterAppJson(List<RosterEntry> roster) => jsonEncode([
      for (final e in roster)
        {'id': 0, 'displayName': e.name, if (e.nicknames.isNotEmpty) 'nicknames': e.nicknames},
    ]);
```

- [ ] **Step 5: Run it to verify it passes**

Run: `flutter test test/models/roster_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/models/roster.dart test/models/roster_test.dart test/fixtures/roster_cases.json
git commit -m "feat: pure-Dart player roster model and validation"
```

---

### Task 2: Firestore rules for `config/players`

**Files:**
- Modify: `firestore.rules` (after the `match /config/club` block)
- Test: `firebase/rules-test/rules.test.ts` (new `describe('config/players')`)

**Interfaces:**
- Produces: rules that Task 8's `saveRosterOp`/`importRoster` writes satisfy: `{players, updatedAt: serverTimestamp(), updatedBy: uid, updatedByEmail: email}`.

- [ ] **Step 1: Write the failing tests** (append to `rules.test.ts`)

```ts
describe('config/players', () => {
  const ref = (db: ReturnType<typeof as>) => doc(db, 'config', 'players');
  const body = (u: User, extra: Record<string, unknown> = {}) => ({
    players: [{ name: 'Braun', nicknames: ['Браун'] }], updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email, ...extra,
  });
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'players')));
  });
  it('an admin can create and update', async () => {
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN, { players: [] })));
  });
  it('a host who is not admin cannot write', async () => {
    await assertFails(setDoc(ref(as(HOST)), body(HOST)));
  });
  it('a guest cannot write', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'players'), body(ADMIN)));
  });
  it('rejects extra keys, a non-list, a forged author and a client timestamp', async () => {
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { extra: 1 })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { players: 'x' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedBy: 'someone' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedByEmail: 'x@x.com' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedAt: new Date(0) })));
  });
  it('rejects more than 2000 players', async () => {
    const players = Array.from({ length: 2001 }, (_, i) => ({ name: `p${i}`, nicknames: [] }));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { players })));
  });
  it('nobody can delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'players'), { players: [] }));
    await assertFails(deleteDoc(ref(as(ADMIN))));
  });
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test`
Expected: FAIL — `an admin can create and update` (no rule matches `config/players`); the deny tests pass already.

- [ ] **Step 3: Add the rule** to `firestore.rules`, right after `match /config/club { … }`

```
    // The club's player list (names + nicknames), edited on /players/edit/. Entry contents
    // are checked by the build and the editor (rules cannot loop over a list).
    match /config/players {
      allow read: if true;
      allow create, update: if isAdmin()
        && request.resource.data.keys().hasOnly(['players', 'updatedAt', 'updatedBy', 'updatedByEmail'])
        && request.resource.data.players is list
        && request.resource.data.players.size() <= 2000
        && request.resource.data.updatedAt == request.time
        && request.resource.data.updatedBy == request.auth.uid
        && request.resource.data.updatedByEmail == email();
      allow delete: if false;
    }
```

- [ ] **Step 4: Run them to verify they pass**

Run: same as Step 2.
Expected: PASS — all previous tests (55) plus 7 new.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firebase/rules-test/rules.test.ts
git commit -m "feat: firestore rules for config/players"
```

---

### Task 3: Fetch and prefetch the roster

**Files:**
- Modify: `lib/services/prefetch_paths.dart`, `lib/services/firestore_service.dart`, `tool/prefetch_seasons.dart`
- Test: `test/services/firestore_service_players_test.dart`, `test/tool/prefetch_seasons_test.dart`

**Interfaces:**
- Consumes: Task 1 `parseRoster`, `checkRoster`, `rosterAppJson`.
- Produces: `const String prefetchedPlayersFile = 'players.json';`; `Future<String?> FirestoreService.fetchPlayers(String projectId)` — app-shape JSON, null when the document does not exist, `FormatException` when malformed.

- [ ] **Step 1: Write the failing service test** `test/services/firestore_service_players_test.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.status, this.body);
  final int status;
  final Object body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

FirestoreService _svc(int status, Object body) => FirestoreService(dio: Dio()..httpClientAdapter = _Fake(status, body));

Map<String, dynamic> _entry(Map<String, dynamic> name, [List<String> nicks = const []]) => {
      'mapValue': {'fields': {
        'name': name,
        'nicknames': {'arrayValue': {'values': [for (final n in nicks) {'stringValue': n}]}},
      }},
    };

void main() {
  test('returns the app players.json shape, empty nicknames left out', () async {
    final json = await _svc(200, {'fields': {
      'players': {'arrayValue': {'values': [
        _entry({'stringValue': 'Braun'}, ['Браун']),
        _entry({'stringValue': 'Joi'}),
      ]}},
      'updatedByEmail': {'stringValue': 'a@x.com'},
    }}).fetchPlayers('p');
    expect(jsonDecode(json!), [
      {'id': 0, 'displayName': 'Braun', 'nicknames': ['Браун']},
      {'id': 0, 'displayName': 'Joi'},
    ]);
  });

  test('a missing document is null', () async {
    expect(await _svc(404, {'error': {'code': 404}}).fetchPlayers('p'), isNull);
  });

  test('a malformed entry or a clash throws FormatException', () async {
    await expectLater(_svc(200, {'fields': {'players': {'arrayValue': {'values': [
      _entry({'integerValue': '1'}),
    ]}}}}).fetchPlayers('p'), throwsFormatException);
    await expectLater(_svc(200, {'fields': {'players': {'arrayValue': {'values': [
      _entry({'stringValue': 'A'}, ['b']), _entry({'stringValue': 'B'}),
    ]}}}}).fetchPlayers('p'), throwsFormatException);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/services/firestore_service_players_test.dart`
Expected: FAIL — `fetchPlayers` is not defined.

- [ ] **Step 3: Implement**

`lib/services/prefetch_paths.dart` — append:

```dart
/// Firestore `config/players` (the roster), in the app's players.json shape.
const String prefetchedPlayersFile = 'players.json';
```

`lib/services/firestore_service.dart` — add `import 'package:family_mafia_app/models/roster.dart';` and this method after `fetchClubConfig`:

```dart
  /// `config/players` in the app's `players.json` shape, or null when the
  /// document doesn't exist yet. Throws [FormatException] when it is
  /// malformed or two players share a name, so the build fails loudly.
  Future<String?> fetchPlayers(String projectId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '$projectId/databases/(default)/documents/config/players');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final fields = decodeFirestoreFields(
          response.data?['fields'] as Map<String, dynamic>? ?? const {});
      final roster = parseRoster(fields['players']);
      checkRoster(roster);
      return rosterAppJson(roster);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/services/firestore_service_players_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing prefetch tests** — in `test/tool/prefetch_seasons_test.dart`, add an optional `Object? players` parameter to the fake router used by the existing tests (next to `events`) with the route `if (uri.path.endsWith('/documents/config/players')) return players == null ? _body('{}', 404) : _body(jsonEncode(players));` placed before the final 404, then add:

```dart
  test('writes the roster snapshot when config/players exists', () async {
    final dir = await Directory.systemTemp.createTemp('prefetch');
    addTearDown(() => dir.delete(recursive: true));
    await prefetchSeasons(
      dio: _dio(players: {'fields': {'players': {'arrayValue': {'values': [
        {'mapValue': {'fields': {'name': {'stringValue': 'Braun'}}}},
      ]}}}}),
      apiKey: 'k', configUrl: 'https://config.test/c.json', outDir: dir);
    expect(jsonDecode(File('${dir.path}/players.json').readAsStringSync()),
        [{'id': 0, 'displayName': 'Braun'}]);
  });

  test('no config/players: no roster snapshot, the bundled file is used', () async {
    final dir = await Directory.systemTemp.createTemp('prefetch');
    addTearDown(() => dir.delete(recursive: true));
    await prefetchSeasons(dio: _dio(), apiKey: 'k', configUrl: 'https://config.test/c.json', outDir: dir);
    expect(File('${dir.path}/players.json').existsSync(), isFalse);
  });

  test('a malformed roster fails the prefetch and writes nothing', () async {
    final dir = Directory('${Directory.systemTemp.path}/prefetch-bad-roster');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    await expectLater(
      prefetchSeasons(
        dio: _dio(players: {'fields': {'players': {'stringValue': 'x'}}}),
        apiKey: 'k', configUrl: 'https://config.test/c.json', outDir: dir),
      throwsFormatException);
    expect(dir.existsSync(), isFalse);
  });
```

(Use the file's existing helper names for building the Dio and config; if the existing helper is not called `_dio`, add the `players` parameter to whichever helper builds the fake adapter and call that.)

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/tool/prefetch_seasons_test.dart`
Expected: FAIL — `players.json` not written.

- [ ] **Step 7: Implement** in `tool/prefetch_seasons.dart`, after `final annualEvents = …`:

```dart
  // Validated inside fetchPlayers; null until the roster is imported.
  final players = await firestore.fetchPlayers(kFirebaseProjectId);
```

and after writing `annualEvents`:

```dart
  if (players != null) {
    await File('${outDir.path}/$prefetchedPlayersFile').writeAsString(players);
  }
```

Update the file's header comment: `// Snapshots the remote config, Firestore config/club, config/players and events, …`.

- [ ] **Step 8: Run to verify it passes, plus the pure-Dart guard**

Run: `flutter test test/tool/`
Expected: PASS (all prefetch tests and `prefetch_pure_dart_test`).

- [ ] **Step 9: Commit**

```bash
git add lib/services/prefetch_paths.dart lib/services/firestore_service.dart tool/prefetch_seasons.dart test/services/firestore_service_players_test.dart test/tool/prefetch_seasons_test.dart
git commit -m "feat: fetch config/players and snapshot it in the prefetch"
```

---

### Task 4: The app and the export read the roster

**Files:**
- Modify: `lib/services/season_cache_service.dart`, `lib/services/asset_season_cache_service.dart`, `lib/services/io_season_cache_service.dart`, `lib/providers/app_providers.dart`
- Modify (fakes): `test/providers/club_config_provider_test.dart`, `test/services/firestore_service_test.dart`
- Test: `test/providers/players_json_provider_test.dart`

**Interfaces:**
- Consumes: Task 3 `fetchPlayers`, `prefetchedPlayersFile`.
- Produces: `SeasonCacheService.getCachedPlayers()` / `cachePlayers(String)`; `final playersJsonProvider = FutureProvider<String>(…)` in `app_providers.dart`.

- [ ] **Step 1: Write the failing test** `test/providers/players_json_provider_test.dart`

```dart
import 'package:dio/dio.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemCache implements SeasonCacheService {
  String? players;
  @override Future<String?> getCachedSeasonData(int id) async => null;
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async {}
  @override Future<void> invalidateSeasonCache(int id) async {}
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => null;
  @override Future<void> cacheClubConfig(String json) async {}
  @override Future<String?> getCachedPlayers() async => players;
  @override Future<void> cachePlayers(String json) async => players = json;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore(this.result) : super(dio: Dio());
  final Future<String?> Function() result;
  @override
  Future<String?> fetchPlayers(String projectId) => result();
}

const _live = '[{"id":0,"displayName":"Live"}]';
const _cached = '[{"id":0,"displayName":"Cached"}]';

ProviderContainer _container(_MemCache cache, FirestoreService? firestore) {
  final c = ProviderContainer(overrides: [
    seasonCacheServiceProvider.overrideWithValue(cache),
    firestoreServiceProvider.overrideWithValue(firestore),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the live roster wins and is cached', () async {
    final cache = _MemCache();
    final json = await _container(cache, _FakeFirestore(() async => _live)).read(playersJsonProvider.future);
    expect(json, _live);
    expect(cache.players, _live);
  });

  test('a failed or malformed fetch falls back to the cached copy', () async {
    final cache = _MemCache()..players = _cached;
    final c = _container(cache, _FakeFirestore(() async => throw const FormatException('roster: bad')));
    expect(await c.read(playersJsonProvider.future), _cached);
    expect(cache.players, _cached);
  });

  test('no live document and no cache: the bundled players.json', () async {
    final c = _container(_MemCache(), _FakeFirestore(() async => null));
    expect(await c.read(playersJsonProvider.future), contains('"displayName": "Anatolich"'));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/providers/players_json_provider_test.dart`
Expected: FAIL — `getCachedPlayers` / `playersJsonProvider` not defined.

- [ ] **Step 3: Implement**

`season_cache_service.dart` — add to the interface:

```dart
  /// The last fetched Firestore `config/players`, app players.json shape.
  Future<String?> getCachedPlayers();

  Future<void> cachePlayers(String jsonData);
```

`asset_season_cache_service.dart` — add:

```dart
  @override
  Future<String?> getCachedPlayers() => _tryLoad(prefetchedPlayersFile);

  @override
  Future<void> cachePlayers(String jsonData) async {}
```

`io_season_cache_service.dart` — add after the club config section:

```dart
  // ── Roster cache ────────────────────────────────────────────────────────

  @override
  Future<String?> getCachedPlayers() async {
    final dir = await _getCacheDir();
    final file = File('$dir/players.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  @override
  Future<void> cachePlayers(String jsonData) async {
    final dir = await _getCacheDir();
    await File('$dir/players.json').writeAsString(jsonData);
  }
```

Both existing test fakes (`_MemCache` in `test/providers/club_config_provider_test.dart` and `test/services/firestore_service_test.dart`) gain:

```dart
  @override Future<String?> getCachedPlayers() async => null;
  @override Future<void> cachePlayers(String json) async {}
```

`app_providers.dart` — add after `clubConfigProvider`:

```dart
/// The roster for the loader (app players.json shape): Firestore
/// `config/players` live, else the cached copy (the build's snapshot on the
/// web and in the site export), else the bundled `assets/raw/players.json`.
final playersJsonProvider = FutureProvider<String>((ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  if (firestore != null) {
    try {
      // fetchPlayers validates, so a document Dart can't use never reaches the cache.
      final json = await firestore.fetchPlayers(kFirebaseProjectId);
      if (json != null) {
        await cache.cachePlayers(json);
        return json;
      }
    } catch (e) {
      debugPrint('Players fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedPlayers();
    if (cached != null) return cached;
  } catch (e) {
    debugPrint('Cached players unavailable: $e');
  }
  return rootBundle.loadString('assets/raw/players.json');
});
```

and in `initialLoadProvider` replace
`final playersJson = await rootBundle.loadString('assets/raw/players.json');` with
`final playersJson = await ref.read(playersJsonProvider.future);`.

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/providers/`
Expected: PASS (new 3 + existing club config tests).

- [ ] **Step 5: Full Dart suite**

Run: `flutter test > /tmp/roster-t4.log 2>&1; tail -3 /tmp/roster-t4.log`
Expected: `All tests passed!`

- [ ] **Step 6: Commit**

```bash
git add lib/services/season_cache_service.dart lib/services/asset_season_cache_service.dart lib/services/io_season_cache_service.dart lib/providers/app_providers.dart test/providers/players_json_provider_test.dart test/providers/club_config_provider_test.dart test/services/firestore_service_test.dart
git commit -m "feat: app and export read the roster live, cached or bundled"
```

---

### Task 5: Export aliases and unresolved names

**Files:**
- Create: `lib/site_export/unresolved_export.dart`
- Modify: `lib/site_export/players_export.dart` (`_summary`), `lib/site_export/site_exporter.dart`, `site/src/lib/types.ts`, `site/src/lib/data.ts`
- Test: `test/site_export/unresolved_export_test.dart`

**Interfaces:**
- Produces:
  - `List<Map<String, Object>> unresolvedNames(Iterable<Game> games, PlayerResolver resolver)` → `[{name, games, lastSeason}]`, most games first, then name.
  - `site/data/unresolved.json` = `{names: [{name, games, lastSeason}]}`.
  - `site/data/players.json` players gain `aliases: string[]` (lower-cased display name + nicknames, no duplicates).
  - TS: `PlayerSummary.aliases: string[]`; `UnresolvedData`; `loadUnresolved()`.

- [ ] **Step 1: Write the failing test** `test/site_export/unresolved_export_test.dart`

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/unresolved_export.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(int season, List<String> players) => Game(
      seasonId: season, players: players, roles: List.filled(players.length, 'Мирний'),
      firstKilled: 0, bestMovePoints: 0, bestMove: const []);

void main() {
  test('lists names no player owns, junk and placeholders left out', () {
    final resolver = PlayerResolver(const [Player(id: 0, displayName: 'Braun', nicknames: ['Браун'])]);
    final out = unresolvedNames([
      _g(30, ['Braun', 'Новенький', '_blank_3', '17', '/']),
      _g(31, ['Новенький', 'Гість', 'x']),
    ], resolver);
    expect(out, [
      {'name': 'Новенький', 'games': 2, 'lastSeason': 31},
      {'name': 'Гість', 'games': 1, 'lastSeason': 31},
    ]);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/site_export/unresolved_export_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement** `lib/site_export/unresolved_export.dart`

```dart
import 'dart:math';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';

/// Digits/slashes/dots only, as filtered on /host/.
final _junk = RegExp(r'^[\d/\\.]+$');

/// Game names that resolve to no roster entry, for /players/edit/. The
/// loader has already replaced every resolved name with its display name.
List<Map<String, Object>> unresolvedNames(Iterable<Game> games, PlayerResolver resolver) {
  final count = <String, int>{};
  final last = <String, int>{};
  for (final g in games) {
    for (final raw in g.players) {
      final n = raw.trim();
      if (n.length < 2 || n.startsWith('_blank_') || _junk.hasMatch(n)) continue;
      if (resolver.resolve(n).id >= 0) continue;
      count[n] = (count[n] ?? 0) + 1;
      last[n] = max(last[n] ?? 0, g.seasonId);
    }
  }
  final names = count.keys.toList()
    ..sort((a, b) => count[b]!.compareTo(count[a]!) != 0 ? count[b]!.compareTo(count[a]!) : a.compareTo(b));
  return [for (final n in names) {'name': n, 'games': count[n]!, 'lastSeason': last[n]!}];
}

Map<String, Object?> unresolvedJson(ExportContext x) => {
      'names': unresolvedNames(x.read(gamesRepositoryProvider), x.read(playerResolverProvider)),
    };
```

`players_export.dart` `_summary` — add after `'name': p.displayName,`:

```dart
    // Every spelling that resolves to this player, for the profile matcher.
    'aliases': {for (final n in [p.displayName, ...?p.nicknames]) n.trim().toLowerCase()}.toList(),
```

`site_exporter.dart` — import `unresolved_export.dart`; after `write('players.json', playersJson(x));` add `write('unresolved.json', unresolvedJson(x));`.

`site/src/lib/types.ts` — `PlayerSummary` gains `aliases: string[];` and add:

```ts
export interface UnresolvedData { names: { name: string; games: number; lastSeason: number }[] }
```

`site/src/lib/data.ts` — import `UnresolvedData`; add `export const loadUnresolved = () => read<UnresolvedData>('unresolved.json');`.

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/site_export/`
Expected: PASS.

- [ ] **Step 5: Export locally and check the files**

Run: `flutter test tool/export_site_data_test.dart > /tmp/roster-export.log 2>&1; tail -2 /tmp/roster-export.log; node -e "const d=require('./site/data/unresolved.json');console.log(d.names.length, d.names.slice(0,5)); const p=require('./site/data/players.json').players.find(x=>x.name==='Anatolich');console.log(p.aliases)"`
Expected: `All tests passed!`; a short list of unresolved names; `[ 'anatolich', 'анатоліч' ]`.

- [ ] **Step 6: Commit**

```bash
git add lib/site_export/unresolved_export.dart lib/site_export/players_export.dart lib/site_export/site_exporter.dart site/src/lib/types.ts site/src/lib/data.ts test/site_export/unresolved_export_test.dart
git commit -m "feat: export player aliases and unresolved game names"
```

---

### Task 6: Profiles follow renames and merges

**Files:**
- Modify: `site/src/lib/profiles/build.ts` (`selectProfiles`), `site/scripts/fetch-profiles.ts`
- Test: `site/src/lib/profiles/build.test.ts`

**Interfaces:**
- Consumes: Task 5 `aliases` in `site/data/players.json`.
- Produces: `selectProfiles(names: string[], docs: RestProfile[], aliases: Record<string, string> = {})` — `aliases` maps a lower-cased old spelling to the current display name. Output keys stay `playerKey(display name)`.

- [ ] **Step 1: Write the failing tests** (append inside `describe('selectProfiles', …)`)

```ts
  it('a profile made under an old name follows the rename', () => {
    const out = selectProfiles(['Rathma'], [{ id: playerKey('Скай'), player: 'Скай', nick: 'Sky' }], { 'скай': 'Rathma' });
    expect(out.profiles[playerKey('Rathma')]).toEqual({ nick: 'Sky' });
  });
  it('two profiles on one player after a merge: the display-name one wins, the other warns', () => {
    const out = selectProfiles(['Braun'], [
      { id: playerKey('Браун'), player: 'Браун', nick: 'Old' },
      { id: playerKey('Braun'), player: 'Braun', nick: 'New' },
    ], { 'браун': 'Braun' });
    expect(out.profiles.braun).toEqual({ nick: 'New' });
    expect(out.warnings.some((w) => w.includes('Браун'))).toBe(true);
  });
  it('the document id must still be the key of the name it was made for', () => {
    const out = selectProfiles(['Rathma'], [{ id: playerKey('Rathma'), player: 'Скай', nick: 'Sky' }], { 'скай': 'Rathma' });
    expect(out.profiles).toEqual({});
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd site && npx vitest run src/lib/profiles/build.test.ts`
Expected: FAIL — the first two new tests.

- [ ] **Step 3: Implement** — in `selectProfiles`, replace the head of the function up to and including the `if (d.id !== key …) { … continue; }` block with:

```ts
export function selectProfiles(names: string[], docs: RestProfile[], aliases: Record<string, string> = {}) {
  const byKey = new Map(names.map((n) => [playerKey(n), n]));
  // An old spelling (renamed or merged player) → the player's current name.
  const owner = (player: string) => byKey.get(playerKey(player)) ?? aliases[player.trim().toLowerCase()];
  const profiles: Record<string, SiteProfile> = {};
  const files: { path: string; bytes: Uint8Array }[] = [];
  const warnings: string[] = [];
  const taken = new Set(names.map((n) => n.trim().toLowerCase()));
  const used = new Map<string, string>();
  // A profile made under the display name first, then code-point order, so the
  // winner is deterministic on every machine.
  const exact = (d: RestProfile) => (byKey.has(playerKey(d.player)) ? 0 : 1);
  const sorted = [...docs].sort((a, b) => exact(a) - exact(b) || (playerKey(a.player) < playerKey(b.player) ? -1 : 1));
  for (const d of sorted) {
    const name = owner(d.player);
    if (!name) continue;
    // The id comes from the claim the admin approved; only the key of the name it was made for is trusted.
    const docKey = playerKey(d.player);
    if (d.id !== docKey && safeDecode(d.id) !== docKey) {
      warnings.push(`profile ${name}: ignored — document id "${d.id}" is not this player's key`);
      continue;
    }
    const key = playerKey(name);
    if (used.has(key)) {
      warnings.push(`profile ${d.player}: ignored — ${name} already has the profile made for "${used.get(key)}"`);
      continue;
    }
    used.set(key, d.player);
```

(the rest of the loop body is unchanged and keeps writing `profiles[key]`).

In `site/scripts/fetch-profiles.ts` replace the players read and the call with:

```ts
    const { players } = JSON.parse(fs.readFileSync(path.join(opts.dataDir, 'players.json'), 'utf8')) as { players: { name: string; aliases?: string[] }[] };
    const aliases: Record<string, string> = {};
    for (const p of players) for (const a of p.aliases ?? []) aliases[a] ??= p.name;
    const { profiles, files, warnings } = selectProfiles(players.map((p) => p.name), docs, aliases);
```

- [ ] **Step 4: Run them to verify they pass**

Run: `cd site && npx vitest run src/lib/profiles scripts`
Expected: PASS (existing profile and fetch-profiles tests included).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/profiles/build.ts site/src/lib/profiles/build.test.ts site/scripts/fetch-profiles.ts
git commit -m "feat: profiles follow renamed and merged players"
```

---

### Task 7: TS roster operations

**Files:**
- Create: `site/src/lib/roster/roster.ts`
- Test: `site/src/lib/roster/roster.test.ts`

**Interfaces:**
- Consumes: Task 1 fixture `test/fixtures/roster_cases.json`.
- Produces:
  - `interface RosterEntry { name: string; nicknames: string[] }`
  - `rosterClashes(r): string[]`, `rosterErrors(r): string[]`, `dedupeRoster(r)`, `fromAppJson(list)`
  - `type RosterOp = { kind: 'add'; name: string } | { kind: 'nick-add'; player: string; nick: string } | { kind: 'nick-remove'; player: string; nick: string } | { kind: 'rename'; player: string; to: string } | { kind: 'merge'; from: string; into: string }`
  - `applyOp(r: RosterEntry[], op: RosterOp): RosterEntry[]` — throws `Error` with an English message
  - `autocompleteNames(r): string[]`, `aliasPairs(r): [string, string][]`, `ownerOf(r, name): string | undefined`

- [ ] **Step 1: Write the failing test** `site/src/lib/roster/roster.test.ts`

```ts
import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { aliasPairs, applyOp, autocompleteNames, dedupeRoster, fromAppJson, ownerOf, rosterClashes, rosterErrors, type RosterEntry } from './roster';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/roster_cases.json', import.meta.url), 'utf8')) as
  { case: string; roster: RosterEntry[]; clashes: string[] }[];
const R = (): RosterEntry[] => [
  { name: 'Rathma', nicknames: ['Скай'] },
  { name: 'Braun', nicknames: [] },
  { name: 'Joi', nicknames: ['Фантазер'] },
];

describe('validation', () => {
  it('matches every shared case (same fixture as the Dart test)', () => {
    for (const c of cases) expect(rosterClashes(c.roster), c.case).toEqual(c.clashes);
  });
  it('limits', () => {
    expect(rosterErrors(Array.from({ length: 2001 }, (_, i) => ({ name: `p${i}`, nicknames: [] })))).toHaveLength(1);
    expect(rosterErrors([{ name: 'A', nicknames: Array.from({ length: 51 }, (_, i) => `n${i}`) }])).toHaveLength(1);
    expect(rosterErrors(R())).toEqual([]);
  });
  it('the real players.json: dedupe removes the second Night and Volus only', () => {
    const raw = JSON.parse(fs.readFileSync(new URL('../../../../assets/raw/players.json', import.meta.url), 'utf8'));
    const r = fromAppJson(raw);
    expect(rosterClashes(r)).toEqual(['night', 'volus']);
    const d = dedupeRoster(r);
    expect(r.length - d.length).toBe(2);
    expect(rosterErrors(d)).toEqual([]);
  });
});

describe('applyOp', () => {
  it('add appends; refuses a taken or too short name', () => {
    expect(applyOp(R(), { kind: 'add', name: '  Новенький ' }).at(-1)).toEqual({ name: 'Новенький', nicknames: [] });
    expect(() => applyOp(R(), { kind: 'add', name: 'скай' })).toThrow(/Rathma/);
    expect(() => applyOp(R(), { kind: 'add', name: 'X' })).toThrow(/2 characters/);
  });
  it('nickname add and remove', () => {
    const r = applyOp(R(), { kind: 'nick-add', player: 'Braun', nick: 'Браун' });
    expect(r[1].nicknames).toEqual(['Браун']);
    expect(() => applyOp(r, { kind: 'nick-add', player: 'Joi', nick: 'браун' })).toThrow(/Braun/);
    expect(applyOp(r, { kind: 'nick-remove', player: 'Braun', nick: 'Браун' })[1].nicknames).toEqual([]);
  });
  it('rename keeps the old name as a nickname', () => {
    const r = applyOp(R(), { kind: 'rename', player: 'Braun', to: 'Браун' });
    expect(r[1]).toEqual({ name: 'Браун', nicknames: ['Braun'] });
  });
  it('rename to a case variant or to an own nickname is allowed', () => {
    expect(applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'RATHMA' })[0]).toEqual({ name: 'RATHMA', nicknames: ['Скай'] });
    expect(applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'Скай' })[0]).toEqual({ name: 'Скай', nicknames: ['Rathma'] });
    expect(() => applyOp(R(), { kind: 'rename', player: 'Rathma', to: 'joi' })).toThrow(/Joi/);
  });
  it('merge moves every name and removes the source', () => {
    const r = applyOp(R(), { kind: 'merge', from: 'Joi', into: 'Braun' });
    expect(r.map((e) => e.name)).toEqual(['Rathma', 'Braun']);
    expect(r[1].nicknames).toEqual(['Joi', 'Фантазер']);
    expect(() => applyOp(R(), { kind: 'merge', from: 'Joi', into: 'Joi' })).toThrow();
  });
  it('ops find players by name, so they apply after the list shifted', () => {
    const shifted = [{ name: 'Новий', nicknames: [] }, ...R()];
    expect(applyOp(shifted, { kind: 'nick-add', player: 'Joi', nick: 'Джой' })[3].nicknames).toEqual(['Фантазер', 'Джой']);
    expect(() => applyOp(R(), { kind: 'nick-add', player: 'Ghost', nick: 'x2' })).toThrow(/Ghost/);
  });
});

describe('lookups', () => {
  it('owner, autocomplete and alias pairs', () => {
    const r = [...R(), { name: '/', nicknames: [] }, { name: '17', nicknames: [] }];
    expect(ownerOf(r, 'скай')).toBe('Rathma');
    expect(autocompleteNames(r)).toEqual(['Braun', 'Joi', 'Rathma', 'Скай', 'Фантазер']);
    expect(aliasPairs(R())).toContainEqual(['скай', 'Rathma']);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd site && npx vitest run src/lib/roster`
Expected: FAIL — `./roster` does not exist.

- [ ] **Step 3: Implement** `site/src/lib/roster/roster.ts`

```ts
// The club's player list (Firestore config/players): validation shared with Dart
// (test/fixtures/roster_cases.json) and the edits /players/edit/ makes. Pure: no I/O.
export interface RosterEntry { name: string; nicknames: string[] }
export type RosterOp =
  | { kind: 'add'; name: string }
  | { kind: 'nick-add'; player: string; nick: string }
  | { kind: 'nick-remove'; player: string; nick: string }
  | { kind: 'rename'; player: string; to: string }
  | { kind: 'merge'; from: string; into: string };

export const MAX_ENTRIES = 2000;
export const MAX_NICKNAMES = 50;
const low = (s: string) => s.toLowerCase();
const names = (e: RosterEntry) => [e.name, ...e.nicknames];
const clean = (s: string) => s.trim().replace(/\s+/g, ' ');
const junk = (n: string) => n.length < 2 || /^[\d/\\.]+$/.test(n);

export function rosterClashes(r: RosterEntry[]): string[] {
  const owner = new Map<string, number>();
  const clashes = new Set<string>();
  r.forEach((e, i) => {
    for (const n of names(e)) {
      const k = low(n);
      if (!owner.has(k)) owner.set(k, i);
      else if (owner.get(k) !== i) clashes.add(k);
    }
  });
  return [...clashes].sort();
}

export function rosterErrors(r: RosterEntry[]): string[] {
  const errors: string[] = [];
  if (r.length > MAX_ENTRIES) errors.push(`${r.length} players, the limit is ${MAX_ENTRIES}`);
  for (const e of r) if (e.nicknames.length > MAX_NICKNAMES) errors.push(`${e.name} has ${e.nicknames.length} nicknames, the limit is ${MAX_NICKNAMES}`);
  const clashes = rosterClashes(r);
  if (clashes.length) errors.push(`names used by two players: ${clashes.join(', ')}`);
  return errors;
}

/** Drops entries whose names are all claimed by earlier ones (unreachable for the resolver). */
export function dedupeRoster(r: RosterEntry[]): RosterEntry[] {
  const seen = new Set<string>();
  return r.filter((e) => {
    const keys = names(e).map(low);
    if (keys.every((k) => seen.has(k))) return false;
    keys.forEach((k) => seen.add(k));
    return true;
  });
}

export const fromAppJson = (list: { displayName: string; nicknames?: string[] }[]): RosterEntry[] =>
  list.map((p) => ({ name: p.displayName, nicknames: [...(p.nicknames ?? [])] }));

export function ownerOf(r: RosterEntry[], name: string): string | undefined {
  const k = low(name.trim());
  return r.find((e) => names(e).some((n) => low(n) === k))?.name;
}

function find(r: RosterEntry[], player: string): number {
  const i = r.findIndex((e) => e.name === player);
  if (i < 0) throw new Error(`${player} is not in the list any more — reload`);
  return i;
}

/** A new name or nickname for entry [self] (or a new entry): long enough, nobody else's. */
function fresh(r: RosterEntry[], raw: string, self: number | null): string {
  const n = clean(raw);
  if (n.length < 2) throw new Error('A name needs at least 2 characters');
  const k = low(n);
  const other = r.findIndex((e, i) => i !== self && names(e).some((x) => low(x) === k));
  if (other >= 0) throw new Error(`"${n}" already belongs to ${r[other].name}`);
  return n;
}

export function applyOp(r: RosterEntry[], op: RosterOp): RosterEntry[] {
  const next = r.map((e) => ({ name: e.name, nicknames: [...e.nicknames] }));
  switch (op.kind) {
    case 'add':
      next.push({ name: fresh(next, op.name, null), nicknames: [] });
      break;
    case 'nick-add': {
      const i = find(next, op.player);
      const n = fresh(next, op.nick, i);
      if (!names(next[i]).some((x) => low(x) === low(n))) next[i].nicknames.push(n);
      break;
    }
    case 'nick-remove': {
      const i = find(next, op.player);
      next[i].nicknames = next[i].nicknames.filter((x) => x !== op.nick);
      break;
    }
    case 'rename': {
      const i = find(next, op.player);
      const to = fresh(next, op.to, i);
      const old = next[i].name;
      const nicks = next[i].nicknames.filter((x) => low(x) !== low(to));
      if (low(old) !== low(to) && !nicks.some((x) => low(x) === low(old))) nicks.unshift(old);
      next[i] = { name: to, nicknames: nicks };
      break;
    }
    case 'merge': {
      const from = find(next, op.from);
      const into = find(next, op.into);
      if (from === into) throw new Error('Pick another player to merge into');
      const have = new Set(names(next[into]).map(low));
      for (const n of names(next[from])) if (!have.has(low(n))) { next[into].nicknames.push(n); have.add(low(n)); }
      next.splice(from, 1);
      break;
    }
  }
  const errors = rosterErrors(next);
  if (errors.length) throw new Error(errors.join('; '));
  return next;
}

/** /host/ autocomplete: every name and nickname, junk left out, Ukrainian order. */
export const autocompleteNames = (r: RosterEntry[]) =>
  [...new Set(r.flatMap(names).map((n) => n.trim()).filter((n) => !junk(n)))].sort((a, b) => a.localeCompare(b, 'uk'));

/** Lower-cased name or nickname → display name, so /host/ catches one player entered twice. */
export const aliasPairs = (r: RosterEntry[]): [string, string][] =>
  r.flatMap((e) => names(e).map((n) => [low(n.trim()), e.name.trim()] as [string, string])).filter(([k]) => k.length >= 2);
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd site && npx vitest run src/lib/roster`
Expected: PASS. (If `autocompleteNames` order differs because of `localeCompare('uk')` on Latin vs Cyrillic, fix the expected array to the order the function produces only after checking it puts Latin before Cyrillic as `/host/` does today; ledger it.)

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/roster/roster.ts site/src/lib/roster/roster.test.ts
git commit -m "feat: roster operations for the player editor"
```

---

### Task 8: `/players/edit/` page

**Files:**
- Create: `site/src/lib/roster/store.ts`, `site/src/lib/roster/render.ts`, `site/src/lib/roster/render.test.ts`, `site/src/pages/players/edit.astro`, `site/src/scripts/players-edit.ts`

**Interfaces:**
- Consumes: Task 7 `applyOp`, `RosterOp`, `RosterEntry`, `dedupeRoster`, `fromAppJson`, `rosterErrors`, `ownerOf`; Task 5 `loadUnresolved`, `loadPlayers`; `onClubUser`, `signIn`, `signOutUser`, `ClubAdmin` from `../club/store`; `esc` from `../annual/render`.
- Produces: `loadRoster(): Promise<RosterEntry[] | null>`, `saveRosterOp(op, u): Promise<RosterEntry[]>`, `importRoster(list, u)`; `playerRow(e, opts)`, `unresolvedRow(u, owner)`.

- [ ] **Step 1: Write the failing render test** `site/src/lib/roster/render.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { filterRoster, playerRow, unresolvedRow } from './render';

const r = [{ name: 'Rathma', nicknames: ['Скай'] }, { name: '<b>x', nicknames: ['"q'] }];

describe('render', () => {
  it('escapes names and nicknames', () => {
    const html = playerRow(r[1], { canSave: true, mode: null });
    expect(html).not.toContain('<b>x');
    expect(html).toContain('&lt;b&gt;x');
    expect(html).not.toContain('"q"');
  });
  it('read-only rows have no action buttons', () => {
    expect(playerRow(r[0], { canSave: false, mode: null })).not.toContain('<button');
  });
  it('rename and merge modes show their confirm form', () => {
    expect(playerRow(r[0], { canSave: true, mode: 'rename' })).toContain('data-act="rename-ok"');
    expect(playerRow(r[0], { canSave: true, mode: 'merge' })).toContain('data-act="merge-ok"');
  });
  it('filters by name or nickname, case-insensitively', () => {
    expect(filterRoster(r, 'скай').map((e) => e.name)).toEqual(['Rathma']);
    expect(filterRoster(r, '')).toHaveLength(2);
  });
  it('an unresolved name that now resolves says so', () => {
    expect(unresolvedRow({ name: 'Скай', games: 3, lastSeason: 31 }, 'Rathma', true)).toContain('Rathma');
    expect(unresolvedRow({ name: 'Гість', games: 1, lastSeason: 31 }, undefined, true)).toContain('data-act="attach"');
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd site && npx vitest run src/lib/roster/render.test.ts`
Expected: FAIL — `./render` does not exist.

- [ ] **Step 3: Implement** `site/src/lib/roster/render.ts`

```ts
// HTML for /players/edit/. Every roster value is escaped: the document is admin-written but public.
import { esc } from '../annual/render';
import type { RosterEntry } from './roster';

export type RowMode = 'rename' | 'merge' | null;

export const filterRoster = (r: RosterEntry[], q: string) => {
  const k = q.trim().toLowerCase();
  return k ? r.filter((e) => [e.name, ...e.nicknames].some((n) => n.toLowerCase().includes(k))) : r;
};

export function playerRow(e: RosterEntry, o: { canSave: boolean; mode: RowMode }): string {
  const p = esc(e.name);
  const nicks = e.nicknames.map((n) => `<span class="chip">${esc(n)}${o.canSave
    ? ` <button type="button" class="x" data-act="nick-remove" data-player="${p}" data-nick="${esc(n)}" aria-label="Remove ${esc(n)}">×</button>` : ''}</span>`).join(' ');
  const actions = !o.canSave ? '' : o.mode === 'rename'
    ? `<span class="act"><input name="to" value="${p}" aria-label="New name"> <button type="button" class="btn primary" data-act="rename-ok" data-player="${p}">Rename</button>
       <button type="button" class="btn" data-act="cancel">Cancel</button>
       <span class="hint">The old name stays as a nickname; the player's page URL changes.</span></span>`
    : o.mode === 'merge'
      ? `<span class="act"><input name="into" list="roster-names" placeholder="Merge into…" aria-label="Merge into"> <button type="button" class="btn primary" data-act="merge-ok" data-player="${p}">Merge</button>
         <button type="button" class="btn" data-act="cancel">Cancel</button>
         <span class="hint">${p} and its nicknames become nicknames of the chosen player; ${p} disappears from the list.</span></span>`
      : `<span class="act"><input name="nick" placeholder="Add nickname" aria-label="Add nickname"> <button type="button" class="btn" data-act="nick-add" data-player="${p}">Add</button>
         <button type="button" class="btn" data-act="rename" data-player="${p}">Rename</button>
         <button type="button" class="btn" data-act="merge" data-player="${p}">Merge into…</button></span>`;
  return `<div class="pl" data-player="${p}"><span class="name">${p}</span> ${nicks} ${actions}</div>`;
}

export function unresolvedRow(u: { name: string; games: number; lastSeason: number }, owner: string | undefined, canSave: boolean): string {
  const n = esc(u.name);
  const head = `<span class="name">${n}</span> <span class="label">${u.games} games · last S${u.lastSeason}</span>`;
  if (owner) return `<div class="un">${head} <span class="hint">now resolves to ${esc(owner)}</span></div>`;
  return `<div class="un">${head}${canSave ? ` <input name="attach" list="roster-names" placeholder="Attach to…" aria-label="Attach ${n} to">
    <button type="button" class="btn" data-act="attach" data-name="${n}">Attach</button>
    <button type="button" class="btn" data-act="new" data-name="${n}">New player</button>` : ''}</div>`;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd site && npx vitest run src/lib/roster`
Expected: PASS.

- [ ] **Step 5: Write the store** `site/src/lib/roster/store.ts`

```ts
// Firebase client for config/players. Access control lives in firestore.rules (public read, admin write).
import { doc, getDoc, runTransaction, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import { applyOp, rosterErrors, type RosterEntry, type RosterOp } from './roster';

const ref = () => doc(db, 'config', 'players');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });
const toEntries = (raw: unknown): RosterEntry[] => (Array.isArray(raw) ? raw : []).map((p) => ({
  name: String(p?.name ?? ''),
  nicknames: Array.isArray(p?.nicknames) ? p.nicknames.map(String) : [],
}));

export async function loadRoster(): Promise<RosterEntry[] | null> {
  const snap = await getDoc(ref());
  return snap.exists() ? toEntries(snap.data().players) : null;
}

/** Applies [op] to the current document (retried by Firestore on a concurrent edit) and bumps meta/state. */
export async function saveRosterOp(op: RosterOp, u: ClubAdmin): Promise<RosterEntry[]> {
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    if (!snap.exists()) throw new Error('config/players does not exist yet — import it first');
    const next = applyOp(toEntries(snap.data().players), op);
    tx.set(ref(), { players: next, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return next;
  });
}

/** One-time copy of assets/raw/players.json (already deduped by the caller). */
export async function importRoster(list: RosterEntry[], u: ClubAdmin) {
  const errors = rosterErrors(list);
  if (errors.length) throw new Error(errors.join('; '));
  await runTransaction(db, async (tx) => {
    if ((await tx.get(ref())).exists()) throw new Error('config/players already exists');
    tx.set(ref(), { players: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}
```

- [ ] **Step 6: Write the page** `site/src/pages/players/edit.astro`

```astro
---
import Base from '../../layouts/Base.astro';
import { loadUnresolved } from '../../lib/data';

const unresolved = loadUnresolved().names;
---
<Base title="Edit players" description="Admins add players and glue nicknames." active="players">
  <div class="pagehead"><h1 class="display">Players list</h1><span class="label" id="state">Loading…</span></div>

  <div class="panel access">
    <span class="label">Editing</span> <span id="who">Read-only</span>
    <button type="button" id="sign-in" class="btn primary">Sign in with Google</button>
    <button type="button" id="sign-out" class="btn" hidden>Sign out</button>
    <button type="button" id="import" class="btn" hidden>Import from players.json</button>
    <p class="hint">Admins (hosts with <code>admin: true</code>) can save. A game name counts for a player when it equals the player's name or a nickname (case ignored). The site rebuilds within an hour.</p>
  </div>

  <div class="toolbar">
    <input id="q" type="search" placeholder="Search name or nickname" aria-label="Search">
    <input id="new-name" placeholder="New player" aria-label="New player name">
    <button type="button" id="add" class="btn" disabled>Add player</button>
  </div>

  <p id="msg" class="msg" role="status"></p>
  <div id="list" class="list"></div>

  <h2>Unresolved names</h2>
  <p class="hint">Names from games (as of the last build) that belong to no player.</p>
  <div id="unresolved" class="list"></div>

  <datalist id="roster-names"></datalist>
  <script type="application/json" id="unresolved-data" set:html={JSON.stringify(unresolved).replace(/</g, '\\u003c')} />
</Base>

<script>
  import '../../scripts/players-edit';
</script>

<style>
  .access, .toolbar { display: flex; flex-wrap: wrap; gap: 8px 12px; align-items: center; margin-bottom: 12px; }
  .hint { flex-basis: 100%; margin: 0; color: var(--muted); }
  .msg:empty { display: none; }
  .msg.error { color: var(--city); }
  .list .pl, .list .un { display: flex; flex-wrap: wrap; gap: 6px 10px; align-items: center; padding: 8px 0; border-top: 1px solid var(--border); }
  .list .name { font-weight: 600; }
  .chip { border: 1px solid var(--border); border-radius: 999px; padding: 1px 8px; }
  .chip .x { border: 0; background: none; color: var(--muted); cursor: pointer; padding: 0 2px; }
  .act { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin-left: auto; }
  input { min-width: 0; }
</style>
```

- [ ] **Step 7: Write the script** `site/src/scripts/players-edit.ts`

```ts
// /players/edit/: admins edit the club's player list (Firestore config/players).
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { importRoster, loadRoster, saveRosterOp } from '../lib/roster/store';
import { dedupeRoster, fromAppJson, ownerOf, type RosterEntry, type RosterOp } from '../lib/roster/roster';
import { filterRoster, playerRow, unresolvedRow, type RowMode } from '../lib/roster/render';
import { esc } from '../lib/annual/render';

const IMPORT_URL = 'https://raw.githubusercontent.com/Seezov/FamilyMafiaApp/feature/flutter_migration/assets/raw/players.json';
const SHOWN = 100;
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const unresolved = JSON.parse($('unresolved-data').textContent!) as { name: string; games: number; lastSeason: number }[];

let user: ClubAdmin | null | 'not-host' = null;
let roster: RosterEntry[] | null = null;
let mode: { player: string; mode: RowMode } | null = null;
let busy = false;
const canSave = () => typeof user === 'object' && user !== null && user.admin && roster !== null && !busy;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

async function refresh() {
  try {
    roster = await loadRoster();
    $('state').textContent = roster ? `${roster.length} players` : 'Not imported yet';
  } catch (e) {
    $('state').textContent = 'Could not load the list';
    say(String(e), true);
  }
  render();
}

function render() {
  const r = roster ?? [];
  const shown = filterRoster(r, ($('q') as HTMLInputElement).value);
  $('list').innerHTML = shown.slice(0, SHOWN).map((e) => playerRow(e, { canSave: canSave(), mode: mode?.player === e.name ? mode.mode : null })).join('')
    + (shown.length > SHOWN ? `<p class="hint">${shown.length - SHOWN} more — refine the search.</p>` : '');
  $('unresolved').innerHTML = unresolved.map((u) => unresolvedRow(u, roster ? ownerOf(r, u.name) : undefined, canSave())).join('')
    || '<p class="hint">Every game name belongs to a player.</p>';
  $('roster-names').innerHTML = r.map((e) => `<option value="${esc(e.name)}">`).join('');
  $('add').toggleAttribute('disabled', !canSave());
  const admin = typeof user === 'object' && user !== null && user.admin;
  $('import').hidden = !(admin && roster === null);
  $('who').textContent = user === null ? 'Read-only' : user === 'not-host' ? 'Not a host — read-only' : `${user.name}${user.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
}

async function run(op: RosterOp, done: string) {
  if (!canSave()) return;
  busy = true;
  render();
  try {
    roster = await saveRosterOp(op, user as ClubAdmin);
    mode = null;
    $('state').textContent = `${roster.length} players`;
    say(`${done} The site updates within an hour.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    render();
  }
}

const inputIn = (el: Element, name: string) => (el.closest('.pl, .un')?.querySelector(`input[name="${name}"]`) as HTMLInputElement | null)?.value ?? '';

document.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLElement>('[data-act]');
  if (!b) return;
  const player = b.dataset.player ?? '';
  const name = b.dataset.name ?? '';
  switch (b.dataset.act) {
    case 'nick-add': void run({ kind: 'nick-add', player, nick: inputIn(b, 'nick') }, `Nickname added to ${player}.`); break;
    case 'nick-remove': void run({ kind: 'nick-remove', player, nick: b.dataset.nick ?? '' }, `Nickname removed from ${player}.`); break;
    case 'rename': mode = { player, mode: 'rename' }; render(); break;
    case 'merge': mode = { player, mode: 'merge' }; render(); break;
    case 'cancel': mode = null; render(); break;
    case 'rename-ok': void run({ kind: 'rename', player, to: inputIn(b, 'to') }, `${player} renamed.`); break;
    case 'merge-ok': void run({ kind: 'merge', from: player, into: inputIn(b, 'into') }, `${player} merged.`); break;
    case 'attach': void run({ kind: 'nick-add', player: inputIn(b, 'attach'), nick: name }, `${name} attached.`); break;
    case 'new': void run({ kind: 'add', name }, `${name} added.`); break;
  }
});

$('add').addEventListener('click', () => {
  const input = $('new-name') as HTMLInputElement;
  void run({ kind: 'add', name: input.value }, `${input.value.trim()} added.`).then(() => { input.value = ''; });
});
$('q').addEventListener('input', render);
$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());
$('import').addEventListener('click', async () => {
  if (!canSaveImport()) return;
  busy = true;
  render();
  try {
    const res = await fetch(IMPORT_URL);
    if (!res.ok) throw new Error(`HTTP ${res.status} reading players.json`);
    const list = dedupeRoster(fromAppJson(await res.json()));
    await importRoster(list, user as ClubAdmin);
    say(`Imported ${list.length} players.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    await refresh();
  }
});
const canSaveImport = () => typeof user === 'object' && user !== null && user.admin && roster === null && !busy;

onClubUser((u) => { user = u; render(); });
void refresh();
```

(If the `ev.target` click lands on `button[data-act]` inside `.chip`, `closest` finds it; the `cancel` button has no `data-player`, which is fine.)

- [ ] **Step 8: Type-check and build**

Run: `cd site && npx astro check > /tmp/roster-check.log 2>&1; tail -3 /tmp/roster-check.log && npm run build > /tmp/roster-build.log 2>&1; tail -5 /tmp/roster-build.log`
Expected: `0 errors`; build ends with the check-dist success line; `dist/players/edit/index.html` exists.

- [ ] **Step 9: Commit**

```bash
git add site/src/lib/roster/store.ts site/src/lib/roster/render.ts site/src/lib/roster/render.test.ts site/src/pages/players/edit.astro site/src/scripts/players-edit.ts
git commit -m "feat: /players/edit/ — admins edit the player list"
```

---

### Task 9: `/host/` reads the live roster

**Files:**
- Modify: `site/src/pages/host/index.astro`, `site/src/scripts/host.ts`

**Interfaces:**
- Consumes: Task 7 `fromAppJson`, `autocompleteNames`, `aliasPairs`, `dedupeRoster`; Task 8 `loadRoster`.

- [ ] **Step 1: Build-time list from the snapshot when present** — in `host/index.astro` replace the roster/names/aliases lines with:

```astro
import { aliasPairs, autocompleteNames, dedupeRoster, fromAppJson } from '../../lib/roster/roster';
// Player names for autocomplete: the build's roster snapshot (config/players), else the bundled file.
// The page also reads the live list on load (scripts/host.ts).
const root = path.resolve(process.cwd(), '..');
const snapshot = path.join(root, 'assets/prefetched/players.json');
const rosterFile = fs.existsSync(snapshot) ? snapshot : path.join(root, 'assets/raw/players.json');
const roster = dedupeRoster(fromAppJson(JSON.parse(fs.readFileSync(rosterFile, 'utf8'))));
const names = autocompleteNames(roster);
```

and `const aliases = aliasPairs(roster);` in place of the old `aliases` expression. Keep `datalist id="names"` as is.

- [ ] **Step 2: Live refresh** — in `host.ts`, add imports and, after `const aliases = new Map(page.aliases);`:

```ts
import { loadRoster } from '../lib/roster/store';
import { aliasPairs, autocompleteNames } from '../lib/roster/roster';

// The baked list is as of the last build; a player an admin just added shows up here at once.
void loadRoster().then((r) => {
  if (!r) return;
  page.names = autocompleteNames(r);
  aliases.clear();
  for (const [k, v] of aliasPairs(r)) aliases.set(k, v);
  document.getElementById('names')!.innerHTML = page.names.map((n) => `<option value="${esc(n)}">`).join('');
}).catch(() => { /* keep the baked list */ });
```

Import `esc` from `'../lib/annual/render'` (if `host.ts` already has an escaping helper, use that one instead and ledger it). `page` is declared with `const`; its `names` property is mutable — if TS narrows it as readonly, change the cast type to `{ names: string[]; … }` without `readonly`.

- [ ] **Step 3: Tests and build**

Run: `cd site && npm test > /tmp/roster-site.log 2>&1; tail -4 /tmp/roster-site.log; npx astro check > /tmp/roster-check.log 2>&1; tail -2 /tmp/roster-check.log; npm run build > /tmp/roster-build.log 2>&1; tail -3 /tmp/roster-build.log`
Expected: all site tests pass; `0 errors`; build succeeds.

- [ ] **Step 4: Commit**

```bash
git add site/src/pages/host/index.astro site/src/scripts/host.ts
git commit -m "feat: /host/ suggests names from the live roster"
```

---

### Task 10: Docs

**Files:**
- Modify: `CLAUDE.md` (Web site section)

- [ ] **Step 1: Add the bullet** after the «Annual rating» bullet:

```markdown
- **Player list:** Firestore `config/players` (`{players: [{name, nicknames}]}`, ordered — the app numbers
  players by position) is the roster; admins edit it on `/players/edit/` (add, nicknames, rename keeps the
  old name as a nickname, merge, unresolved game names from `site/data/unresolved.json`). Validation in
  `lib/models/roster.dart` and `site/src/lib/roster/roster.ts` (shared fixture `test/fixtures/roster_cases.json`).
  Prefetch snapshots it to `assets/prefetched/players.json` in the old `players.json` shape; the app reads it
  live → cached → bundled `assets/raw/players.json` (now only a fallback). Profiles follow renames through
  `aliases` in `site/data/players.json`.
```

- [ ] **Step 2: Full verification**

Run:
```bash
flutter analyze > /tmp/roster-an.log 2>&1; tail -2 /tmp/roster-an.log
flutter test > /tmp/roster-all.log 2>&1; tail -2 /tmp/roster-all.log
(cd site && npm test > /tmp/roster-site.log 2>&1; tail -3 /tmp/roster-site.log)
(cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test > /tmp/roster-rules.log 2>&1; tail -4 /tmp/roster-rules.log)
```
Expected: `No issues found!`; `All tests passed!`; site tests pass; rules 62 pass.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: player list in CLAUDE.md"
```

---

## Rollout (needs the user's go-ahead)

1. Push `feature/flutter_migration` and fast-forward `master` to the same commit.
2. Publish the `config/players` rule in the Firebase console (Rules tab), verify the history entry and a public REST read of `config/players` (404 until import = rule works for read).
3. The user (admin) opens `/players/edit/` and clicks «Import from players.json»; verify the document has 607 entries and `meta/state` was bumped.
4. After the next build: the site's players and stats are unchanged (spot-check a player with nicknames, e.g. Anatolich), `/players/edit/` lists the roster.
