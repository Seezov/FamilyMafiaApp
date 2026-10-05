# Season Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admins create club seasons 32+ on `/seasons/edit/`; Firestore `config/seasons` holds them; the build, the app and `/host/` append them to the JSON season list.

**Architecture:** A pure-Dart `ClubSeason` module parses and validates `config/seasons` entries and turns them into the `SeasonConfig` JSON the app already understands. The prefetch appends them to the `remote_config.json` snapshot it writes (and snapshots their games), so the export needs no change; the app appends them in `parsedConfigProvider` (live → cache). A season whose Firestore snapshot has no games is skipped when loading. A TS module (same validation fixture) drives the editor page and `/host/`'s default season.

**Tech Stack:** Dart/Flutter (Riverpod, Dio), Astro + TypeScript (vitest), Firebase JS SDK, Firestore rules.

**Spec:** `docs/superpowers/specs/2026-10-05-season-creation-design.md`

## Global Constraints

- Admin = `hosts/{email}.admin == true`; sign-in via `site/src/lib/club/store.ts` (`onClubUser`, `signIn`, `signOutUser`).
- `config/seasons` keys exactly `seasons`, `updatedAt`, `updatedBy`, `updatedByEmail`; `seasons` ≤ 100 entries `{id, title, smallLeagueMinGames, startDate}`.
- Valid list: ids are exactly `lastJsonId + 1, lastJsonId + 2, …` in order; title 1–40 chars after trim; `smallLeagueMinGames` int 1–100; `startDate` a real `YYYY-MM-DD` date; ≤ 100 entries.
- Each entry becomes `{id, title, gameLimitRule: 'top3', gamesMultiplier: 0.0, smallLeagueMinGames, source: 'firestore', projectId: 'familymafiaapp'}`.
- The JSON config wins on an id clash in the app; the build fails on a clash.
- Every save bumps `meta/state.updatedAt`.
- `tool/prefetch_seasons.dart` stays pure Dart.
- Admin page copy is English; `/host/` stays Ukrainian. Every Firestore value in HTML goes through `esc`.

## Review Focus

1. Two admins pressing «Create» at once → both transactions re-read the document; the second gets id N+1 or fails validation, never two seasons with the same id (Task 6 test: `createSeason` builds the next id from the fresh list — covered by `nextSeason` on a list that grew).
2. A season created for December with today's date in October → `/host/` keeps the current season as default until the start date (Task 6 test: `hostDefaultSeason` before/after `startDate`).
3. The newest season already has games → delete must be refused even if the page is stale (Task 6: `deleteNewestSeason` re-counts games right before the write; test on `canDelete`).
4. A freshly created season with no games is the last config → app and site must show the previous season, not an empty one (Task 4 test: `latestWithGames` skips it; background load skips it).
5. A malformed `config/seasons` (string id, missing title) → the build fails naming it; the app ignores it and keeps the cached list (Task 2 + Task 3 tests).

---

### Task 1: Pure-Dart club season model and validation

**Files:**
- Create: `lib/models/club_season.dart`, `test/fixtures/club_season_cases.json`
- Test: `test/models/club_season_test.dart`

**Interfaces:**
- Produces:
  - `class ClubSeason { const ClubSeason({required int id, required String title, required int smallLeagueMinGames, required String startDate}); Map<String, Object?> toJson(); Map<String, Object?> toConfigJson(); }`
  - `const kMaxClubSeasons = 100;`
  - `List<ClubSeason> parseClubSeasons(Object? list)` — throws `FormatException('seasons: …')` on wrong types
  - `List<String> clubSeasonErrors(List<ClubSeason> seasons, {required int lastJsonId})`
  - `void checkClubSeasons(List<ClubSeason> seasons, {required int lastJsonId})` — throws `FormatException`
  - `List<Map<String, dynamic>> appendClubSeasons(List<Map<String, dynamic>> jsonSeasons, List<ClubSeason> extra)` — JSON first; extra entries whose id the JSON has are dropped
  - `int lastSeasonId(List<Map<String, dynamic>> jsonSeasons)`

- [ ] **Step 1: Write the shared fixture** `test/fixtures/club_season_cases.json`

```json
[
  {"case": "no club seasons", "lastJsonId": 31, "seasons": [], "valid": true},
  {"case": "the next season", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}], "valid": true},
  {"case": "two in order", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}, {"id": 33, "title": "Season 33", "smallLeagueMinGames": 12, "startDate": "2027-03-01"}], "valid": true},
  {"case": "a gap", "lastJsonId": 31, "seasons": [{"id": 33, "title": "Season 33", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}], "valid": false},
  {"case": "id the JSON has", "lastJsonId": 32, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}], "valid": false},
  {"case": "blank title", "lastJsonId": 31, "seasons": [{"id": 32, "title": "   ", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}], "valid": false},
  {"case": "title of 41 characters", "lastJsonId": 31, "seasons": [{"id": 32, "title": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "smallLeagueMinGames": 15, "startDate": "2026-12-01"}], "valid": false},
  {"case": "min games 0", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 0, "startDate": "2026-12-01"}], "valid": false},
  {"case": "min games 101", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 101, "startDate": "2026-12-01"}], "valid": false},
  {"case": "no such day", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 15, "startDate": "2026-02-30"}], "valid": false},
  {"case": "short date", "lastJsonId": 31, "seasons": [{"id": 32, "title": "Season 32", "smallLeagueMinGames": 15, "startDate": "2026-2-1"}], "valid": false}
]
```

- [ ] **Step 2: Write the failing test** `test/models/club_season_test.dart`

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/club_season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = (jsonDecode(File('test/fixtures/club_season_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('validity matches every shared case (same fixture as the TS test)', () {
    for (final c in cases) {
      final errors = clubSeasonErrors(parseClubSeasons(c['seasons']), lastJsonId: c['lastJsonId'] as int);
      expect(errors.isEmpty, c['valid'], reason: '${c['case']}: $errors');
    }
  });

  test('more than 100 seasons is invalid', () {
    final many = [
      for (var i = 0; i < kMaxClubSeasons + 1; i++)
        ClubSeason(id: 32 + i, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01'),
    ];
    expect(clubSeasonErrors(many, lastJsonId: 31), isNotEmpty);
  });

  test('parseClubSeasons rejects wrong types', () {
    expect(() => parseClubSeasons('x'), throwsFormatException);
    expect(() => parseClubSeasons([{'id': '32', 'title': 'S', 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'}]), throwsFormatException);
    expect(() => parseClubSeasons([{'id': 32, 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'}]), throwsFormatException);
  });

  test('checkClubSeasons names the problem', () {
    expect(() => checkClubSeasons(parseClubSeasons(cases[3]['seasons']), lastJsonId: 31),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('33'))));
  });

  test('toConfigJson is a firestore SeasonConfig with the top3 rule', () {
    const s = ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 12, startDate: '2026-12-01');
    final config = SeasonConfig.fromJson(s.toConfigJson());
    expect(config.id, 32);
    expect(config.title, 'Season 32');
    expect(config.source, isA<FirestoreSource>());
    expect(s.toConfigJson(), containsPair('gameLimitRule', 'top3'));
    expect(s.toConfigJson(), containsPair('smallLeagueMinGames', 12));
    expect(s.toConfigJson().containsKey('startDate'), isFalse);
  });

  test('appendClubSeasons keeps the JSON first and drops a clashing id', () {
    final json = [{'id': 31, 'title': 'Season 31'}];
    final out = appendClubSeasons(json, const [
      ClubSeason(id: 31, title: 'Dup', smallLeagueMinGames: 15, startDate: '2026-12-01'),
      ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 15, startDate: '2026-12-01'),
    ]);
    expect(out.map((s) => s['title']), ['Season 31', 'Season 32']);
    expect(lastSeasonId(json), 31);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/models/club_season_test.dart`
Expected: FAIL — `club_season.dart` does not exist.

- [ ] **Step 4: Implement** `lib/models/club_season.dart`

```dart
import 'package:family_mafia_app/services/firestore_service_ids.dart';

/// A club season created on /seasons/edit/ (Firestore `config/seasons`).
/// Seasons up to the JSON config's last id stay in `remote_config.json`;
/// these are appended after it. Pure Dart: the CI prefetch imports it.
class ClubSeason {
  const ClubSeason({
    required this.id,
    required this.title,
    required this.smallLeagueMinGames,
    required this.startDate,
  });

  final int id;
  final String title;
  final int smallLeagueMinGames;

  /// 'YYYY-MM-DD': from this day /host/ offers the season by default.
  final String startDate;

  Map<String, Object?> toJson() => {
        'id': id, 'title': title, 'smallLeagueMinGames': smallLeagueMinGames, 'startDate': startDate,
      };

  /// The `SeasonConfig` JSON the app loads: a Firestore season with the
  /// top-3 threshold rule, like season 31's.
  Map<String, Object?> toConfigJson() => {
        'id': id,
        'title': title,
        'gameLimitRule': 'top3',
        'gamesMultiplier': 0.0,
        'smallLeagueMinGames': smallLeagueMinGames,
        'source': 'firestore',
        'projectId': kFirebaseProjectIdForSeasons,
      };
}

const kMaxClubSeasons = 100;

List<ClubSeason> parseClubSeasons(Object? list) {
  if (list is! List) throw const FormatException('seasons: not a list');
  return [
    for (final (i, s) in list.indexed)
      if (s is Map &&
          s['id'] is int &&
          s['title'] is String &&
          s['smallLeagueMinGames'] is int &&
          s['startDate'] is String)
        ClubSeason(
          id: s['id'] as int,
          title: s['title'] as String,
          smallLeagueMinGames: s['smallLeagueMinGames'] as int,
          startDate: s['startDate'] as String,
        )
      else
        throw FormatException('seasons: entry $i needs int id, string title, int smallLeagueMinGames, string startDate'),
  ];
}

final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

bool _realDate(String s) {
  final m = _date.firstMatch(s);
  if (m == null) return false;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

List<String> clubSeasonErrors(List<ClubSeason> seasons, {required int lastJsonId}) {
  final errors = <String>[];
  if (seasons.length > kMaxClubSeasons) errors.add('${seasons.length} seasons, the limit is $kMaxClubSeasons');
  for (final (i, s) in seasons.indexed) {
    final want = lastJsonId + 1 + i;
    if (s.id != want) errors.add('season ${s.id}: expected id $want');
    final t = s.title.trim().length;
    if (t < 1 || t > 40) errors.add('season ${s.id}: title must be 1–40 characters');
    if (s.smallLeagueMinGames < 1 || s.smallLeagueMinGames > 100) {
      errors.add('season ${s.id}: small league minimum must be 1–100');
    }
    if (!_realDate(s.startDate)) errors.add('season ${s.id}: start date "${s.startDate}" is not a YYYY-MM-DD date');
  }
  return errors;
}

void checkClubSeasons(List<ClubSeason> seasons, {required int lastJsonId}) {
  final errors = clubSeasonErrors(seasons, lastJsonId: lastJsonId);
  if (errors.isNotEmpty) throw FormatException('config/seasons: ${errors.join('; ')}');
}

int lastSeasonId(List<Map<String, dynamic>> jsonSeasons) =>
    jsonSeasons.fold(-1, (m, s) => (s['id'] as int) > m ? s['id'] as int : m);

List<Map<String, dynamic>> appendClubSeasons(List<Map<String, dynamic>> jsonSeasons, List<ClubSeason> extra) {
  final ids = {for (final s in jsonSeasons) s['id']};
  return [
    ...jsonSeasons,
    for (final s in extra)
      if (!ids.contains(s.id)) s.toConfigJson(),
  ];
}
```

`lib/services/firestore_service_ids.dart` (new, pure — `firestore_service.dart` imports Dio, which is fine for the prefetch, but the model must not depend on a service):

```dart
/// The Firebase project behind /host/, config/club, config/players and config/seasons.
const kFirebaseProjectIdForSeasons = 'familymafiaapp';
```

and in `lib/services/firestore_service.dart` replace `const kFirebaseProjectId = 'familymafiaapp';` with
`const kFirebaseProjectId = kFirebaseProjectIdForSeasons;` plus `import 'package:family_mafia_app/services/firestore_service_ids.dart';` (keeps one source of truth).

- [ ] **Step 5: Run it to verify it passes**

Run: `flutter test test/models/club_season_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/models/club_season.dart lib/services/firestore_service_ids.dart lib/services/firestore_service.dart test/models/club_season_test.dart test/fixtures/club_season_cases.json
git commit -m "feat: pure-Dart club season model and validation"
```

---

### Task 2: Rules for `config/seasons`

**Files:**
- Modify: `firestore.rules` (after `match /config/players`)
- Test: `firebase/rules-test/rules.test.ts`

- [ ] **Step 1: Write the failing tests** (append)

```ts
describe('config/seasons', () => {
  const ref = (db: ReturnType<typeof as>) => doc(db, 'config', 'seasons');
  const body = (u: User, extra: Record<string, unknown> = {}) => ({
    seasons: [{ id: 32, title: 'Season 32', smallLeagueMinGames: 15, startDate: '2026-12-01' }],
    updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email, ...extra,
  });
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'seasons')));
  });
  it('an admin can create and update', async () => {
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons: [] })));
  });
  it('a host who is not admin cannot write', async () => {
    await assertFails(setDoc(ref(as(HOST)), body(HOST)));
  });
  it('a guest cannot write', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'config', 'seasons'), body(ADMIN)));
  });
  it('rejects extra keys, a non-list, a forged author and a client timestamp', async () => {
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { extra: 1 })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons: 'x' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedBy: 'someone' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedByEmail: 'x@x.com' })));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { updatedAt: new Date(0) })));
  });
  it('rejects more than 100 seasons', async () => {
    const seasons = Array.from({ length: 101 }, (_, i) => ({ id: 32 + i, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01' }));
    await assertFails(setDoc(ref(as(ADMIN)), body(ADMIN, { seasons })));
  });
  it('nobody can delete it', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'config', 'seasons'), { seasons: [] }));
    await assertFails(deleteDoc(ref(as(ADMIN))));
  });
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test`
Expected: FAIL — `anyone can read`, `an admin can create and update`.

- [ ] **Step 3: Add the rule** after the `match /config/players { … }` block

```
    // Club seasons 32+ (the JSON config keeps 0–31), created on /seasons/edit/. Entry contents
    // are checked by the build and the editor (rules cannot loop over a list).
    match /config/seasons {
      allow read: if true;
      allow create, update: if isAdmin()
        && request.resource.data.keys().hasOnly(['seasons', 'updatedAt', 'updatedBy', 'updatedByEmail'])
        && request.resource.data.seasons is list
        && request.resource.data.seasons.size() <= 100
        && request.resource.data.updatedAt == request.time
        && request.resource.data.updatedBy == request.auth.uid
        && request.resource.data.updatedByEmail == email();
      allow delete: if false;
    }
```

- [ ] **Step 4: Run them to verify they pass**

Run: same as Step 2.
Expected: PASS — 62 previous + 7 new = 69.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firebase/rules-test/rules.test.ts
git commit -m "feat: firestore rules for config/seasons"
```

---

### Task 3: Fetch club seasons; the prefetch merges them

**Files:**
- Modify: `lib/services/firestore_service.dart`, `tool/prefetch_seasons.dart`
- Test: `test/services/firestore_service_seasons_test.dart`, `test/tool/prefetch_seasons_test.dart`

**Interfaces:**
- Consumes: Task 1 `parseClubSeasons`, `checkClubSeasons`, `appendClubSeasons`, `lastSeasonId`.
- Produces: `Future<List<ClubSeason>?> FirestoreService.fetchClubSeasons(String projectId)` — null when the document does not exist; `FormatException` on wrong types (validation against the JSON is the caller's).

- [ ] **Step 1: Write the failing service test** `test/services/firestore_service_seasons_test.dart`

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

Map<String, dynamic> _season(Map<String, dynamic> id) => {'mapValue': {'fields': {
      'id': id,
      'title': {'stringValue': 'Season 32'},
      'smallLeagueMinGames': {'integerValue': '15'},
      'startDate': {'stringValue': '2026-12-01'},
    }}};

void main() {
  test('reads the seasons', () async {
    final s = await _svc(200, {'fields': {'seasons': {'arrayValue': {'values': [_season({'integerValue': '32'})]}}}})
        .fetchClubSeasons('p');
    expect(s!.single.toJson(), {'id': 32, 'title': 'Season 32', 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'});
  });

  test('a missing document is null', () async {
    expect(await _svc(404, {'error': {'code': 404}}).fetchClubSeasons('p'), isNull);
  });

  test('a wrong type throws FormatException', () async {
    await expectLater(
        _svc(200, {'fields': {'seasons': {'arrayValue': {'values': [_season({'stringValue': '32'})]}}}}).fetchClubSeasons('p'),
        throwsFormatException);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/services/firestore_service_seasons_test.dart`
Expected: FAIL — `fetchClubSeasons` not defined.

- [ ] **Step 3: Implement** — in `firestore_service.dart`, import `package:family_mafia_app/models/club_season.dart` and add after `fetchPlayers`:

```dart
  /// `config/seasons` (club seasons 32+), or null when the document doesn't
  /// exist yet. Throws [FormatException] on wrong types; checking the ids
  /// against the JSON config is the caller's job.
  Future<List<ClubSeason>?> fetchClubSeasons(String projectId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '$projectId/databases/(default)/documents/config/seasons');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final fields = decodeFirestoreFields(
          response.data?['fields'] as Map<String, dynamic>? ?? const {});
      return parseClubSeasons(fields['seasons'] ?? const []);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/services/firestore_service_seasons_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Write the failing prefetch tests** — in `test/tool/prefetch_seasons_test.dart` add `Object? seasons` to `_dio`'s parameters with the route
`if (uri.path.endsWith('/documents/config/seasons')) return seasons == null ? _body('{}', 404) : _body(jsonEncode(seasons));`
and a `runQuery` route for the new season's games if the existing firestore-season test does not already provide one (reuse the existing firestore-season fake: read the test `snapshots firestore seasons too` and route `documents:runQuery` the same way). Then add:

```dart
  Map<String, dynamic> seasonsDoc(int id) => {'fields': {'seasons': {'arrayValue': {'values': [
        {'mapValue': {'fields': {
          'id': {'integerValue': '$id'},
          'title': {'stringValue': 'Season $id'},
          'smallLeagueMinGames': {'integerValue': '15'},
          'startDate': {'stringValue': '2026-12-01'},
        }}},
      ]}}}};

  test('club seasons are appended to the config snapshot and their games fetched', () async {
    final ids = await prefetch.prefetchSeasons(
        dio: _dio(seasons: seasonsDoc(30)), apiKey: 'k', configUrl: _configUrl, outDir: out);
    final config = jsonDecode(File('${out.path}/remote_config.json').readAsStringSync()) as Map<String, dynamic>;
    final seasons = (config['seasons'] as List).cast<Map<String, dynamic>>();
    expect(seasons.last, containsPair('id', 30));
    expect(seasons.last, containsPair('source', 'firestore'));
    expect(ids, contains(30));
    expect(File('${out.path}/season30.json').existsSync(), isTrue);
  });

  test('a club season clashing with the JSON fails the prefetch and writes nothing', () async {
    await expectLater(
      prefetch.prefetchSeasons(dio: _dio(seasons: seasonsDoc(29)), apiKey: 'k', configUrl: _configUrl, outDir: out),
      throwsFormatException,
    );
    expect(out.listSync(), isEmpty);
  });
```

(The fake config's last id is 29, so the next club season is 30.)

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/tool/prefetch_seasons_test.dart`
Expected: FAIL — the two new tests.

- [ ] **Step 7: Implement** in `tool/prefetch_seasons.dart` — import `package:family_mafia_app/models/club_season.dart`; replace the block from `final configJson = configResponse.data!;` through the `.map(SeasonConfig.fromJson);` line with:

```dart
  final configMap = jsonDecode(configResponse.data!) as Map<String, dynamic>;
  final jsonSeasons = (configMap['seasons'] as List).cast<Map<String, dynamic>>();

  final firestore = FirestoreService(dio: dio);
  // Seasons 32+ created on /seasons/edit/: appended, so every reader of the
  // snapshot sees one list. Validated against the JSON's last id.
  final clubSeasons = await firestore.fetchClubSeasons(kFirebaseProjectId) ?? const <ClubSeason>[];
  checkClubSeasons(clubSeasons, lastJsonId: lastSeasonId(jsonSeasons));
  final configJson = jsonEncode({...configMap, 'seasons': appendClubSeasons(jsonSeasons, clubSeasons)});
  final seasons = ((jsonDecode(configJson) as Map<String, dynamic>)['seasons'] as List)
      .cast<Map<String, dynamic>>()
      .map(SeasonConfig.fromJson);
```

and delete the later `final firestore = FirestoreService(dio: dio);` line (now declared above). Update the header comment to mention `config/seasons`.

- [ ] **Step 8: Run to verify, plus the pure-Dart guard**

Run: `flutter test test/tool/ test/services/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/services/firestore_service.dart tool/prefetch_seasons.dart test/services/firestore_service_seasons_test.dart test/tool/prefetch_seasons_test.dart
git commit -m "feat: prefetch appends club seasons from config/seasons"
```

---

### Task 4: The app appends club seasons and skips empty ones

**Files:**
- Modify: `lib/services/season_cache_service.dart`, `lib/services/asset_season_cache_service.dart`, `lib/services/io_season_cache_service.dart`, `lib/providers/app_providers.dart`
- Create: `lib/services/empty_seasons.dart`
- Modify (fakes): `test/providers/club_config_provider_test.dart`, `test/services/firestore_service_test.dart`, `test/providers/players_json_provider_test.dart`
- Test: `test/providers/club_seasons_provider_test.dart`, `test/services/empty_seasons_test.dart`

**Interfaces:**
- Consumes: Task 1 (`ClubSeason`, `parseClubSeasons`, `clubSeasonErrors`, `appendClubSeasons`, `lastSeasonId`), Task 3 `fetchClubSeasons`.
- Produces:
  - `SeasonCacheService.getCachedClubSeasons()` / `cacheClubSeasons(String)`
  - `bool isEmptyFirestoreSnapshot(String json)`; `Future<(SeasonConfig, String)?> latestWithGames(List<SeasonConfig> configs, Future<String?> Function(SeasonConfig) load)`
  - `parsedConfigProvider` seasons include valid club seasons.

- [ ] **Step 1: Write the failing helper test** `test/services/empty_seasons_test.dart`

```dart
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/empty_seasons.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _c(int id, SeasonSource source) =>
    SeasonConfig(id: id, title: 'S$id', gameLimit: 10, smallLeagueMinGames: 15, gamesMultiplier: 0, source: source);

void main() {
  const fs = FirestoreSource(projectId: 'p');
  const empty = '{"format":"firestore","games":[]}';
  const one = '{"format":"firestore","games":[{"id":"a"}]}';

  test('only a firestore snapshot without games is empty', () {
    expect(isEmptyFirestoreSnapshot(empty), isTrue);
    expect(isEmptyFirestoreSnapshot(one), isFalse);
    expect(isEmptyFirestoreSnapshot('[["1","Rathma"]]'), isFalse);
    expect(isEmptyFirestoreSnapshot('{"values": []}'), isFalse);
  });

  test('latestWithGames skips an empty newest firestore season', () async {
    final configs = [_c(31, const BundledSource(jsonFile: 'season31.json')), _c(32, fs)];
    final r = await latestWithGames(configs, (c) async => c.id == 32 ? empty : one);
    expect(r!.$1.id, 31);
  });

  test('latestWithGames keeps a firestore season with games', () async {
    final r = await latestWithGames([_c(31, fs), _c(32, fs)], (c) async => one);
    expect(r!.$1.id, 32);
  });

  test('latestWithGames: null when nothing loads', () async {
    expect(await latestWithGames([_c(32, fs)], (c) async => null), isNull);
  });
}
```

(If `SeasonConfig`'s constructor or `BundledSource` take different named parameters, use the ones `lib/models/season_config.dart` defines and ledger the change.)

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/services/empty_seasons_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement** `lib/services/empty_seasons.dart`

```dart
import 'dart:convert';

import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_rest.dart';

/// A season created on /seasons/edit/ before its first game: the app and the
/// site leave it out until a game is recorded.
bool isEmptyFirestoreSnapshot(String json) {
  try {
    final d = jsonDecode(json);
    return d is Map && d['format'] == firestoreSnapshotFormat && (d['games'] as List?)?.isEmpty == true;
  } catch (_) {
    return false;
  }
}

/// The newest season whose JSON loads and is not an empty Firestore season,
/// with that JSON; null when none loads.
Future<(SeasonConfig, String)?> latestWithGames(
    List<SeasonConfig> configs, Future<String?> Function(SeasonConfig) load) async {
  for (final c in configs.reversed) {
    final json = await load(c);
    if (json == null) return null; // as before: the newest season must load
    if (!isEmptyFirestoreSnapshot(json)) return (c, json);
  }
  return null;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/services/empty_seasons_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing provider test** `test/providers/club_seasons_provider_test.dart`

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/club_season.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemCache implements SeasonCacheService {
  String? seasons;
  @override Future<String?> getCachedSeasonData(int id) async => null;
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async {}
  @override Future<void> invalidateSeasonCache(int id) async {}
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => null;
  @override Future<void> cacheClubConfig(String json) async {}
  @override Future<String?> getCachedPlayers() async => null;
  @override Future<void> cachePlayers(String json) async {}
  @override Future<String?> getCachedClubSeasons() async => seasons;
  @override Future<void> cacheClubSeasons(String json) async => seasons = json;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore(this.result) : super(dio: Dio());
  final Future<List<ClubSeason>?> Function() result;
  @override
  Future<List<ClubSeason>?> fetchClubSeasons(String projectId) => result();
}

const _s32 = ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 12, startDate: '2026-12-01');

ProviderContainer _container(_MemCache cache, FirestoreService? firestore) {
  final c = ProviderContainer(overrides: [
    envJsonProvider.overrideWith((ref) async => const <String, String>{}),
    seasonCacheServiceProvider.overrideWithValue(cache),
    firestoreServiceProvider.overrideWithValue(firestore),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live club seasons are appended to the bundled config and cached', () async {
    final cache = _MemCache();
    final c = _container(cache, _FakeFirestore(() async => [_s32]));
    await c.read(parsedConfigProvider.future);
    final last = c.read(seasonConfigsProvider).last;
    expect(last.id, 32);
    expect(last.smallLeagueMinGames, 12);
    expect(jsonDecode(cache.seasons!), [_s32.toJson()]);
  });

  test('a failed fetch falls back to the cached seasons', () async {
    final cache = _MemCache()..seasons = jsonEncode([_s32.toJson()]);
    final c = _container(cache, _FakeFirestore(() async => throw DioException(requestOptions: RequestOptions())));
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 32);
  });

  test('invalid live seasons are ignored and not cached', () async {
    final cache = _MemCache();
    final c = _container(cache, _FakeFirestore(() async => const [
          ClubSeason(id: 40, title: 'Gap', smallLeagueMinGames: 15, startDate: '2026-12-01'),
        ]));
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 31);
    expect(cache.seasons, isNull);
  });

  test('no firestore and no cache: the JSON seasons only', () async {
    final c = _container(_MemCache(), null);
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 31);
  });
}
```

(`seasonConfigsProvider` returns the parsed seasons; `SeasonConfig.smallLeagueMinGames` — use the real field name from `season_config.dart` if it differs, and ledger it.)

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/providers/club_seasons_provider_test.dart`
Expected: FAIL — `getCachedClubSeasons` not defined.

- [ ] **Step 7: Implement**

`season_cache_service.dart` — add:

```dart
  /// The last fetched Firestore `config/seasons` list (ClubSeason JSON).
  Future<String?> getCachedClubSeasons();

  Future<void> cacheClubSeasons(String jsonData);
```

`asset_season_cache_service.dart` — add (the build's merged `remote_config.json` snapshot already contains them):

```dart
  @override
  Future<String?> getCachedClubSeasons() async => null;

  @override
  Future<void> cacheClubSeasons(String jsonData) async {}
```

`io_season_cache_service.dart` — add:

```dart
  // ── Club seasons cache ──────────────────────────────────────────────────

  @override
  Future<String?> getCachedClubSeasons() async {
    final dir = await _getCacheDir();
    final file = File('$dir/club_seasons.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  @override
  Future<void> cacheClubSeasons(String jsonData) async {
    final dir = await _getCacheDir();
    await File('$dir/club_seasons.json').writeAsString(jsonData);
  }
```

The three test fakes gain:

```dart
  @override Future<String?> getCachedClubSeasons() async => null;
  @override Future<void> cacheClubSeasons(String json) async {}
```

`app_providers.dart` — import `club_season.dart`, `empty_seasons.dart`; change `_parseConfig` so the season maps pass through a hook:

```dart
_ParsedConfig _parseConfig(String json,
    {String? bundledJsonForTournamentsFallback, List<ClubSeason> clubSeasons = const []}) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final jsonSeasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  final seasons = appendClubSeasons(jsonSeasons, _validFor(jsonSeasons, clubSeasons));
  final tournaments = bundledJsonForTournamentsFallback == null
      ? parseTournaments(map)
      : tournamentsWithBundledFallback(map, bundledJsonForTournamentsFallback);
  return _ParsedConfig(
    seasons.map((e) => SeasonConfig.fromJson(e)).toList(),
    tournaments,
  );
}

/// Club seasons only when they continue this JSON's ids; a config with them
/// already merged (the build's snapshot) keeps its own copy.
List<ClubSeason> _validFor(List<Map<String, dynamic>> jsonSeasons, List<ClubSeason> club) {
  if (club.isEmpty) return club;
  final last = lastSeasonId(jsonSeasons);
  if (club.first.id <= last) return const []; // already in this config
  final errors = clubSeasonErrors(club, lastJsonId: last);
  if (errors.isEmpty) return club;
  debugPrint('config/seasons ignored: ${errors.join('; ')}');
  return const [];
}

/// Firestore `config/seasons`: live (cached when it parses), else the cached
/// copy, else none.
Future<List<ClubSeason>> _clubSeasons(Ref ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  if (firestore != null) {
    try {
      final live = await firestore.fetchClubSeasons(kFirebaseProjectId);
      if (live != null) return live;
    } catch (e) {
      debugPrint('Club seasons fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedClubSeasons();
    if (cached != null) return parseClubSeasons(jsonDecode(cached));
  } catch (e) {
    debugPrint('Cached club seasons unavailable: $e');
  }
  return const [];
}
```

In `parsedConfigProvider`, first line after reading `env`: `final club = await _clubSeasons(ref);` and pass `clubSeasons: club` to each of the three `_parseConfig` calls. Caching happens only for a live list that validated: right after a successful `_parseConfig(..., clubSeasons: club)` in each branch, add

```dart
      if (club.isNotEmpty && parsed.seasons.any((s) => s.id == club.first.id)) {
        await cacheService.cacheClubSeasons(jsonEncode([for (final s in club) s.toJson()]));
      }
```

(restructure each `return _parseConfig(…)` into `final parsed = _parseConfig(…); <cache>; return parsed;`). Cached-from-cache rewrites are harmless.

`initialLoadProvider` — replace

```dart
  final latestConfig = configs.last;
  final latestJson = await dataService.loadSeasonJson(latestConfig);

  if (latestJson == null) {
    throw Exception('Failed to load latest season: ${latestConfig.title}');
  }
```

with

```dart
  // The newest season with games: one just created on /seasons/edit/ has none yet.
  final latestLoad = await latestWithGames(configs, dataService.loadSeasonJson);
  if (latestLoad == null) {
    throw Exception('Failed to load latest season: ${configs.last.title}');
  }
  final (latestConfig, latestJson) = latestLoad;
```

and in `backgroundLoadProvider`'s `for (final config in remote)` loop change the `if (json != null)` to `if (json != null && !isEmptyFirestoreSnapshot(json))`.

- [ ] **Step 8: Run to verify it passes, then the full suite**

Run: `flutter test test/providers/ test/services/ > /tmp/sc-t4.log 2>&1; tail -1 /tmp/sc-t4.log; flutter test > /tmp/sc-all.log 2>&1; tail -1 /tmp/sc-all.log; flutter analyze 2>&1 | tail -1`
Expected: all pass; `No issues found!`.

- [ ] **Step 9: Commit**

```bash
git add lib/services/season_cache_service.dart lib/services/asset_season_cache_service.dart lib/services/io_season_cache_service.dart lib/services/empty_seasons.dart lib/providers/app_providers.dart test/providers/club_seasons_provider_test.dart test/services/empty_seasons_test.dart test/providers/club_config_provider_test.dart test/services/firestore_service_test.dart test/providers/players_json_provider_test.dart
git commit -m "feat: the app appends club seasons and skips seasons without games"
```

---

### Task 5: TS season logic

**Files:**
- Create: `site/src/lib/seasons/seasons.ts`
- Test: `site/src/lib/seasons/seasons.test.ts`

**Interfaces:**
- Consumes: fixture `test/fixtures/club_season_cases.json`.
- Produces:
  - `interface ClubSeason { id: number; title: string; smallLeagueMinGames: number; startDate: string }`
  - `seasonErrors(list: ClubSeason[], lastJsonId: number): string[]`
  - `nextSeason(list: ClubSeason[], lastJsonId: number, jsonMinGames: number, today: string): ClubSeason`
  - `hostDefaultSeason(list: ClubSeason[], today: string, fallback: number | null): number | null`
  - `toSeasons(raw: unknown): ClubSeason[]`

- [ ] **Step 1: Write the failing test** `site/src/lib/seasons/seasons.test.ts`

```ts
import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { hostDefaultSeason, nextSeason, seasonErrors, toSeasons, type ClubSeason } from './seasons';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/club_season_cases.json', import.meta.url), 'utf8')) as
  { case: string; lastJsonId: number; seasons: ClubSeason[]; valid: boolean }[];
const S = (id: number, startDate: string, min = 15): ClubSeason => ({ id, title: `Season ${id}`, smallLeagueMinGames: min, startDate });

describe('seasonErrors', () => {
  it('matches every shared case (same fixture as the Dart test)', () => {
    for (const c of cases) expect(seasonErrors(c.seasons, c.lastJsonId).length === 0, c.case).toBe(c.valid);
  });
  it('more than 100 is invalid', () => {
    expect(seasonErrors(Array.from({ length: 101 }, (_, i) => S(32 + i, '2026-12-01')), 31)).not.toEqual([]);
  });
});

describe('nextSeason', () => {
  it('the first club season follows the JSON and copies its minimum', () => {
    expect(nextSeason([], 31, 15, '2026-11-20')).toEqual(S(32, '2026-11-20'));
  });
  it('later seasons follow the list and copy the previous minimum', () => {
    expect(nextSeason([S(32, '2026-12-01', 12)], 31, 15, '2027-03-01')).toEqual(S(33, '2027-03-01', 12));
  });
});

describe('hostDefaultSeason', () => {
  const list = [S(32, '2026-12-01'), S(33, '2027-03-01')];
  it('the newest season that has started', () => {
    expect(hostDefaultSeason(list, '2027-01-15', 31)).toBe(32);
    expect(hostDefaultSeason(list, '2027-03-01', 31)).toBe(33);
  });
  it('before any start date: the fallback', () => {
    expect(hostDefaultSeason(list, '2026-11-30', 31)).toBe(31);
    expect(hostDefaultSeason([], '2026-11-30', null)).toBeNull();
  });
});

describe('toSeasons', () => {
  it('reads Firestore data and drops malformed entries', () => {
    expect(toSeasons([S(32, '2026-12-01'), { id: '33' }, null])).toEqual([S(32, '2026-12-01')]);
    expect(toSeasons(undefined)).toEqual([]);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd site && npx vitest run src/lib/seasons`
Expected: FAIL — `./seasons` does not exist.

- [ ] **Step 3: Implement** `site/src/lib/seasons/seasons.ts`

```ts
// Club seasons 32+ (Firestore config/seasons): validation shared with Dart
// (test/fixtures/club_season_cases.json), defaults for /seasons/edit/, /host/'s default season. Pure.
export interface ClubSeason { id: number; title: string; smallLeagueMinGames: number; startDate: string }

export const MAX_SEASONS = 100;

function realDate(s: string): boolean {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return false;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  return d.getUTCFullYear() === +m[1] && d.getUTCMonth() === +m[2] - 1 && d.getUTCDate() === +m[3];
}

export function seasonErrors(list: ClubSeason[], lastJsonId: number): string[] {
  const errors: string[] = [];
  if (list.length > MAX_SEASONS) errors.push(`${list.length} seasons, the limit is ${MAX_SEASONS}`);
  list.forEach((s, i) => {
    const want = lastJsonId + 1 + i;
    if (s.id !== want) errors.push(`season ${s.id}: expected id ${want}`);
    const t = s.title.trim().length;
    if (t < 1 || t > 40) errors.push(`season ${s.id}: title must be 1–40 characters`);
    if (!Number.isInteger(s.smallLeagueMinGames) || s.smallLeagueMinGames < 1 || s.smallLeagueMinGames > 100) {
      errors.push(`season ${s.id}: small league minimum must be 1–100`);
    }
    if (!realDate(s.startDate)) errors.push(`season ${s.id}: start date "${s.startDate}" is not a YYYY-MM-DD date`);
  });
  return errors;
}

/** Defaults for «Create season N»: next id, `Season N`, the previous season's minimum, today. */
export function nextSeason(list: ClubSeason[], lastJsonId: number, jsonMinGames: number, today: string): ClubSeason {
  const prev = list.at(-1);
  const id = (prev?.id ?? lastJsonId) + 1;
  return { id, title: `Season ${id}`, smallLeagueMinGames: prev?.smallLeagueMinGames ?? jsonMinGames, startDate: today };
}

/** The newest club season whose start date has come, else [fallback]. */
export function hostDefaultSeason(list: ClubSeason[], today: string, fallback: number | null): number | null {
  const started = list.filter((s) => s.startDate <= today);
  return started.length ? started[started.length - 1].id : fallback;
}

export function toSeasons(raw: unknown): ClubSeason[] {
  return (Array.isArray(raw) ? raw : []).filter((s): s is ClubSeason =>
    !!s && typeof s === 'object' && Number.isInteger(s.id) && typeof s.title === 'string'
      && Number.isInteger(s.smallLeagueMinGames) && typeof s.startDate === 'string')
    .map((s) => ({ id: s.id, title: s.title, smallLeagueMinGames: s.smallLeagueMinGames, startDate: s.startDate }));
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd site && npx vitest run src/lib/seasons`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/seasons/seasons.ts site/src/lib/seasons/seasons.test.ts
git commit -m "feat: season defaults and validation for the site"
```

---

### Task 6: `/seasons/edit/` page

**Files:**
- Create: `site/src/lib/seasons/store.ts`, `site/src/lib/seasons/render.ts`, `site/src/lib/seasons/render.test.ts`, `site/src/pages/seasons/edit.astro`, `site/src/scripts/seasons-edit.ts`

**Interfaces:**
- Consumes: Task 5; `onClubUser`, `signIn`, `signOutUser`, `ClubAdmin`; `esc` from `../annual/render`.
- Produces: `loadClubSeasons(): Promise<ClubSeason[]>`, `createSeason(draft, lastJsonId, u)`, `deleteNewestSeason(id, u)`, `gamesCount(id)`; `seasonRow(...)`.

- [ ] **Step 1: Write the failing render test** `site/src/lib/seasons/render.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { canDelete, seasonRow } from './render';

describe('render', () => {
  it('escapes the title and shows the start date and games', () => {
    const html = seasonRow({ id: 32, title: '<b>x', source: 'Firestore', startDate: '2026-12-01', games: 3 }, { deletable: false, confirming: false });
    expect(html).toContain('&lt;b&gt;x');
    expect(html).toContain('2026-12-01');
    expect(html).toContain('3');
    expect(html).not.toContain('data-act="delete"');
  });
  it('a deletable row has delete, then a confirm step', () => {
    const row = { id: 32, title: 'Season 32', source: 'Firestore', startDate: '2026-12-01', games: 0 };
    expect(seasonRow(row, { deletable: true, confirming: false })).toContain('data-act="delete"');
    expect(seasonRow(row, { deletable: true, confirming: true })).toContain('data-act="delete-ok"');
  });
  it('only the newest club season without games can be deleted', () => {
    const list = [{ id: 32, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01' }, { id: 33, title: 'S', smallLeagueMinGames: 15, startDate: '2027-03-01' }];
    expect(canDelete(list, 33, 0)).toBe(true);
    expect(canDelete(list, 33, 2)).toBe(false);
    expect(canDelete(list, 32, 0)).toBe(false);
    expect(canDelete([], 31, 0)).toBe(false);
  });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd site && npx vitest run src/lib/seasons/render.test.ts`
Expected: FAIL — `./render` does not exist.

- [ ] **Step 3: Implement** `site/src/lib/seasons/render.ts`

```ts
// HTML for /seasons/edit/. Every Firestore value is escaped.
import { esc } from '../annual/render';
import type { ClubSeason } from './seasons';

export interface SeasonRow { id: number; title: string; source: string; startDate: string | null; games: number | null }

export const canDelete = (list: ClubSeason[], id: number, games: number) =>
  list.length > 0 && list[list.length - 1].id === id && games === 0;

export function seasonRow(r: SeasonRow, o: { deletable: boolean; confirming: boolean }): string {
  const del = !o.deletable ? '' : o.confirming
    ? `<button type="button" class="btn primary" data-act="delete-ok" data-id="${r.id}">Delete season ${r.id}</button>
       <button type="button" class="btn" data-act="cancel">Cancel</button>`
    : `<button type="button" class="btn" data-act="delete" data-id="${r.id}">Delete</button>`;
  return `<tr><td class="num">${r.id}</td><td>${esc(r.title)}</td><td>${esc(r.source)}</td>
    <td>${esc(r.startDate ?? '')}</td><td class="num">${r.games ?? ''}</td><td>${del}</td></tr>`;
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `cd site && npx vitest run src/lib/seasons`
Expected: PASS.

- [ ] **Step 5: Write the store** `site/src/lib/seasons/store.ts`

```ts
// Firebase client for config/seasons. Access control lives in firestore.rules (public read, admin write).
import { collection, doc, getCountFromServer, getDoc, query, runTransaction, serverTimestamp, where } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import { seasonErrors, toSeasons, type ClubSeason } from './seasons';

const ref = () => doc(db, 'config', 'seasons');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });

export async function loadClubSeasons(): Promise<ClubSeason[]> {
  const snap = await getDoc(ref());
  return snap.exists() ? toSeasons(snap.data().seasons) : [];
}

export async function gamesCount(season: number): Promise<number> {
  return (await getCountFromServer(query(collection(db, 'games'), where('season', '==', season)))).data().count;
}

/** Appends the next season (id from the fresh document, so two admins never reuse one) and bumps meta/state. */
export async function createSeason(draft: Omit<ClubSeason, 'id'>, lastJsonId: number, u: ClubAdmin): Promise<ClubSeason[]> {
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    const cur = snap.exists() ? toSeasons(snap.data().seasons) : [];
    const id = (cur.at(-1)?.id ?? lastJsonId) + 1;
    const list = [...cur, { id, title: draft.title.trim(), smallLeagueMinGames: draft.smallLeagueMinGames, startDate: draft.startDate }];
    const errors = seasonErrors(list, lastJsonId);
    if (errors.length) throw new Error(errors.join('; '));
    tx.set(ref(), { seasons: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return list;
  });
}

/** Removes the newest season if it still has no games (re-counted right before the write). */
export async function deleteNewestSeason(id: number, u: ClubAdmin): Promise<ClubSeason[]> {
  if ((await gamesCount(id)) > 0) throw new Error(`Season ${id} already has games — it cannot be deleted`);
  return runTransaction(db, async (tx) => {
    const snap = await tx.get(ref());
    const cur = snap.exists() ? toSeasons(snap.data().seasons) : [];
    if (cur.at(-1)?.id !== id) throw new Error(`Season ${id} is not the newest any more — reload`);
    const list = cur.slice(0, -1);
    tx.set(ref(), { seasons: list, ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    return list;
  });
}
```

- [ ] **Step 6: Write the page** `site/src/pages/seasons/edit.astro`

```astro
---
import fs from 'node:fs';
import path from 'node:path';
import Base from '../../layouts/Base.astro';

// The JSON config's seasons (0–31): fixed, shown read-only. Club seasons come live from Firestore.
const root = path.resolve(process.cwd(), '..');
const config = JSON.parse(fs.readFileSync(path.join(root, 'remote_config.json'), 'utf8')) as
  { seasons: { id: number; title: string; source: string; smallLeagueMinGames?: number }[] };
const SOURCE: Record<string, string> = { bundled: 'App', remote: 'Sheet', firestore: 'Firestore' };
const json = config.seasons.map((s) => ({ id: s.id, title: s.title, source: SOURCE[s.source] ?? s.source }));
const last = config.seasons.reduce((a, b) => (b.id > a.id ? b : a));
const data = JSON.stringify({ json, lastJsonId: last.id, jsonMinGames: last.smallLeagueMinGames ?? 15 }).replace(/</g, '\\u003c');
---
<Base title="Edit seasons" description="Admins open new club seasons." active="season">
  <div class="pagehead"><h1 class="display">Seasons</h1><span class="label" id="state">Loading…</span></div>

  <div class="panel access">
    <span class="label">Editing</span> <span id="who">Read-only</span>
    <button type="button" id="sign-in" class="btn primary">Sign in with Google</button>
    <button type="button" id="sign-out" class="btn" hidden>Sign out</button>
    <p class="hint">Admins (hosts with <code>admin: true</code>) can create a season. From its start date hosts get it by default on /host/; it appears on the site after its first game and the next rebuild (within an hour).</p>
  </div>

  <form id="create" class="panel form" hidden>
    <h2 id="create-title">Create season</h2>
    <div class="fields">
      <label>Title <input name="title" maxlength="40" required></label>
      <label>Small league: min games <input name="min" type="number" min="1" max="100" required></label>
      <label>Start date <input name="start" type="date" required></label>
      <button type="submit" class="btn primary">Create</button>
    </div>
  </form>

  <p id="msg" class="msg" role="status"></p>
  <table class="list"><thead><tr><th>#</th><th>Title</th><th>Source</th><th>Start</th><th>Games</th><th></th></tr></thead><tbody id="rows"></tbody></table>

  <script type="application/json" id="seasons-data" set:html={data} />
</Base>

<script>
  import '../../scripts/seasons-edit';
</script>

<style>
  .access { display: flex; flex-wrap: wrap; gap: 8px 12px; align-items: center; margin-bottom: 12px; }
  .hint { flex-basis: 100%; margin: 0; color: var(--muted); }
  .msg:empty { display: none; }
  .msg.error { color: var(--city); }
  .form { display: grid; gap: 8px; margin-bottom: 16px; }
  .form .fields { display: flex; flex-wrap: wrap; gap: 8px; align-items: end; }
  .list { width: 100%; border-collapse: collapse; }
  .list td, .list th { padding: 6px 8px; border-top: 1px solid var(--border); text-align: left; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
</style>
```

- [ ] **Step 7: Write the script** `site/src/scripts/seasons-edit.ts`

```ts
// /seasons/edit/: admins open new club seasons (Firestore config/seasons).
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { createSeason, deleteNewestSeason, gamesCount, loadClubSeasons } from '../lib/seasons/store';
import { nextSeason, type ClubSeason } from '../lib/seasons/seasons';
import { canDelete, seasonRow } from '../lib/seasons/render';

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const page = JSON.parse($('seasons-data').textContent!) as { json: { id: number; title: string; source: string }[]; lastJsonId: number; jsonMinGames: number };
const today = () => new Date().toLocaleDateString('sv-SE'); // YYYY-MM-DD, local day

let user: ClubAdmin | null | 'not-host' = null;
let club: ClubSeason[] = [];
const games = new Map<number, number>();
let confirming: number | null = null;
let busy = false;
const isAdmin = () => typeof user === 'object' && user !== null && user.admin;

function say(text: string, error = false) {
  $('msg').textContent = text;
  $('msg').classList.toggle('error', error);
}

async function refresh() {
  try {
    club = await loadClubSeasons();
    await Promise.all(club.map(async (s) => games.set(s.id, await gamesCount(s.id))));
    $('state').textContent = `${page.json.length + club.length} seasons`;
  } catch (e) {
    $('state').textContent = 'Could not load seasons';
    say(String(e), true);
  }
  render();
}

function render() {
  const rows = [
    ...club.slice().reverse().map((s) => seasonRow({ id: s.id, title: s.title, source: 'Firestore', startDate: s.startDate, games: games.get(s.id) ?? null },
      { deletable: isAdmin() && !busy && canDelete(club, s.id, games.get(s.id) ?? 1), confirming: confirming === s.id })),
    ...page.json.slice().reverse().map((s) => seasonRow({ ...s, startDate: null, games: null }, { deletable: false, confirming: false })),
  ];
  $('rows').innerHTML = rows.join('');
  const f = $('create') as HTMLFormElement;
  f.hidden = !isAdmin();
  const next = nextSeason(club, page.lastJsonId, page.jsonMinGames, today());
  $('create-title').textContent = `Create season ${next.id}`;
  if (!f.dataset.for || f.dataset.for !== String(next.id)) {
    f.dataset.for = String(next.id);
    (f.elements.namedItem('title') as HTMLInputElement).value = next.title;
    (f.elements.namedItem('min') as HTMLInputElement).value = String(next.smallLeagueMinGames);
    (f.elements.namedItem('start') as HTMLInputElement).value = next.startDate;
  }
  f.querySelector('button')!.toggleAttribute('disabled', busy);
  $('who').textContent = user === null ? 'Read-only' : user === 'not-host' ? 'Not a host — read-only' : `${user.name}${user.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = user !== null;
  $('sign-out').hidden = user === null;
}

async function run(work: () => Promise<ClubSeason[]>, done: string) {
  busy = true;
  render();
  try {
    club = await work();
    confirming = null;
    say(`${done} The site updates within an hour.`);
  } catch (e) {
    say((e as Error).message, true);
  } finally {
    busy = false;
    await refresh();
  }
}

$('create').addEventListener('submit', (ev) => {
  ev.preventDefault();
  if (!isAdmin() || busy) return;
  const f = ev.target as HTMLFormElement;
  const v = (n: string) => (f.elements.namedItem(n) as HTMLInputElement).value;
  void run(() => createSeason({ title: v('title'), smallLeagueMinGames: Number(v('min')), startDate: v('start') }, page.lastJsonId, user as ClubAdmin),
    `Season ${nextSeason(club, page.lastJsonId, page.jsonMinGames, today()).id} created.`);
});

document.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLElement>('[data-act]');
  if (!b || !isAdmin() || busy) return;
  const id = Number(b.dataset.id);
  if (b.dataset.act === 'delete') { confirming = id; render(); }
  else if (b.dataset.act === 'cancel') { confirming = null; render(); }
  else if (b.dataset.act === 'delete-ok') void run(() => deleteNewestSeason(id, user as ClubAdmin), `Season ${id} deleted.`);
});

$('sign-in').addEventListener('click', () => void signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => void signOutUser());
onClubUser((u) => { user = u; render(); });
void refresh();
```

- [ ] **Step 8: Type-check, test, build**

Run: `cd site && npx vitest run src/lib/seasons && npx astro check 2>&1 | grep -A3 Result && npm run build 2>&1 | tail -1 && ls dist/seasons/edit/`
Expected: tests pass; `0 errors`; check-dist success; `index.html`.

- [ ] **Step 9: Commit**

```bash
git add site/src/lib/seasons site/src/pages/seasons/edit.astro site/src/scripts/seasons-edit.ts
git commit -m "feat: /seasons/edit/ — admins create club seasons"
```

---

### Task 7: `/host/` default season from the start date

**Files:**
- Modify: `site/src/scripts/host.ts`

**Interfaces:**
- Consumes: Task 5 `hostDefaultSeason`; Task 6 `loadClubSeasons`.

- [ ] **Step 1: Implement** — in `host.ts` import `loadClubSeasons` from `'../lib/seasons/store'` and `hostDefaultSeason` from `'../lib/seasons/seasons'`. After `let form: FormState = emptyForm(page.defaultSeason, today());` add:

```ts
// The live default: the newest club season whose start date has come (config/seasons),
// else the build's. A form still on the old default follows it.
const seasonReady = loadClubSeasons().then((list) => {
  const d = hostDefaultSeason(list, today(), page.defaultSeason);
  if (d === page.defaultSeason) return;
  const old = page.defaultSeason;
  page.defaultSeason = d;
  if (form.season === old) form.season = d;
}).catch(() => { /* keep the build's default */ });
```

and in `onUser`, before `$<HTMLInputElement>('l-season').value = …`, add `await seasonReady;`. If `page` is typed readonly, make `defaultSeason` mutable in its cast. `today()` here is the club-evening date (`eveningDate()`), already `YYYY-MM-DD` — check `eveningDate`'s return format and ledger if it differs.

- [ ] **Step 2: Test and build**

Run: `cd site && npm test 2>&1 | grep "Tests " && npx astro check 2>&1 | grep -A1 Result && npm run build 2>&1 | tail -1`
Expected: all site tests pass (the default logic is covered by `hostDefaultSeason` tests in Task 5); `0 errors`; build succeeds.

- [ ] **Step 3: Commit**

```bash
git add site/src/scripts/host.ts
git commit -m "feat: /host/ defaults to the club season whose start date has come"
```

---

### Task 8: Docs and full verification

**Files:**
- Modify: `CLAUDE.md` («Adding a New Season» section and the Web site bullets)

- [ ] **Step 1: Docs** — at the top of «## Adding a New Season» add:

```markdown
**Club seasons (32+):** admins create them on `/seasons/edit/` (Firestore `config/seasons`: title,
small-league minimum, start date; id = last + 1). The prefetch appends them to the `remote_config.json`
snapshot and snapshots their games; the app appends them in `parsedConfigProvider` (live → cache).
A season with no games yet is skipped by the app and the site; `/host/` offers it from its start date.
`remote_config.json` keeps seasons 0–31 — do not add new seasons there.
```

- [ ] **Step 2: Full verification**

Run:
```bash
flutter analyze 2>&1 | tail -1
flutter test > /tmp/sc-all.log 2>&1; tail -1 /tmp/sc-all.log
(cd site && npm test 2>&1 | grep "Tests ")
(cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test 2>&1 | grep "Tests ")
flutter test tool/export_site_data_test.dart 2>&1 | tail -1
(cd site && npm run build 2>&1 | tail -1)
```
Expected: no issues; all pass; rules 69; export passes; build succeeds.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: club seasons in CLAUDE.md"
```

---

## Rollout (needs the user's go-ahead)

1. Publish the `config/seasons` rule in the Firebase console **before** pushing (the prefetch reads `config/seasons`; without the rule CI gets 403, as happened with `config/players`).
2. Push `feature/flutter_migration` and fast-forward `master`.
3. Verify the deploy succeeds and `/seasons/edit/` lists seasons 0–31; `config/seasons` reads 404 until the first season is created.
4. Season 32 is created by an admin when the club is ready (December).
