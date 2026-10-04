# Game Hosting (Stage 1: Protocol Form) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hosts record finished games on a new site page `/host/`; games live in Firebase Firestore and load into the app and the stats site like sheet seasons do.

**Architecture:** Firestore (free Spark plan) holds `games`, `hosts`, `meta/state`. The Astro site gets a client-side `/host/` page using the Firebase JS SDK (Google sign-in, form, transactional save). The Dart app gains a third season source `firestore`, read over the Firestore REST API with Dio; documents map straight to `Game`. An hourly GitHub Action rebuilds the site only when `meta/state.updatedAt` changed.

**Tech Stack:** Dart/Flutter 3.41 (Riverpod, freezed, Dio), Astro 7 + TypeScript + Vitest, Firebase JS SDK v12 (`firebase`), Firestore security rules + `@firebase/rules-unit-testing`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-05-game-hosting-design.md`

## Global Constraints

- Firebase **Spark (free) plan only**; no Cloud Functions, no Blaze.
- Firestore reads are public; writes only by emails in `hosts`; update by creator or admin, **no time limit**; delete by admin only.
- Season 32 is the first Firestore season; season 31 stays in its sheet; no import of old seasons.
- Role strings stored exactly as `"Мирний" | "Мафія" | "Дон" | "Шериф"`; result as `"city" | "mafia" | "unrated"`.
- `penalty` and `protocolPenalty` are stored **negative or 0** (penalties are added, never subtracted). The form shows them as positive numbers and stores `-Math.abs(x)`.
- ОП and the win point are **computed, never stored**.
- Protocol entries only for players killed at night: `{slot, version: number|null, color: {slot, black}|null}`.
- Host is **required, empty by default**; up to 2 tables; game number counts per table per date.
- The `/host/` page UI is in Ukrainian (matches the club's sheet vocabulary); nav label «Провести гру».
- The built site may contain exactly one `AIza…` string: the Firebase web API key. Any other `AIza` still fails `check-dist`.
- Push to **both** `feature/flutter_migration` and `master` when workflows change (schedules run from master).
- Commit trailer on every commit:
  ```
  Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Md1aToVB8fxFCxrPyMYUbm
  ```

## Review Focus

1. **Penalty sign typed by hand** — a host types `0.5` or `-0.5` into Штраф; both must store `-0.5` (pinned in Task 7 `formToDoc` test).
2. **Reload mid-entry** — refreshing `/host/` or reopening the tab restores the draft for that game, and a draft for game A never overwrites game B (pinned in Task 7 `draftKey` test + Task 9 manual check).
3. **Firestore season with zero games / unreachable network** — app and export must not crash; an empty season yields no games, a network failure falls back to cache, and the export reads the snapshot (pinned in Task 3 and Task 4 tests).
4. **Duplicate player names that differ only by case/space** (`"Seezov"` vs `"seezov "`) — treated as duplicates in validation (pinned in Task 7 test).
5. **A non-host or a different host editing someone's game** — rules reject it (pinned in Task 6 rules tests).

---

## File Structure

**Dart (app + build)**
- Modify `lib/services/rating_formulas.dart` — add `calculateSupportFivePoints`.
- Modify `lib/models/game.dart`, `lib/models/protocol_entry.dart` — `fouls`, `sheriffVersion`.
- Create `lib/services/firestore_games.dart` — Firestore value decoding, `gameFromFirestore`, `gamesFromFirestoreSnapshot`.
- Create `lib/services/firestore_service.dart` — REST `runQuery` over Dio.
- Modify `lib/models/season_config.dart` — `FirestoreSource`.
- Modify `lib/services/season_data_service.dart`, `lib/services/src/game_parsing.dart`, `lib/services/src/isolate_functions.dart`, `lib/providers/app_providers.dart`, `lib/site_export/load_container.dart`, `tool/prefetch_seasons.dart`.

**Firebase**
- Create `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json` (repo root).
- Create `firebase/rules-test/package.json`, `firebase/rules-test/rules.test.ts`, `firebase/rules-test/vitest.config.ts`.

**Site**
- Create `site/src/lib/hosting/types.ts` — game document types.
- Create `site/src/lib/hosting/points.ts` (+ `points.test.ts`) — ОП + win point.
- Create `site/src/lib/hosting/validate.ts` (+ `validate.test.ts`) — errors/warnings.
- Create `site/src/lib/hosting/form.ts` (+ `form.test.ts`) — form state ⇄ document, draft key, next game number.
- Create `site/src/lib/hosting/firebase-config.ts` — public web config.
- Create `site/src/lib/hosting/store.ts` — Firebase client: auth, list, save.
- Create `site/src/pages/host/index.astro`, `site/src/scripts/host.ts`.
- Modify `site/src/layouts/Base.astro` (nav), `site/scripts/check-dist.mjs` (key allowlist), `site/package.json` (`firebase`).

**CI**
- Create `.github/workflows/games-watch.yml`, `.github/workflows/firestore-rules.yml`.

---

### Task 1: Firebase project (owner, guided) + config files

The owner must do the console steps (needs their Google account). The executor gives these instructions, waits for the values, then commits the files.

**Files:**
- Create: `.firebaserc`, `firebase.json`, `firestore.indexes.json`
- Create: `site/src/lib/hosting/firebase-config.ts`

**Interfaces:**
- Produces: `FIREBASE_PROJECT_ID` (string, used in Tasks 4/6/10/11), `firebaseConfig` export from `site/src/lib/hosting/firebase-config.ts`, `FIREBASE_WEB_API_KEY` (used in Task 9 `check-dist` allowlist).

- [ ] **Step 1: Give the owner the console steps and wait**

Send the owner exactly this:

```
1. https://console.firebase.google.com → «Створити проєкт» → назва family-mafia-club
   (Google Analytics — вимкнути). Тариф лишається Spark (безкоштовний).
2. Build → Firestore Database → Create database → регіон eur3 (europe-west) →
   «Start in production mode».
3. Build → Authentication → Get started → Sign-in method → Google → Enable.
   Authentication → Settings → Authorized domains → Add domain: seezov.github.io
4. Project settings (шестерня) → General → Your apps → Web (</>) → назва host-page
   (Hosting НЕ вмикати) → скопіюй об'єкт firebaseConfig і надішли мені.
5. Firestore → Data → Start collection "hosts" → Document ID = твій email →
   поля: name (string) = твоє ім'я в клубі, admin (boolean) = true.
```

Wait for the `firebaseConfig` object. Record `projectId` as `FIREBASE_PROJECT_ID` and `apiKey` as `FIREBASE_WEB_API_KEY`.

- [ ] **Step 2: Write the config files**

`.firebaserc`:
```json
{ "projects": { "default": "<FIREBASE_PROJECT_ID>" } }
```

`firebase.json`:
```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "emulators": { "firestore": { "port": 8080 }, "singleProjectMode": true }
}
```

`firestore.indexes.json` (only single-field `season ==` queries are used, which need no composite index):
```json
{ "indexes": [], "fieldOverrides": [] }
```

`site/src/lib/hosting/firebase-config.ts` (paste the owner's values verbatim):
```ts
// Public Firebase web config. The apiKey only identifies the project; access is
// controlled by firestore.rules. check-dist.mjs allows exactly this key.
export const firebaseConfig = {
  apiKey: '<FIREBASE_WEB_API_KEY>',
  authDomain: '<FIREBASE_PROJECT_ID>.firebaseapp.com',
  projectId: '<FIREBASE_PROJECT_ID>',
  storageBucket: '<from owner>',
  messagingSenderId: '<from owner>',
  appId: '<from owner>',
};
```

- [ ] **Step 3: Commit**

```bash
git add .firebaserc firebase.json firestore.indexes.json site/src/lib/hosting/firebase-config.ts
git commit -m "chore(firebase): project config for game hosting"
```

---

### Task 2: ОП formula in Dart (`calculateSupportFivePoints`)

**Files:**
- Modify: `lib/services/rating_formulas.dart` (append)
- Test: `test/services/rating_formulas_test.dart` (append group)

**Interfaces:**
- Produces: `double calculateSupportFivePoints(List<int> supportFive, List<String> roles)` — `supportFive` signed slots (+ red, − black), `roles` 10 role strings in slot order. Returns −0.1 when `supportFive` is empty.

- [ ] **Step 1: Write the failing tests** (append inside `main()`)

```dart
  // ── calculateSupportFivePoints (season-30 sheet formula) ─────────────────

  group('calculateSupportFivePoints', () {
    // Season 30 game 1: 1 Мирний, 5 Мафія, 7 Дон; Опорна 5 = 1, 5, 7 (all "red")
    const roles = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія',
                   'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];

    test('sheet game: 1,5,7 all red → -0.15', () {
      expect(calculateSupportFivePoints([1, 5, 7], roles), closeTo(-0.15, 1e-9));
    });
    test('empty → -0.1', () {
      expect(calculateSupportFivePoints([], roles), -0.1);
    });
    test('all three blacks found → 0.9', () {
      expect(calculateSupportFivePoints([-5, -7, -9], roles), closeTo(0.9, 1e-9));
    });
    test('one black miss → -0.1', () {
      expect(calculateSupportFivePoints([-1], roles), closeTo(-0.1, 1e-9));
    });
    test('two blacks hit + two reds hit → 0.55 + 0.2 = 0.75', () {
      expect(calculateSupportFivePoints([-5, -9, 1, 2], roles), closeTo(0.75, 1e-9));
    });
    test('five black guesses, three hit → 0.9 + (mMiss5 - mMiss3) = 0.9 - 2.0', () {
      expect(calculateSupportFivePoints([-5, -7, -9, -1, -2], roles),
          closeTo(0.9 + (-2.45 - -0.45), 1e-9));
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/services/rating_formulas_test.dart`
Expected: compile error `The function 'calculateSupportFivePoints' isn't defined`.

- [ ] **Step 3: Implement** (append to `lib/services/rating_formulas.dart`)

```dart
// ── Опорна 5 (ОП) — port of the season-30 sheet formula ──────────────────
// supportFive: signed slots, positive = called red, negative = called black.
// Only the first-killed player (ПУ) gets this value.

const _supportMafiaSuccess = [0.0, 0.25, 0.55, 0.9, 0.9, 0.9];
const _supportMafiaMiss = [0.0, -0.1, -0.25, -0.45, -1.45, -2.45];
const _supportCityMiss = [0.0, -0.1, -0.2, -0.35, -0.55, -0.8];

double calculateSupportFivePoints(List<int> supportFive, List<String> roles) {
  final guesses = supportFive.where((g) => g != 0).toList();
  if (guesses.isEmpty) return -0.1;
  bool isBlack(int g) =>
      Role.findByValue(roles[g.abs() - 1])?.isBlack ?? false;
  final nMaf = guesses.where((g) => g < 0).length;
  final kMaf = guesses.where((g) => g < 0 && isBlack(g)).length;
  final nCit = guesses.where((g) => g > 0).length;
  final kCit = guesses.where((g) => g > 0 && !isBlack(g)).length;
  return _supportMafiaSuccess[kMaf] +
      (_supportMafiaMiss[nMaf] - _supportMafiaMiss[kMaf]) +
      0.1 * kCit +
      (_supportCityMiss[nCit] - _supportCityMiss[kCit]);
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/services/rating_formulas_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/rating_formulas.dart test/services/rating_formulas_test.dart
git commit -m "feat: Опорна 5 points formula ported from the season-30 sheet"
```

---

### Task 3: Firestore document → `Game` (models + mapper + loader dispatch)

**Files:**
- Modify: `lib/models/game.dart` (add `List<int>? fouls`)
- Modify: `lib/models/protocol_entry.dart` (add `int? sheriffVersion`)
- Create: `lib/services/firestore_games.dart`
- Modify: `lib/services/src/game_parsing.dart` (add `_parseSeasonGames`)
- Modify: `lib/services/src/isolate_functions.dart` (use it in both loops)
- Modify: `lib/services/season_loader.dart` (import + test hook)
- Test: `test/services/firestore_games_test.dart`

**Interfaces:**
- Consumes: `calculateSupportFivePoints` (Task 2).
- Produces:
  - `Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields)` — Firestore REST typed values → plain JSON.
  - `Game gameFromFirestore(int seasonId, Map<String, dynamic> doc)` — `doc` is a plain map in the spec's `games/{id}` shape.
  - `List<Game> gamesFromFirestoreSnapshot(int seasonId, Map<String, dynamic> snapshot)` — `snapshot = {"format": "firestore", "games": [doc, ...]}`, sorted by `date, table, gameNumber`.
  - Season JSON contract: a firestore season's JSON string is that snapshot object; a sheet season's is a JSON list. `_parseSeasonGames(int seasonId, String json)` handles both.
  - `@visibleForTesting List<Game> parseSeasonJsonForTest(int seasonId, String json)`.

- [ ] **Step 1: Extend the models**

In `lib/models/game.dart` add after `DateTime? date,`:
```dart
    List<int>? fouls, // per slot 0..4; null for sheet seasons (fouls are not parsed there)
```
In `lib/models/protocol_entry.dart` replace the factory body:
```dart
  const factory ProtocolEntry({
    required int killedSlot, // 1-indexed slot that was killed
    @Default([]) List<int> colorGuesses, // signed ints: abs=slot, positive=red, negative=black
    int? sheriffVersion, // slot the killed player names as sheriff (season 32+), null = none
  }) = _ProtocolEntry;
```
Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: regenerates `game.freezed.dart`, `protocol_entry.freezed.dart` with no errors.

- [ ] **Step 2: Write the failing tests** — `test/services/firestore_games_test.dart`

```dart
import 'dart:convert';

import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/services/firestore_games.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> seat(String player, String role,
        {double add = 0, double pen = 0, int fouls = 0}) =>
    {'player': player, 'role': role, 'fouls': fouls, 'additional': add,
     'penalty': pen, 'protocolAdditional': 0, 'protocolPenalty': 0};

Map<String, dynamic> doc({String date = '2026-12-03', int table = 1, int n = 1,
        String result = 'city'}) => {
      'season': 32, 'date': date, 'table': table, 'gameNumber': n,
      'host': 'Серпень',
      'seats': [
        seat('Німфа', 'Мирний'), seat('Таті', 'Мирний', add: 0.3),
        seat('Фенікс', 'Мирний'), seat('Green', 'Шериф', add: 0.5),
        seat('NSpace', 'Мафія'), seat('Сирник', 'Мирний', pen: -0.5, fouls: 3),
        seat('Seezov', 'Дон', add: 0.4), seat('Флекс', 'Мирний'),
        seat('Вітамінка', 'Мафія'), seat('Шпак', 'Мирний'),
      ],
      'firstKilled': 6,
      'supportFive': [1, 5, 7],
      'protocol': [
        {'slot': 6, 'version': 4, 'color': {'slot': 5, 'black': true}},
        {'slot': 2, 'version': null, 'color': null},
      ],
      'result': result,
      'comments': [],
    };

void main() {
  group('decodeFirestoreFields', () {
    test('decodes every value type used by games', () {
      final fields = {
        's': {'stringValue': 'x'},
        'i': {'integerValue': '32'},
        'd': {'doubleValue': 0.3},
        'b': {'booleanValue': true},
        'n': {'nullValue': null},
        't': {'timestampValue': '2026-12-03T20:00:00Z'},
        'a': {'arrayValue': {'values': [{'integerValue': '1'}, {'integerValue': '-5'}]}},
        'e': {'arrayValue': {}},
        'm': {'mapValue': {'fields': {'slot': {'integerValue': '5'}}}},
      };
      expect(decodeFirestoreFields(fields), {
        's': 'x', 'i': 32, 'd': 0.3, 'b': true, 'n': null,
        't': '2026-12-03T20:00:00Z', 'a': [1, -5], 'e': [], 'm': {'slot': 5},
      });
    });
  });

  group('gameFromFirestore', () {
    final g = gameFromFirestore(32, doc());

    test('seats, roles, points, fouls', () {
      expect(g.players.first, 'Німфа');
      expect(g.roles[3], 'Шериф');
      expect(g.additionalPoints![1], 0.3);
      expect(g.penaltyPoints![5], -0.5);
      expect(g.fouls![5], 3);
      expect(g.protocolAdditionalPoints, hasLength(10));
    });
    test('result → cityWon', () {
      expect(g.cityWon, true);
      expect(gameFromFirestore(32, doc(result: 'mafia')).cityWon, false);
      expect(gameFromFirestore(32, doc(result: 'unrated')).cityWon, null);
    });
    test('ОП computed for the first killed from Опорна 5', () {
      expect(g.firstKilled, 6);
      expect(g.bestMovePoints, closeTo(-0.15, 1e-9));
      expect(g.supportFive, [1, 5, 7]);
    });
    test('no first killed → 0 ОП', () {
      final d = doc()..['firstKilled'] = 0;
      expect(gameFromFirestore(32, d).bestMovePoints, 0.0);
    });
    test('protocol keeps one colour as a signed guess and the version', () {
      expect(g.protocol, [
        const ProtocolEntry(killedSlot: 6, colorGuesses: [-5], sheriffVersion: 4),
        const ProtocolEntry(killedSlot: 2),
      ]);
    });
    test('host and date', () {
      expect(g.host, 'Серпень');
      expect(g.date, DateTime.utc(2026, 12, 3));
    });
    test('is a normal game', () => expect(g.isNormalGame(), true));
  });

  group('gamesFromFirestoreSnapshot', () {
    test('sorts by date, table, game number', () {
      final games = gamesFromFirestoreSnapshot(32, {
        'format': 'firestore',
        'games': [
          doc(date: '2026-12-10', n: 1),
          doc(date: '2026-12-03', table: 2, n: 1),
          doc(date: '2026-12-03', table: 1, n: 2),
          doc(date: '2026-12-03', table: 1, n: 1),
        ],
      });
      expect(games.map((g) => g.date!.day), [3, 3, 3, 10]);
    });
    test('empty season → no games', () {
      expect(gamesFromFirestoreSnapshot(32, {'format': 'firestore', 'games': []}), isEmpty);
    });
  });

  group('season JSON dispatch', () {
    test('a firestore snapshot string parses through the loader', () {
      final json = jsonEncode({'format': 'firestore', 'games': [doc()]});
      expect(parseSeasonJsonForTest(32, json).single.host, 'Серпень');
    });
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/services/firestore_games_test.dart`
Expected: compile errors (`firestore_games.dart` missing, `parseSeasonJsonForTest` undefined).

- [ ] **Step 4: Implement `lib/services/firestore_games.dart`**

```dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/services/rating_formulas.dart';

// Games recorded on the site's /host/ page (Firestore, season 32+).
// The season JSON for a firestore season is {"format": "firestore", "games": [...]},
// each game a plain map in the shape documented in the game-hosting spec.

const firestoreSnapshotFormat = 'firestore';

/// Firestore REST typed values (`{"integerValue": "3"}` …) → plain JSON.
Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields) =>
    fields.map((k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)));

Object? _decodeValue(Map<String, dynamic> v) {
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('arrayValue')) {
    final values = (v['arrayValue'] as Map)['values'] as List? ?? const [];
    return values.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
  }
  if (v.containsKey('mapValue')) {
    final f = (v['mapValue'] as Map)['fields'] as Map<String, dynamic>? ?? const {};
    return decodeFirestoreFields(f);
  }
  return null; // nullValue and anything unknown
}

double _num(Object? v) => (v as num?)?.toDouble() ?? 0.0;

bool? _cityWon(Object? result) => switch (result) {
      'city' => true,
      'mafia' => false,
      _ => null,
    };

Game gameFromFirestore(int seasonId, Map<String, dynamic> doc) {
  final seats = (doc['seats'] as List).cast<Map<String, dynamic>>();
  final roles = [for (final s in seats) s['role'] as String];
  final firstKilled = (doc['firstKilled'] as num?)?.toInt() ?? 0;
  final supportFive =
      ((doc['supportFive'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  final protocol = [
    for (final p in ((doc['protocol'] as List?) ?? const []).cast<Map<String, dynamic>>())
      ProtocolEntry(
        killedSlot: (p['slot'] as num).toInt(),
        colorGuesses: switch (p['color']) {
          {'slot': final num slot, 'black': final bool black} =>
            [black ? -slot.toInt() : slot.toInt()],
          _ => const [],
        },
        sheriffVersion: (p['version'] as num?)?.toInt(),
      ),
  ];
  final date = DateTime.tryParse(doc['date'] as String? ?? '');
  final host = (doc['host'] as String?)?.trim();
  return Game(
    seasonId: seasonId,
    players: [for (final s in seats) (s['player'] as String).trim()],
    roles: roles,
    cityWon: _cityWon(doc['result']),
    firstKilled: firstKilled,
    bestMovePoints:
        firstKilled == 0 ? 0.0 : calculateSupportFivePoints(supportFive, roles),
    bestMove: const [],
    additionalPoints: [for (final s in seats) _num(s['additional'])],
    penaltyPoints: [for (final s in seats) _num(s['penalty'])],
    protocolAdditionalPoints: [for (final s in seats) _num(s['protocolAdditional'])],
    protocolPenaltyPoints: [for (final s in seats) _num(s['protocolPenalty'])],
    fouls: [for (final s in seats) (s['fouls'] as num?)?.toInt() ?? 0],
    protocol: protocol.isEmpty ? null : protocol,
    supportFive: supportFive.isEmpty ? null : supportFive,
    host: host == null || host.isEmpty ? null : host,
    date: date == null ? null : DateTime.utc(date.year, date.month, date.day),
  );
}

List<Game> gamesFromFirestoreSnapshot(int seasonId, Map<String, dynamic> snapshot) {
  final docs = ((snapshot['games'] as List?) ?? const []).cast<Map<String, dynamic>>().toList()
    ..sort((a, b) {
      final byDate = (a['date'] as String).compareTo(b['date'] as String);
      if (byDate != 0) return byDate;
      final byTable = (a['table'] as num).compareTo(b['table'] as num);
      if (byTable != 0) return byTable;
      return (a['gameNumber'] as num).compareTo(b['gameNumber'] as num);
    });
  return [for (final d in docs) gameFromFirestore(seasonId, d)];
}
```

- [ ] **Step 5: Dispatch in the loader**

In `lib/services/season_loader.dart` add the import `import 'package:family_mafia_app/services/firestore_games.dart';` and, below `parseSeasonGamesForTest`, add:
```dart
/// Parses one season's JSON string (sheet rows or a firestore snapshot).
@visibleForTesting
List<Game> parseSeasonJsonForTest(int seasonId, String json) =>
    _parseSeasonGames(seasonId, json);
```

In `lib/services/src/game_parsing.dart`, after `_getGamesDataSeason`, add:
```dart
/// A season's JSON is either sheet rows (a list) or a firestore snapshot (a map).
List<Game> _parseSeasonGames(int seasonId, String json) {
  final decoded = jsonDecode(json);
  if (decoded is Map<String, dynamic>) {
    return gamesFromFirestoreSnapshot(seasonId, decoded);
  }
  final rawData = (decoded as List)
      .cast<Map<String, dynamic>>()
      .map(GamesDataSeason.fromJson)
      .where((d) => _filterRawData(d, seasonId))
      .toList();
  return _getGamesDataSeason(seasonId, rawData);
}
```

In `lib/services/src/isolate_functions.dart`, in **both** `_computePartialData` and `_computeAllData`, replace:
```dart
    final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final rawData = raw
        .map((e) => GamesDataSeason.fromJson(e))
        .where((d) => _filterRawData(d, meta.id))
        .toList();

    final gamesData = _canonicalNames(
        _getGamesDataSeason(meta.id, rawData)
            .where((g) => g.isRatingGame())
            .toList(),
        resolver);
```
with:
```dart
    final gamesData = _canonicalNames(
        _parseSeasonGames(meta.id, json)
            .where((g) => g.isRatingGame())
            .toList(),
        resolver);
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/services/firestore_games_test.dart`
Expected: PASS.
Run: `flutter test`
Expected: whole suite PASS (sheet seasons unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/models lib/services test/services/firestore_games_test.dart
git commit -m "feat: parse Firestore game documents into Game (fouls, sheriff version)"
```

---

### Task 4: `firestore` season source + `FirestoreService` + wiring

**Files:**
- Modify: `lib/models/season_config.dart`
- Create: `lib/services/firestore_service.dart`
- Modify: `lib/services/season_data_service.dart`
- Modify: `lib/providers/app_providers.dart` (provider, 2 constructions at ~l.221 and ~l.358 area, l.280, l.357)
- Modify: `lib/site_export/load_container.dart`
- Test: `test/services/firestore_service_test.dart`, `test/models/season_config_firestore_test.dart`

**Interfaces:**
- Consumes: `decodeFirestoreFields`, `firestoreSnapshotFormat` (Task 3).
- Produces:
  - `class FirestoreSource extends SeasonSource { final String projectId; }`; JSON `{"source": "firestore", "projectId": "..."}`.
  - `class FirestoreService { FirestoreService({required Dio dio}); Future<String> fetchSeasonGames(FirestoreSource source, int seasonId); }` — returns the snapshot JSON string.
  - `final firestoreServiceProvider = Provider<FirestoreService?>(...)`.
  - `SeasonDataService({required SheetsService? sheetsService, FirestoreService? firestoreService, required SeasonCacheService cacheService})`.

- [ ] **Step 1: Failing tests**

`test/models/season_config_firestore_test.dart`:
```dart
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const json = {
    'id': 32, 'title': 'Season 32', 'gameLimit': 40, 'gamesMultiplier': 0.0,
    'smallLeagueMinGames': 15, 'source': 'firestore', 'projectId': 'family-mafia-club',
  };

  test('parses a firestore source', () {
    final c = SeasonConfig.fromJson(json);
    expect(c.source, isA<FirestoreSource>());
    expect((c.source as FirestoreSource).projectId, 'family-mafia-club');
  });

  test('round-trips through toJson', () {
    expect(SeasonConfig.fromJson(json).toJson(), json);
  });
}
```

`test/services/firestore_service_test.dart`:
```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:family_mafia_app/services/season_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions o) respond;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? s, Future<void>? c) async {
    last = options;
    return respond(options);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
    jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

class _MemCache implements SeasonCacheService {
  final data = <int, String>{};
  @override Future<String?> getCachedSeasonData(int id) async => data[id];
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async => data[id] = json;
  @override Future<void> invalidateSeasonCache(int id) async => data.remove(id);
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
}

const _src = FirestoreSource(projectId: 'p1');
const _config = SeasonConfig(id: 32, title: 'S32', gameLimit: 40,
    smallLeagueMinGames: 15, gamesMultiplier: 0, source: _src);

void main() {
  test('runQuery filters by season and decodes documents', () async {
    final adapter = _FakeAdapter((o) => _json([
          {'document': {
            'name': 'projects/p1/databases/(default)/documents/games/abc',
            'fields': {'season': {'integerValue': '32'}, 'host': {'stringValue': 'Серпень'}},
          }},
          {'readTime': '2026-12-03T20:00:00Z'}, // trailing element without a document
        ]));
    final service = FirestoreService(dio: Dio()..httpClientAdapter = adapter);

    final snapshot = jsonDecode(await service.fetchSeasonGames(_src, 32));

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.uri.toString(),
        'https://firestore.googleapis.com/v1/projects/p1/databases/(default)/documents:runQuery');
    final where = (adapter.last!.data as Map)['structuredQuery']['where']['fieldFilter'];
    expect(where['value'], {'integerValue': '32'});
    expect(snapshot, {
      'format': 'firestore',
      'games': [{'id': 'abc', 'season': 32, 'host': 'Серпень'}],
    });
  });

  test('data service caches a fetch and falls back to the cache on failure', () async {
    final cache = _MemCache();
    var fail = false;
    final dio = Dio()..httpClientAdapter = _FakeAdapter(
        (o) => fail ? _json({'error': 'x'}, 503) : _json([]));
    final service = SeasonDataService(
        sheetsService: null, firestoreService: FirestoreService(dio: dio), cacheService: cache);

    final first = await service.loadSeasonJson(_config);
    expect(jsonDecode(first!), {'format': 'firestore', 'games': []});

    fail = true;
    expect(await service.loadSeasonJson(_config), first);
  });

  test('without a service (site export) only the cache/snapshot is used', () async {
    final cache = _MemCache()..data[32] = '{"format":"firestore","games":[]}';
    final service = SeasonDataService(sheetsService: null, cacheService: cache);
    expect(await service.loadSeasonJson(_config), cache.data[32]);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/models/season_config_firestore_test.dart test/services/firestore_service_test.dart`
Expected: compile errors (`FirestoreSource`, `FirestoreService` undefined).

- [ ] **Step 3: Implement `FirestoreSource`** in `lib/models/season_config.dart`

In `fromJson` replace the `if/else` with:
```dart
    final SeasonSource source = switch (sourceType) {
      'remote' => RemoteSource(
          spreadsheetId: json['spreadsheetId'] as String,
          sheetName: json['sheetName'] as String,
          range: json['range'] as String,
        ),
      'firestore' => FirestoreSource(projectId: json['projectId'] as String),
      _ => BundledSource(jsonFile: json['jsonFile'] as String),
    };
```
In `toJson`'s switch add:
```dart
      case FirestoreSource(:final projectId):
        map['source'] = 'firestore';
        map['projectId'] = projectId;
```
Append the class:
```dart
/// Games recorded on the site's /host/ page (season 32+), read over the
/// Firestore REST API.
class FirestoreSource extends SeasonSource {
  final String projectId;
  const FirestoreSource({required this.projectId});
}
```

- [ ] **Step 4: Implement `lib/services/firestore_service.dart`**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_games.dart';

/// Reads a season's games from Firestore over REST. Games are publicly
/// readable (firestore.rules), so no key or sign-in is needed.
class FirestoreService {
  final Dio _dio;

  FirestoreService({required Dio dio}) : _dio = dio;

  /// Returns the season snapshot JSON: {"format": "firestore", "games": [...]}.
  Future<String> fetchSeasonGames(FirestoreSource source, int seasonId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '${source.projectId}/databases/(default)/documents:runQuery');
    final response = await _dio.postUri<List<dynamic>>(uri, data: {
      'structuredQuery': {
        'from': [{'collectionId': 'games'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'season'},
            'op': 'EQUAL',
            'value': {'integerValue': '$seasonId'},
          },
        },
      },
    });
    final games = <Map<String, dynamic>>[];
    for (final row in response.data ?? const []) {
      final document = (row as Map<String, dynamic>)['document'] as Map<String, dynamic>?;
      if (document == null) continue;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      games.add({
        'id': (document['name'] as String).split('/').last,
        ...decodeFirestoreFields(fields),
      });
    }
    return jsonEncode({'format': firestoreSnapshotFormat, 'games': games});
  }
}
```

- [ ] **Step 5: Branch in `SeasonDataService`**

Add field + constructor param (optional, defaults to null):
```dart
  final FirestoreService? _firestoreService;

  SeasonDataService({
    required SheetsService? sheetsService,
    FirestoreService? firestoreService,
    required SeasonCacheService cacheService,
  })  : _sheetsService = sheetsService,
        _firestoreService = firestoreService,
        _cacheService = cacheService;
```
Add these cases to the `switch` in `loadSeasonJson` (before the closing brace):
```dart
      case FirestoreSource() when _firestoreService == null:
        // Site export: read the build-time snapshot only.
        return _cacheService.getCachedSeasonData(config.id);

      case final FirestoreSource firestore:
        return _loadFirestoreSeason(config.id, firestore);
```
And the method:
```dart
  Future<String?> _loadFirestoreSeason(int seasonId, FirestoreSource source) async {
    try {
      final json = await _firestoreService!.fetchSeasonGames(source, seasonId);
      await _cacheService.cacheSeasonData(seasonId, json, 0);
      return json;
    } catch (e) {
      debugPrint('Season $seasonId: Firestore fetch failed ($e), trying cache');
      return _cacheService.getCachedSeasonData(seasonId);
    }
  }
```
Add `import 'package:family_mafia_app/services/firestore_service.dart';`.

- [ ] **Step 6: Wire providers and the export**

In `lib/providers/app_providers.dart`:
```dart
/// Null in the site export, which reads the prefetched snapshot instead.
final firestoreServiceProvider =
    Provider<FirestoreService?>((ref) => FirestoreService(dio: ref.read(dioProvider)));
```
Pass `firestoreService: ref.read(firestoreServiceProvider),` to **every** `SeasonDataService(` construction (grep `SeasonDataService(`).
Change line ~280:
```dart
  final remote = remainingConfigs.where((c) => c.source is! BundledSource).toList();
```
Change `refreshSeason` (~l.357): `if (config.source is! BundledSource) {`.

In `lib/site_export/load_container.dart` add to the overrides list:
```dart
    // The build reads firestore seasons from the prefetched snapshot too.
    firestoreServiceProvider.overrideWithValue(null),
```

- [ ] **Step 7: Run tests**

Run: `flutter test test/models/season_config_firestore_test.dart test/services/firestore_service_test.dart`
Expected: PASS.
Run: `flutter analyze && flutter test`
Expected: no issues, all PASS.

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat: firestore season source read over the Firestore REST API"
```

---

### Task 5: Prefetch firestore seasons into the build snapshot

**Files:**
- Modify: `tool/prefetch_seasons.dart`
- Test: `test/tool/prefetch_seasons_test.dart` (add a test)

**Interfaces:**
- Consumes: `FirestoreService.fetchSeasonGames`, `FirestoreSource` (Task 4).
- Produces: `assets/prefetched/season<id>.json` for firestore seasons (snapshot string), same file naming as remote seasons.

- [ ] **Step 1: Failing test** — add to `test/tool/prefetch_seasons_test.dart`:

```dart
  test('snapshots firestore seasons too (no API key needed for them)', () async {
    const config = '{"seasons": ['
        '{"id": 32, "title": "Season 32", "gameLimit": 40, "gamesMultiplier": 0.0, "source": "firestore", "projectId": "p1"}'
        ']}';
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((uri) {
        if (uri.host == 'config.test') return _body(config);
        if (uri.host == 'firestore.googleapis.com') {
          return _body(jsonEncode([
            {'document': {'name': 'x/games/g1', 'fields': {'season': {'integerValue': '32'}}}},
          ]));
        }
        return _body('{}', 404);
      });

    final ids = await prefetch.prefetchSeasons(
        dio: dio, apiKey: 'k', configUrl: _configUrl, outDir: out);

    expect(ids, [32]);
    final snap = jsonDecode(File('${out.path}/season32.json').readAsStringSync());
    expect(snap, {'format': 'firestore', 'games': [{'id': 'g1', 'season': 32}]});
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/tool/prefetch_seasons_test.dart`
Expected: FAIL — `ids` is `[]`.

- [ ] **Step 3: Implement** — in `prefetchSeasons`, replace the loop:

```dart
  final sheets = SheetsService(dio: dio, apiKey: apiKey);
  final firestore = FirestoreService(dio: dio);
  final fetched = <int, String>{};
  for (final season in seasons) {
    switch (season.source) {
      case final RemoteSource remote:
        fetched[season.id] = await sheets.fetchSeasonData(remote);
      case final FirestoreSource source:
        fetched[season.id] = await firestore.fetchSeasonGames(source, season.id);
      case BundledSource():
        break;
    }
  }
```
Add `import 'package:family_mafia_app/services/firestore_service.dart';`. Update the file's header comment: "Snapshots the remote config and every remote (Google Sheets) and firestore season…" and the doc comment "Returns the ids of the remote and firestore seasons written."

- [ ] **Step 4: Run tests**

Run: `flutter test test/tool/prefetch_seasons_test.dart`
Expected: PASS (old tests unchanged).

- [ ] **Step 5: Commit**

```bash
git add tool/prefetch_seasons.dart test/tool/prefetch_seasons_test.dart
git commit -m "feat(tool): prefetch firestore seasons into the site snapshot"
```

---

### Task 6: Firestore security rules + emulator tests + CI

Java is not installed locally; the emulator needs Java 21. Either install it (`winget install EclipseAdoptium.Temurin.21.JDK`, then reopen the shell) or rely on the CI job below — the job is the gate.

**Files:**
- Create: `firestore.rules`
- Create: `firebase/rules-test/package.json`, `firebase/rules-test/vitest.config.ts`, `firebase/rules-test/rules.test.ts`
- Create: `.github/workflows/firestore-rules.yml`

**Interfaces:**
- Consumes: `.firebaserc` / `firebase.json` (Task 1).
- Produces: deployed rules (owner runs deploy in Step 7). Write contract the site relies on (Task 8): game create/update must set `createdAt`/`updatedAt` = `request.time` (use `serverTimestamp()`), `createdBy` = uid, `createdByEmail` = email, `updatedBy` = uid; `meta/state` write sets only `updatedAt` = `request.time`.

- [ ] **Step 1: Write `firestore.rules`**

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function signedIn() { return request.auth != null && request.auth.token.email_verified == true; }
    function email() { return request.auth.token.email; }
    function isHost() { return signedIn() && exists(/databases/$(database)/documents/hosts/$(email())); }
    function isAdmin() { return isHost() && get(/databases/$(database)/documents/hosts/$(email())).data.admin == true; }

    function validGame(d) {
      return d.season is int
        && d.date is string && d.date.matches('^\\d{4}-\\d{2}-\\d{2}$')
        && d.table in [1, 2]
        && d.gameNumber is int && d.gameNumber >= 1
        && d.host is string && d.host.size() > 0
        && d.seats is list && d.seats.size() == 10
        && d.firstKilled is int && d.firstKilled >= 0 && d.firstKilled <= 10
        && d.supportFive is list && d.supportFive.size() <= 5
        && d.protocol is list && d.protocol.size() <= 9
        && d.result in ['city', 'mafia', 'unrated']
        && d.comments is list
        && d.updatedBy == request.auth.uid
        && d.updatedAt == request.time;
    }

    match /games/{id} {
      allow read: if true;
      allow create: if isHost() && validGame(request.resource.data)
        && request.resource.data.createdBy == request.auth.uid
        && request.resource.data.createdByEmail == email()
        && request.resource.data.createdAt == request.time;
      allow update: if isHost()
        && (resource.data.createdBy == request.auth.uid || isAdmin())
        && validGame(request.resource.data)
        && request.resource.data.createdBy == resource.data.createdBy
        && request.resource.data.createdByEmail == resource.data.createdByEmail
        && request.resource.data.createdAt == resource.data.createdAt;
      allow delete: if isAdmin();
    }

    match /hosts/{hostEmail} {
      allow read: if signedIn() && hostEmail == email();
      allow write: if false;
    }

    match /meta/state {
      allow read: if true;
      allow write: if isHost()
        && request.resource.data.keys().hasOnly(['updatedAt'])
        && request.resource.data.updatedAt == request.time;
    }
  }
}
```

- [ ] **Step 2: Test project files**

`firebase/rules-test/package.json`:
```json
{
  "name": "family-mafia-rules-test",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "firebase emulators:exec --config ../../firebase.json --only firestore --project demo-family-mafia \"vitest run\""
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^5.0.0",
    "firebase": "^12.0.0",
    "firebase-tools": "^14.0.0",
    "vitest": "^5.0.3"
  }
}
```

`firebase/rules-test/vitest.config.ts`:
```ts
import { defineConfig } from 'vitest/config';
export default defineConfig({ test: { testTimeout: 20000, hookTimeout: 30000, fileParallelism: false } });
```

- [ ] **Step 3: Write the rules tests** — `firebase/rules-test/rules.test.ts`

```ts
import fs from 'node:fs';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { assertFails, assertSucceeds, initializeTestEnvironment, type RulesTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, serverTimestamp, setDoc, updateDoc } from 'firebase/firestore';

let env: RulesTestEnvironment;
const HOST = { uid: 'u-host', email: 'host@x.com' };
const OTHER = { uid: 'u-other', email: 'other@x.com' };
const ADMIN = { uid: 'u-admin', email: 'admin@x.com' };
const STRANGER = { uid: 'u-stranger', email: 'stranger@x.com' };

const seat = (player: string, role: string) => ({ player, role, fouls: 0, additional: 0, penalty: 0, protocolAdditional: 0, protocolPenalty: 0 });
const ROLES = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];
const game = (who: { uid: string; email: string }, extra: Record<string, unknown> = {}) => ({
  season: 32, date: '2026-12-03', table: 1, gameNumber: 1, host: 'Серпень',
  seats: ROLES.map((r, i) => seat(`P${i + 1}`, r)),
  firstKilled: 6, supportFive: [1, -5], protocol: [], result: 'city', comments: [],
  createdBy: who.uid, createdByEmail: who.email, createdAt: serverTimestamp(),
  updatedBy: who.uid, updatedAt: serverTimestamp(), ...extra,
});
const as = (u: { uid: string; email: string }) => env.authenticatedContext(u.uid, { email: u.email, email_verified: true }).firestore();

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-family-mafia',
    firestore: { rules: fs.readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
  });
});
afterAll(() => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'hosts', HOST.email), { name: 'Host', admin: false });
    await setDoc(doc(db, 'hosts', OTHER.email), { name: 'Other', admin: false });
    await setDoc(doc(db, 'hosts', ADMIN.email), { name: 'Admin', admin: true });
  });
});

describe('games', () => {
  it('anyone can read', async () => {
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'games', 'g1')));
  });
  it('a host can create a valid game', async () => {
    await assertSucceeds(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST)));
  });
  it('a signed-in non-host cannot create', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'games', 'g1'), game(STRANGER)));
  });
  it('a guest cannot create', async () => {
    await assertFails(setDoc(doc(env.unauthenticatedContext().firestore(), 'games', 'g1'), game(HOST)));
  });
  it('rejects a game without a host', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { host: '' })));
  });
  it('rejects 9 seats', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { seats: game(HOST).seats.slice(0, 9) })));
  });
  it('rejects createdBy of someone else', async () => {
    await assertFails(setDoc(doc(as(HOST), 'games', 'g1'), game(HOST, { createdBy: OTHER.uid })));
  });

  describe('existing game by HOST', () => {
    beforeEach(async () => { await setDoc(doc(as(HOST), 'games', 'g1'), game(HOST)); });
    const edit = (u: typeof HOST) => updateDoc(doc(as(u), 'games', 'g1'), { result: 'mafia', updatedBy: u.uid, updatedAt: serverTimestamp() });

    it('the author can edit', async () => { await assertSucceeds(edit(HOST)); });
    it('another host cannot edit', async () => { await assertFails(edit(OTHER)); });
    it('an admin can edit', async () => { await assertSucceeds(edit(ADMIN)); });
    it('nobody can rewrite createdBy', async () => {
      await assertFails(updateDoc(doc(as(ADMIN), 'games', 'g1'), { createdBy: ADMIN.uid, updatedBy: ADMIN.uid, updatedAt: serverTimestamp() }));
    });
    it('the author cannot delete', async () => { await assertFails(deleteDoc(doc(as(HOST), 'games', 'g1'))); });
    it('an admin can delete', async () => { await assertSucceeds(deleteDoc(doc(as(ADMIN), 'games', 'g1'))); });
  });
});

describe('hosts', () => {
  it('a user reads only their own host doc', async () => {
    await assertSucceeds(getDoc(doc(as(HOST), 'hosts', HOST.email)));
    await assertFails(getDoc(doc(as(HOST), 'hosts', OTHER.email)));
  });
  it('nobody writes hosts from the client', async () => {
    await assertFails(setDoc(doc(as(ADMIN), 'hosts', STRANGER.email), { name: 'x', admin: true }));
  });
});

describe('meta/state', () => {
  it('a host bumps updatedAt', async () => {
    await assertSucceeds(setDoc(doc(as(HOST), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('a non-host cannot', async () => {
    await assertFails(setDoc(doc(as(STRANGER), 'meta', 'state'), { updatedAt: serverTimestamp() }));
  });
  it('no extra fields', async () => {
    await assertFails(setDoc(doc(as(HOST), 'meta', 'state'), { updatedAt: serverTimestamp(), x: 1 }));
  });
});
```

- [ ] **Step 4: CI workflow** — `.github/workflows/firestore-rules.yml`

```yaml
name: Firestore rules

on:
  push:
    paths: ['firestore.rules', 'firebase/rules-test/**', '.github/workflows/firestore-rules.yml']
  workflow_dispatch:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    defaults:
      run:
        working-directory: firebase/rules-test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { distribution: temurin, java-version: '21' }
      - uses: actions/setup-node@v4
        with: { node-version: '24' }
      - run: npm install
      - run: npm test
```

- [ ] **Step 5: Run the tests**

Local (if Java installed): `cd firebase/rules-test && npm install && npm test`
Expected: all tests PASS.
Otherwise: commit, push the branch, and check the "Firestore rules" run is green: `gh run list --workflow firestore-rules.yml --limit 1` → `completed success`.

- [ ] **Step 6: Commit** (add `firebase/rules-test/node_modules` to `.gitignore` first)

```bash
echo "firebase/rules-test/node_modules/" >> .gitignore
git add .gitignore firestore.rules firebase/rules-test .github/workflows/firestore-rules.yml
git commit -m "feat(firebase): security rules for games/hosts/meta with emulator tests"
```

- [ ] **Step 7: Owner deploys the rules**

Ask the owner to run in the session:
```
! npx firebase-tools login
! npx firebase-tools deploy --only firestore:rules,firestore:indexes
```
Expected: `Deploy complete!`. Verify in console → Firestore → Rules that the text matches `firestore.rules`.

---

### Task 7: Site hosting logic (types, points, validation, form mapping) — pure TS

**Files:**
- Create: `site/src/lib/hosting/types.ts`
- Create: `site/src/lib/hosting/points.ts`, `site/src/lib/hosting/points.test.ts`
- Create: `site/src/lib/hosting/validate.ts`, `site/src/lib/hosting/validate.test.ts`
- Create: `site/src/lib/hosting/form.ts`, `site/src/lib/hosting/form.test.ts`

**Interfaces:**
- Produces (used by Tasks 8–9):
  - types `Role`, `Result`, `Seat`, `ProtocolEntry`, `GameDoc`, `FormState`, `FormSeat`.
  - `supportFivePoints(supportFive: number[], roles: Role[]): number`
  - `winPoint(role: Role, result: Result): number | null`
  - `validate(f: FormState): { errors: string[]; warnings: string[]; fields: Set<string> }` — `fields` names invalid inputs for highlighting (`'host'`, `'result'`, `'seat-3-player'`, `'roles'`).
  - `formToDoc(f: FormState): Omit<GameDoc, 'createdBy'|'createdByEmail'|'createdAt'|'updatedBy'|'updatedAt'>`
  - `docToForm(d: GameDoc): FormState`, `emptyForm(season: number, date: string): FormState`
  - `nextGameNumber(games: Pick<GameDoc,'date'|'table'|'gameNumber'>[], date: string, table: 1|2): number`
  - `draftKey(gameId: string | null): string`

- [ ] **Step 1: `types.ts`**

```ts
export type Role = 'Мирний' | 'Мафія' | 'Дон' | 'Шериф';
export type Result = 'city' | 'mafia' | 'unrated';
export const ROLES: Role[] = ['Мирний', 'Мафія', 'Дон', 'Шериф'];

export interface Seat {
  player: string; role: Role; fouls: number;
  additional: number; penalty: number; protocolAdditional: number; protocolPenalty: number;
}
export interface ProtocolEntry { slot: number; version: number | null; color: { slot: number; black: boolean } | null }
export interface GameDoc {
  season: number; date: string; table: 1 | 2; gameNumber: number; host: string;
  seats: Seat[]; firstKilled: number; supportFive: number[]; protocol: ProtocolEntry[];
  result: Result; comments: { slot: number; text: string }[];
  createdBy: string; createdByEmail: string; createdAt: unknown; updatedBy: string; updatedAt: unknown;
}

/** What the inputs hold: numbers may be blank, penalties are typed positive. */
export interface FormSeat {
  player: string; role: Role; fouls: number;
  additional: string; penalty: string; protocolAdditional: string; protocolPenalty: string;
}
export interface FormState {
  season: number | null; date: string; table: 1 | 2; gameNumber: number | null; host: string;
  seats: FormSeat[]; firstKilled: number; supportFive: number[]; protocol: ProtocolEntry[];
  result: Result | null; comments: { slot: number; text: string }[];
}
```

- [ ] **Step 2: Failing tests** — `points.test.ts`

```ts
import { describe, expect, it } from 'vitest';
import { supportFivePoints, winPoint } from './points';
import type { Role } from './types';

const roles: Role[] = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];

describe('supportFivePoints (season-30 sheet formula)', () => {
  it('sheet game: 1,5,7 all red → -0.15', () => expect(supportFivePoints([1, 5, 7], roles)).toBeCloseTo(-0.15, 9));
  it('empty → -0.1', () => expect(supportFivePoints([], roles)).toBe(-0.1));
  it('three blacks found → 0.9', () => expect(supportFivePoints([-5, -7, -9], roles)).toBeCloseTo(0.9, 9));
  it('two blacks + two reds hit → 0.75', () => expect(supportFivePoints([-5, -9, 1, 2], roles)).toBeCloseTo(0.75, 9));
  it('five black guesses, three hit', () => expect(supportFivePoints([-5, -7, -9, -1, -2], roles)).toBeCloseTo(0.9 - 2.0, 9));
});

describe('winPoint', () => {
  it('city win: reds 1, blacks 0', () => {
    expect(winPoint('Шериф', 'city')).toBe(1);
    expect(winPoint('Дон', 'city')).toBe(0);
  });
  it('mafia win', () => expect(winPoint('Мафія', 'mafia')).toBe(1));
  it('unrated → null', () => expect(winPoint('Мирний', 'unrated')).toBeNull());
});
```

`validate.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { validate } from './validate';
import { emptyForm } from './form';
import type { FormState, Role } from './types';

const ROLES: Role[] = ['Мирний', 'Мирний', 'Мирний', 'Шериф', 'Мафія', 'Мирний', 'Дон', 'Мирний', 'Мафія', 'Мирний'];
const valid = (): FormState => {
  const f = emptyForm(32, '2026-12-03');
  f.host = 'Серпень'; f.result = 'city'; f.gameNumber = 1;
  f.seats.forEach((s, i) => { s.player = `P${i + 1}`; s.role = ROLES[i]; });
  return f;
};

describe('validate', () => {
  it('a full game has no errors', () => expect(validate(valid()).errors).toEqual([]));
  it('host is required and highlighted', () => {
    const f = valid(); f.host = '  ';
    const r = validate(f);
    expect(r.errors).toContain('Оберіть ведучого');
    expect(r.fields.has('host')).toBe(true);
  });
  it('result is required', () => {
    const f = valid(); f.result = null;
    expect(validate(f).fields.has('result')).toBe(true);
  });
  it('roles must be 6/2/1/1', () => {
    const f = valid(); f.seats[0].role = 'Мафія';
    expect(validate(f).errors).toContain('Ролі мають бути 6 мирних, 2 мафії, 1 дон, 1 шериф');
  });
  it('empty player is highlighted', () => {
    const f = valid(); f.seats[2].player = '';
    expect(validate(f).fields.has('seat-3-player')).toBe(true);
  });
  it('duplicates differing by case/space are caught', () => {
    const f = valid(); f.seats[0].player = 'Seezov'; f.seats[1].player = ' seezov ';
    const r = validate(f);
    expect(r.errors).toContain('Гравець «Seezov» записаний двічі');
    expect(r.fields.has('seat-2-player')).toBe(true);
  });
  it('season and game number are required', () => {
    const f = valid(); f.season = null; f.gameNumber = null;
    const r = validate(f);
    expect(r.fields.has('season')).toBe(true);
    expect(r.fields.has('gameNumber')).toBe(true);
  });
  it('protocol slot must be a seat and not repeated', () => {
    const f = valid(); f.protocol = [{ slot: 11, version: null, color: null }];
    expect(validate(f).errors).toContain('Протокол: невірний номер вбитого');
  });
  it('warns when Доп + ОП > 3.6 (does not block)', () => {
    const f = valid(); f.seats.forEach((s) => { s.additional = '0.4'; });
    const r = validate(f);
    expect(r.errors).toEqual([]);
    expect(r.warnings).toContain('Сума Доп + ОП більша за 3.6');
  });
  it('warns when more than 7 point cells are filled', () => {
    const f = valid(); f.firstKilled = 6; f.seats.slice(0, 7).forEach((s) => { s.additional = '0.1'; });
    expect(validate(f).warnings).toContain('Бали мають більше ніж 7 клітинок');
  });
});
```

`form.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { docToForm, draftKey, emptyForm, formToDoc, nextGameNumber } from './form';

describe('formToDoc', () => {
  it('stores penalties negative whatever sign was typed', () => {
    const f = emptyForm(32, '2026-12-03');
    f.seats[0].penalty = '0.5'; f.seats[1].penalty = '-0.5'; f.seats[2].protocolPenalty = '0.3';
    const d = formToDoc(f);
    expect(d.seats[0].penalty).toBe(-0.5);
    expect(d.seats[1].penalty).toBe(-0.5);
    expect(d.seats[2].protocolPenalty).toBe(-0.3);
  });
  it('blank numbers become 0, comma decimals parse', () => {
    const f = emptyForm(32, '2026-12-03'); f.seats[0].additional = '0,3';
    const d = formToDoc(f);
    expect(d.seats[0].additional).toBe(0.3);
    expect(d.seats[1].additional).toBe(0);
  });
  it('trims names and host; drops empty comments', () => {
    const f = emptyForm(32, '2026-12-03');
    f.host = ' Серпень '; f.seats[0].player = ' Німфа '; f.comments = [{ slot: 1, text: ' ' }, { slot: 2, text: 'ok' }];
    const d = formToDoc(f);
    expect(d.host).toBe('Серпень');
    expect(d.seats[0].player).toBe('Німфа');
    expect(d.comments).toEqual([{ slot: 2, text: 'ok' }]);
  });
  it('round-trips through docToForm (penalties shown positive)', () => {
    const f = emptyForm(32, '2026-12-03'); f.seats[0].penalty = '0.5'; f.result = 'city'; f.gameNumber = 2; f.host = 'X';
    const back = docToForm({ ...formToDoc(f), createdBy: 'u', createdByEmail: 'e', createdAt: null, updatedBy: 'u', updatedAt: null });
    expect(back.seats[0].penalty).toBe('0.5');
    expect(back.gameNumber).toBe(2);
  });
});

describe('nextGameNumber', () => {
  const games = [
    { date: '2026-12-03', table: 1 as const, gameNumber: 1 },
    { date: '2026-12-03', table: 1 as const, gameNumber: 2 },
    { date: '2026-12-03', table: 2 as const, gameNumber: 1 },
    { date: '2026-12-10', table: 1 as const, gameNumber: 5 },
  ];
  it('counts per table per date', () => {
    expect(nextGameNumber(games, '2026-12-03', 1)).toBe(3);
    expect(nextGameNumber(games, '2026-12-03', 2)).toBe(2);
    expect(nextGameNumber(games, '2026-12-17', 1)).toBe(1);
  });
});

describe('draftKey', () => {
  it('separates new games from each existing game', () => {
    expect(draftKey(null)).toBe('fm-host-draft:new');
    expect(draftKey('abc')).toBe('fm-host-draft:abc');
    expect(draftKey('abc')).not.toBe(draftKey('def'));
  });
});
```

- [ ] **Step 3: Run to verify failure**

Run: `cd site && npx vitest run src/lib/hosting`
Expected: FAIL — modules not found.

- [ ] **Step 4: Implement `points.ts`**

```ts
import type { Result, Role } from './types';

// Port of the season-30 sheet ОП formula (Опорна 5). Signed slots: + red, − black.
const M_SUCC = [0, 0.25, 0.55, 0.9, 0.9, 0.9];
const M_MISS = [0, -0.1, -0.25, -0.45, -1.45, -2.45];
const C_MISS = [0, -0.1, -0.2, -0.35, -0.55, -0.8];
const isBlack = (r: Role | undefined) => r === 'Мафія' || r === 'Дон';

export function supportFivePoints(supportFive: number[], roles: Role[]): number {
  const g = supportFive.filter((x) => x !== 0);
  if (g.length === 0) return -0.1;
  const black = (x: number) => isBlack(roles[Math.abs(x) - 1]);
  const nMaf = g.filter((x) => x < 0).length;
  const kMaf = g.filter((x) => x < 0 && black(x)).length;
  const nCit = g.filter((x) => x > 0).length;
  const kCit = g.filter((x) => x > 0 && !black(x)).length;
  return M_SUCC[kMaf] + (M_MISS[nMaf] - M_MISS[kMaf]) + 0.1 * kCit + (C_MISS[nCit] - C_MISS[kCit]);
}

export function winPoint(role: Role, result: Result): number | null {
  if (result === 'unrated') return null;
  return (result === 'mafia') === isBlack(role) ? 1 : 0;
}
```

- [ ] **Step 5: Implement `form.ts`**

```ts
import type { FormSeat, FormState, GameDoc } from './types';

type DocBody = Omit<GameDoc, 'createdBy' | 'createdByEmail' | 'createdAt' | 'updatedBy' | 'updatedAt'>;

const num = (s: string) => {
  const v = Number.parseFloat(s.replace(',', '.'));
  return Number.isFinite(v) ? v : 0;
};
const neg = (s: string) => -Math.abs(num(s)) || 0; // `|| 0` turns -0 into 0
const show = (v: number) => (v === 0 ? '' : String(Math.abs(v)));

const emptySeat = (): FormSeat => ({
  player: '', role: 'Мирний', fouls: 0, additional: '', penalty: '', protocolAdditional: '', protocolPenalty: '',
});

export const emptyForm = (season: number | null, date: string): FormState => ({
  season, date, table: 1, gameNumber: null, host: '',
  seats: Array.from({ length: 10 }, emptySeat),
  firstKilled: 0, supportFive: [], protocol: [], result: null, comments: [],
});

export function formToDoc(f: FormState): DocBody {
  return {
    season: f.season ?? 0, date: f.date, table: f.table, gameNumber: f.gameNumber ?? 0, host: f.host.trim(),
    seats: f.seats.map((s) => ({
      player: s.player.trim(), role: s.role, fouls: s.fouls,
      additional: num(s.additional), penalty: neg(s.penalty),
      protocolAdditional: num(s.protocolAdditional), protocolPenalty: neg(s.protocolPenalty),
    })),
    firstKilled: f.firstKilled,
    supportFive: f.supportFive.filter((x) => x !== 0),
    protocol: f.protocol,
    result: f.result ?? 'unrated',
    comments: f.comments.map((c) => ({ slot: c.slot, text: c.text.trim() })).filter((c) => c.text),
  };
}

export function docToForm(d: GameDoc): FormState {
  return {
    season: d.season, date: d.date, table: d.table, gameNumber: d.gameNumber, host: d.host,
    seats: d.seats.map((s) => ({
      player: s.player, role: s.role, fouls: s.fouls,
      additional: s.additional ? String(s.additional) : '', penalty: show(s.penalty),
      protocolAdditional: s.protocolAdditional ? String(s.protocolAdditional) : '', protocolPenalty: show(s.protocolPenalty),
    })),
    firstKilled: d.firstKilled, supportFive: [...d.supportFive], protocol: d.protocol.map((p) => ({ ...p })),
    result: d.result, comments: d.comments.map((c) => ({ ...c })),
  };
}

export const nextGameNumber = (games: Pick<GameDoc, 'date' | 'table' | 'gameNumber'>[], date: string, table: 1 | 2) =>
  1 + Math.max(0, ...games.filter((g) => g.date === date && g.table === table).map((g) => g.gameNumber));

export const draftKey = (gameId: string | null) => `fm-host-draft:${gameId ?? 'new'}`;

export { num as parseNumber };
```

- [ ] **Step 6: Implement `validate.ts`**

```ts
import { parseNumber } from './form';
import { supportFivePoints } from './points';
import type { FormState } from './types';

export function validate(f: FormState) {
  const errors: string[] = [];
  const warnings: string[] = [];
  const fields = new Set<string>();
  const fail = (msg: string, ...names: string[]) => { if (!errors.includes(msg)) errors.push(msg); names.forEach((n) => fields.add(n)); };

  if (f.season === null || !Number.isInteger(f.season)) fail('Вкажіть сезон', 'season');
  if (!/^\d{4}-\d{2}-\d{2}$/.test(f.date)) fail('Вкажіть дату', 'date');
  if (f.gameNumber === null || f.gameNumber < 1) fail('Вкажіть номер гри', 'gameNumber');
  if (!f.host.trim()) fail('Оберіть ведучого', 'host');
  if (f.result === null) fail('Оберіть переможця', 'result');

  const seen = new Map<string, number>();
  f.seats.forEach((s, i) => {
    const name = s.player.trim();
    if (!name) { fail('Заповніть усіх 10 гравців', `seat-${i + 1}-player`); return; }
    const key = name.toLowerCase();
    if (seen.has(key)) fail(`Гравець «${f.seats[seen.get(key)!].player.trim()}» записаний двічі`, `seat-${i + 1}-player`);
    else seen.set(key, i);
  });

  const count = (r: string) => f.seats.filter((s) => s.role === r).length;
  if (count('Мирний') !== 6 || count('Мафія') !== 2 || count('Дон') !== 1 || count('Шериф') !== 1) {
    fail('Ролі мають бути 6 мирних, 2 мафії, 1 дон, 1 шериф', 'roles');
  }

  const valid = (n: number | undefined) => n !== undefined && Number.isInteger(n) && n >= 1 && n <= 10;
  const slots = f.protocol.map((p) => p.slot);
  if (f.protocol.some((p) => !valid(p.slot) || (p.version !== null && !valid(p.version)) || (p.color && !valid(p.color.slot)))
      || new Set(slots).size !== slots.length) {
    fail('Протокол: невірний номер вбитого', 'protocol');
  }
  if (f.supportFive.some((x) => !valid(Math.abs(x))) || f.supportFive.length > 5) fail('Опорна 5: невірні номери', 'supportFive');

  // Sheet checks (warnings only): SUM(ОП + Доп) > 3.6, COUNT(ОП, Доп cells) > 7.
  const op = f.firstKilled ? supportFivePoints(f.supportFive, f.seats.map((s) => s.role)) : 0;
  const addSum = f.seats.reduce((a, s) => a + parseNumber(s.additional), 0);
  if (op + addSum > 3.6 + 1e-9) warnings.push('Сума Доп + ОП більша за 3.6');
  const cells = f.seats.filter((s) => parseNumber(s.additional) !== 0).length + (f.firstKilled ? 1 : 0);
  if (cells > 7) warnings.push('Бали мають більше ніж 7 клітинок');

  return { errors, warnings, fields };
}
```

- [ ] **Step 7: Run tests**

Run: `cd site && npx vitest run src/lib/hosting`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add site/src/lib/hosting
git commit -m "feat(site): hosting form logic — ОП, validation, form ⇄ document"
```

---

### Task 8: Firebase client store (auth, list, transactional save)

**Files:**
- Modify: `site/package.json` (dependency)
- Create: `site/src/lib/hosting/store.ts`

**Interfaces:**
- Consumes: `firebaseConfig` (Task 1), `GameDoc`, `formToDoc` output (Task 7), rules write contract (Task 6).
- Produces:
  - `type HostUser = { uid: string; email: string; name: string; admin: boolean }`
  - `onUser(cb: (u: HostUser | null | 'not-host') => void): void`
  - `signIn(): Promise<void>`, `signOutUser(): Promise<void>`
  - `listSeasonGames(season: number): Promise<(GameDoc & { id: string })[]>`
  - `saveGame(body: ReturnType<typeof formToDoc>, existing: { id: string; updatedAtMillis: number } | null, user: HostUser): Promise<string>` — returns the game id; throws `StaleGameError` when the stored `updatedAt` differs from `updatedAtMillis`.
  - `class StaleGameError extends Error`
  - `explainError(e: unknown): string` — Ukrainian message for UI.

- [ ] **Step 1: Install**

Run: `cd site && npm install firebase@^12`
Expected: `package.json` dependencies gains `"firebase": "^12…"`.

- [ ] **Step 2: Implement `store.ts`**

```ts
// Firebase client for the /host/ page. Thin on purpose: all game logic lives in
// form.ts / validate.ts (unit-tested); access control lives in firestore.rules.
import { initializeApp } from 'firebase/app';
import { GoogleAuthProvider, getAuth, onAuthStateChanged, signInWithPopup, signInWithRedirect, signOut } from 'firebase/auth';
import {
  collection, doc, getDoc, getDocs, getFirestore, query, runTransaction, serverTimestamp, where, type Timestamp,
} from 'firebase/firestore';
import { firebaseConfig } from './firebase-config';
import type { GameDoc } from './types';
import type { formToDoc } from './form';

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

export type HostUser = { uid: string; email: string; name: string; admin: boolean };
export class StaleGameError extends Error {}

export function onUser(cb: (u: HostUser | null | 'not-host') => void) {
  onAuthStateChanged(auth, async (u) => {
    if (!u?.email) return cb(null);
    const host = await getDoc(doc(db, 'hosts', u.email)).catch(() => null);
    if (!host?.exists()) return cb('not-host');
    cb({ uid: u.uid, email: u.email, name: String(host.data().name ?? u.email), admin: host.data().admin === true });
  });
}

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

export async function listSeasonGames(season: number) {
  const snap = await getDocs(query(collection(db, 'games'), where('season', '==', season)));
  return snap.docs.map((d) => ({ id: d.id, ...(d.data() as GameDoc) }));
}

export const millis = (t: unknown) => (t as Timestamp | null)?.toMillis?.() ?? 0;

export async function saveGame(
  body: ReturnType<typeof formToDoc>,
  existing: { id: string; updatedAtMillis: number } | null,
  user: HostUser,
): Promise<string> {
  const ref = existing ? doc(db, 'games', existing.id) : doc(collection(db, 'games'));
  await runTransaction(db, async (tx) => {
    const stamp = { updatedBy: user.uid, updatedAt: serverTimestamp() };
    if (existing) {
      const cur = await tx.get(ref);
      if (!cur.exists() || millis(cur.data().updatedAt) !== existing.updatedAtMillis) throw new StaleGameError();
      const { createdBy, createdByEmail, createdAt } = cur.data();
      tx.set(ref, { ...body, createdBy, createdByEmail, createdAt, ...stamp });
    } else {
      tx.set(ref, { ...body, createdBy: user.uid, createdByEmail: user.email, createdAt: serverTimestamp(), ...stamp });
    }
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
  return ref.id;
}

export function explainError(e: unknown): string {
  if (e instanceof StaleGameError) return 'Гру змінили з іншого пристрою — перезавантаж сторінку.';
  const code = (e as { code?: string }).code ?? '';
  if (code === 'permission-denied') return 'Немає прав зберегти цю гру (не ведучий або чужа гра).';
  if (code === 'unavailable' || code === 'deadline-exceeded' || !navigator.onLine) return 'Немає зʼєднання. Чернетка збережена — спробуй ще.';
  if (code === 'auth/popup-closed-by-user') return 'Вхід скасовано.';
  return `Помилка: ${code || (e as Error).message}`;
}
```

- [ ] **Step 3: Type-check**

Run: `cd site && npx astro check`
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add site/package.json site/package-lock.json site/src/lib/hosting/store.ts
git commit -m "feat(site): Firebase client for hosting — Google sign-in, list, transactional save"
```

---

### Task 9: `/host/` page (UI, draft, nav, key allowlist)

**Files:**
- Create: `site/src/pages/host/index.astro`
- Create: `site/src/scripts/host.ts`
- Modify: `site/src/layouts/Base.astro` (Props `active` union + `nav` entry)
- Modify: `site/scripts/check-dist.mjs`

**Interfaces:**
- Consumes: everything from Tasks 7–8; `assets/raw/players.json`, `remote_config.json` at build time.
- Produces: page at `/FamilyMafiaApp/host/`.

- [ ] **Step 1: Nav + key allowlist**

`Base.astro`: add `'host'` to the `active` union and append to `nav`:
```ts
  { key: 'host', label: 'Провести гру', url: href('host/') },
```

`check-dist.mjs`: add after the `errors` declaration (Node cannot import `.ts`, so read the key textually):
```js
// The Firebase web key is public by design (firestore.rules guard the data);
// it is the only key allowed in the build.
const fbConfig = fs.readFileSync(path.resolve('src/lib/hosting/firebase-config.ts'), 'utf8');
const allowedKey = fbConfig.match(/apiKey:\s*'([^']+)'/)?.[1];
```
and in the loop replace the `if (text.includes('AIza'))` line with:
```js
  const keys = text.match(/AIza[0-9A-Za-z_-]{35}/g) ?? [];
  if (keys.some((k) => k !== allowedKey)) errors.push(`API key pattern in ${path.relative(dist, file)}`);
```

- [ ] **Step 2: Page — `site/src/pages/host/index.astro`**

```astro
---
import fs from 'node:fs';
import path from 'node:path';
import Base from '../../layouts/Base.astro';

// Player names for autocomplete: the app's roster with nicknames, junk filtered.
const root = path.resolve(process.cwd(), '..');
const roster = JSON.parse(fs.readFileSync(path.join(root, 'assets/raw/players.json'), 'utf8')) as { displayName: string; nicknames?: string[] }[];
const names = [...new Set(roster.flatMap((p) => [p.displayName, ...(p.nicknames ?? [])])
  .map((n) => n.trim()).filter((n) => n.length >= 2 && !/^[\d/\\.]+$/.test(n)))].sort((a, b) => a.localeCompare(b, 'uk'));
// Default season: the latest firestore season in the live config, else none.
const config = JSON.parse(fs.readFileSync(path.join(root, 'remote_config.json'), 'utf8')) as { seasons: { id: number; source: string }[] };
const defaultSeason = config.seasons.filter((s) => s.source === 'firestore').map((s) => s.id).sort((a, b) => b - a)[0] ?? null;
const data = JSON.stringify({ names, defaultSeason }).replace(/</g, '\\u003c');
---
<Base title="Провести гру" description="Запис ігор клубу для ведучих." active="host">
  <div class="pagehead"><h1 class="display">Провести гру</h1><span class="label" id="who"></span></div>

  <section id="signed-out" class="panel" hidden>
    <p>Записувати ігри можуть лише ведучі клубу.</p>
    <button class="btn primary" id="sign-in" type="button">Увійти через Google</button>
  </section>
  <section id="not-host" class="panel" hidden>
    <p>Немає прав ведучого — звернись до адміна.</p>
    <button class="btn" id="sign-out-2" type="button">Вийти</button>
  </section>

  <section id="list-view" hidden>
    <div class="toolbar">
      <button class="btn primary" id="new-game" type="button">Нова гра</button>
      <label>Сезон <input id="l-season" type="number" min="1" inputmode="numeric" /></label>
      <button class="btn" id="sign-out" type="button">Вийти</button>
    </div>
    <div id="games" class="list" aria-live="polite"></div>
  </section>

  <form id="game-form" class="host-form" hidden novalidate>
    <fieldset class="panel head">
      <label>Сезон <input id="f-season" type="number" min="1" inputmode="numeric" /></label>
      <label>Дата <input id="f-date" type="date" /></label>
      <label>Стіл <select id="f-table"><option value="1">1</option><option value="2">2</option></select></label>
      <label>Гра № <input id="f-number" type="number" min="1" inputmode="numeric" /></label>
      <label class="wide">Ведучий <input id="f-host" list="names" autocomplete="off" placeholder="Оберіть ведучого" /></label>
    </fieldset>
    <div id="seats" class="seats"></div>
    <fieldset class="panel">
      <legend>ПУ і Опорна 5</legend>
      <label>ПУ <input id="f-first" type="number" min="0" max="10" inputmode="numeric" /></label>
      <div id="support" class="support"></div>
      <span class="label" id="op-value"></span>
    </fieldset>
    <fieldset class="panel">
      <legend>Протокол</legend>
      <div id="protocol"></div>
      <button class="btn" id="add-protocol" type="button">+ Вбитий гравець</button>
    </fieldset>
    <fieldset class="panel" id="f-result">
      <legend>Перемога</legend>
      <label><input type="radio" name="result" value="city" /> Місто</label>
      <label><input type="radio" name="result" value="mafia" /> Мафія</label>
      <label><input type="radio" name="result" value="unrated" /> Не рейтинг</label>
    </fieldset>
    <fieldset class="panel">
      <legend>Коментарі до дод. балів</legend>
      <div id="comments"></div>
      <button class="btn" id="add-comment" type="button">+ Коментар</button>
    </fieldset>
    <div id="messages" aria-live="polite"></div>
    <div class="toolbar sticky">
      <button class="btn" id="cancel" type="button">До списку</button>
      <button class="btn primary" id="save" type="submit">Зберегти</button>
    </div>
  </form>

  <datalist id="names">{names.map((n) => <option value={n} />)}</datalist>
  <script type="application/json" id="host-data" set:html={data} />
</Base>

<script>
  import '../../scripts/host';
</script>

<style is:global>
  .host-form { display: grid; gap: 12px; }
  .host-form fieldset { display: grid; gap: 8px; border: 1px solid var(--border); }
  .host-form .head { grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); }
  .host-form .wide { grid-column: 1 / -1; }
  .host-form label { display: grid; gap: 4px; font-size: 13px; }
  .host-form input, .host-form select { min-height: 40px; font-size: 16px; }
  .seats { display: grid; gap: 8px; }
  .seat { display: grid; gap: 6px; grid-template-columns: 2rem 1fr; padding: 10px; background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius); }
  .seat .nums { grid-column: 2; display: grid; gap: 6px; grid-template-columns: repeat(auto-fit, minmax(70px, 1fr)); }
  .seat .roles button[aria-pressed="true"] { outline: 2px solid var(--fg); }
  .invalid, .invalid input { outline: 2px solid var(--bad, #e53935) !important; }
  .msg-error { color: var(--bad, #e53935); } .msg-warn { color: var(--mid); }
  .toolbar.sticky { position: sticky; bottom: 0; background: var(--bg); padding: 8px 0; }
</style>
```

- [ ] **Step 3: Script — `site/src/scripts/host.ts`**

```ts
// The /host/ page: sign-in, a host's games, and the protocol form.
import { docToForm, draftKey, emptyForm, formToDoc, nextGameNumber } from '../lib/hosting/form';
import { supportFivePoints } from '../lib/hosting/points';
import { explainError, listSeasonGames, millis, onUser, saveGame, signIn, signOutUser, type HostUser } from '../lib/hosting/store';
import { ROLES, type FormState, type GameDoc } from '../lib/hosting/types';
import { validate } from '../lib/hosting/validate';

const page = JSON.parse(document.getElementById('host-data')!.textContent!) as { names: string[]; defaultSeason: number | null };
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const store = {
  get(k: string) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k: string, v: string | null) { try { if (v === null) localStorage.removeItem(k); else localStorage.setItem(k, v); } catch { /* private mode */ } },
};
const today = () => new Date().toLocaleDateString('sv-SE'); // yyyy-mm-dd, local
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);

let user: HostUser | null = null;
let games: (GameDoc & { id: string })[] = [];
let form: FormState = emptyForm(page.defaultSeason, today());
let editing: { id: string; updatedAtMillis: number } | null = null;

function show(view: 'signed-out' | 'not-host' | 'list-view' | 'game-form') {
  for (const id of ['signed-out', 'not-host', 'list-view', 'game-form']) $(id).hidden = id !== view;
}

// ── Draft (per game id) ───────────────────────────────────────────────────
const saveDraft = () => store.set(draftKey(editing?.id ?? null), JSON.stringify(form));
function loadDraft(id: string | null): FormState | null {
  try { const s = store.get(draftKey(id)); return s ? (JSON.parse(s) as FormState) : null; } catch { return null; }
}

// ── List ──────────────────────────────────────────────────────────────────
async function refreshList() {
  const season = form.season ?? page.defaultSeason;
  games = season ? await listSeasonGames(season) : [];
  const visible = games
    .filter((g) => user!.admin || g.createdBy === user!.uid || g.date === today())
    .sort((a, b) => b.date.localeCompare(a.date) || a.table - b.table || b.gameNumber - a.gameNumber);
  const label = { city: 'Місто', mafia: 'Мафія', unrated: 'Не рейтинг' } as const;
  $('games').innerHTML = visible.length
    ? visible.map((g) => `<button class="panel game-row" data-id="${g.id}" type="button">
        <b>${g.date}</b> · стіл ${g.table} · гра ${g.gameNumber} · ${esc(g.host)} · ${label[g.result]}</button>`).join('')
    : '<p class="label">Ігор ще немає.</p>';
}

// ── Form rendering ────────────────────────────────────────────────────────
function renderSeats() {
  $('seats').innerHTML = form.seats.map((s, i) => `
    <div class="seat" data-i="${i}">
      <b>${i + 1}</b>
      <input data-k="player" list="names" autocomplete="off" placeholder="Гравець" value="${esc(s.player)}" aria-label="Гравець ${i + 1}" />
      <div class="roles nums">${ROLES.map((r) => `<button type="button" data-role="${r}" aria-pressed="${s.role === r}">${r}</button>`).join('')}</div>
      <div class="nums">
        <label>Фоли <input data-k="fouls" type="number" min="0" max="4" inputmode="numeric" value="${s.fouls}" /></label>
        <label>Доп <input data-k="additional" inputmode="decimal" value="${esc(s.additional)}" /></label>
        <label>Штраф <input data-k="penalty" inputmode="decimal" value="${esc(s.penalty)}" /></label>
        <label>ПрДод <input data-k="protocolAdditional" inputmode="decimal" value="${esc(s.protocolAdditional)}" /></label>
        <label>ПрШтраф <input data-k="protocolPenalty" inputmode="decimal" value="${esc(s.protocolPenalty)}" /></label>
      </div>
      <span class="label new-player" ${!s.player.trim() || page.names.includes(s.player.trim()) ? 'hidden' : ''}>новий гравець</span>
    </div>`).join('');
}

function renderSupport() {
  const rows = [...form.supportFive, ...(form.supportFive.length < 5 ? [0] : [])];
  $('support').innerHTML = rows.map((g, j) => `
    <div class="row" data-j="${j}">
      <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${g ? Math.abs(g) : ''}" aria-label="Опорна ${j + 1}" />
      <select data-k="color"><option value="red" ${g >= 0 ? 'selected' : ''}>червоний</option><option value="black" ${g < 0 ? 'selected' : ''}>чорний</option></select>
    </div>`).join('');
  renderOp();
}

function renderOp() {
  $('op-value').textContent = form.firstKilled
    ? `ОП гравця ${form.firstKilled}: ${supportFivePoints(form.supportFive, form.seats.map((s) => s.role)).toFixed(2)}`
    : '';
}

function renderProtocol() {
  $('protocol').innerHTML = form.protocol.map((p, j) => `
    <div class="row" data-j="${j}">
      <label>Вбитий <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${p.slot || ''}" /></label>
      <label>Версія (шериф) <input data-k="version" type="number" min="1" max="10" inputmode="numeric" value="${p.version ?? ''}" /></label>
      <label>Колір: гравець <input data-k="cslot" type="number" min="1" max="10" inputmode="numeric" value="${p.color?.slot ?? ''}" /></label>
      <select data-k="cblack"><option value="red" ${p.color?.black ? '' : 'selected'}>червоний</option><option value="black" ${p.color?.black ? 'selected' : ''}>чорний</option></select>
      <button class="btn" type="button" data-remove>✕</button>
    </div>`).join('');
}

function renderComments() {
  $('comments').innerHTML = form.comments.map((c, j) => `
    <div class="row" data-j="${j}">
      <input data-k="slot" type="number" min="1" max="10" inputmode="numeric" value="${c.slot || ''}" aria-label="Номер" />
      <input data-k="text" value="${esc(c.text)}" aria-label="Коментар" />
      <button class="btn" type="button" data-remove>✕</button>
    </div>`).join('');
}

function renderAll() {
  $<HTMLInputElement>('f-season').value = form.season?.toString() ?? '';
  $<HTMLInputElement>('f-date').value = form.date;
  $<HTMLSelectElement>('f-table').value = String(form.table);
  $<HTMLInputElement>('f-number').value = form.gameNumber?.toString() ?? '';
  $<HTMLInputElement>('f-host').value = form.host;
  $<HTMLInputElement>('f-first').value = form.firstKilled ? String(form.firstKilled) : '';
  document.querySelectorAll<HTMLInputElement>('input[name=result]').forEach((r) => { r.checked = r.value === form.result; });
  renderSeats(); renderSupport(); renderProtocol(); renderComments();
  showMessages(false);
}

function showMessages(highlight: boolean) {
  const r = validate(form);
  document.querySelectorAll('.invalid').forEach((el) => el.classList.remove('invalid'));
  if (highlight) {
    const map: Record<string, string> = { host: 'f-host', result: 'f-result', season: 'f-season', gameNumber: 'f-number', date: 'f-date', protocol: 'protocol', supportFive: 'support', roles: 'seats' };
    for (const f of r.fields) {
      const m = /^seat-(\d+)-player$/.exec(f);
      const el = m ? document.querySelector(`.seat[data-i="${+m[1] - 1}"] [data-k=player]`) : document.getElementById(map[f]);
      el?.classList.add('invalid');
    }
  }
  $('messages').innerHTML = [
    ...(highlight ? r.errors.map((e) => `<p class="msg-error">${esc(e)}</p>`) : []),
    ...r.warnings.map((w) => `<p class="msg-warn">⚠ ${esc(w)}</p>`),
  ].join('');
  return r;
}

const changed = () => { saveDraft(); renderOp(); showMessages(false); };

// ── Form events ───────────────────────────────────────────────────────────
$('game-form').addEventListener('input', (e) => {
  const t = e.target as HTMLInputElement;
  const seat = t.closest<HTMLElement>('.seat');
  const row = t.closest<HTMLElement>('.row');
  const k = t.dataset.k;
  if (t.id === 'f-season') form.season = t.value ? Number(t.value) : null;
  else if (t.id === 'f-date') form.date = t.value;
  else if (t.id === 'f-number') form.gameNumber = t.value ? Number(t.value) : null;
  else if (t.id === 'f-host') form.host = t.value;
  else if (t.id === 'f-first') {
    form.firstKilled = Number(t.value) || 0;
    if (form.firstKilled && !form.protocol.length) { form.protocol = [{ slot: form.firstKilled, version: null, color: null }]; renderProtocol(); }
  } else if (t.name === 'result') form.result = t.value as FormState['result'];
  else if (seat && k) {
    const s = form.seats[+seat.dataset.i!];
    if (k === 'fouls') s.fouls = Math.max(0, Math.min(4, Number(t.value) || 0));
    else (s as unknown as Record<string, string>)[k] = t.value;
    if (k === 'player') seat.querySelector<HTMLElement>('.new-player')!.hidden = !t.value.trim() || page.names.includes(t.value.trim());
  } else if (row && row.parentElement?.id === 'support') {
    const inputs = [...$('support').querySelectorAll<HTMLElement>('.row')].map((r) => {
      const n = Number(r.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
      return r.querySelector<HTMLSelectElement>('[data-k=color]')!.value === 'black' ? -n : n;
    });
    form.supportFive = inputs.filter((x) => x !== 0);
    if (k === 'slot' && t.value && form.supportFive.length < 5 && row.dataset.j === String(inputs.length - 1)) { renderSupport(); }
  } else if (row && row.parentElement?.id === 'protocol') {
    const p = form.protocol[+row.dataset.j!];
    const v = (key: string) => Number(row.querySelector<HTMLInputElement>(`[data-k=${key}]`)!.value) || 0;
    p.slot = v('slot');
    p.version = v('version') || null;
    p.color = v('cslot') ? { slot: v('cslot'), black: row.querySelector<HTMLSelectElement>('[data-k=cblack]')!.value === 'black' } : null;
  } else if (row && row.parentElement?.id === 'comments') {
    const c = form.comments[+row.dataset.j!];
    c.slot = Number(row.querySelector<HTMLInputElement>('[data-k=slot]')!.value) || 0;
    c.text = row.querySelector<HTMLInputElement>('[data-k=text]')!.value;
  }
  changed();
});

$('game-form').addEventListener('change', (e) => {
  const t = e.target as HTMLSelectElement;
  if (t.id === 'f-table') {
    form.table = Number(t.value) as 1 | 2;
    if (!editing) { form.gameNumber = nextGameNumber(games, form.date, form.table); $<HTMLInputElement>('f-number').value = String(form.gameNumber); }
    changed();
  } else if (t.tagName === 'SELECT') {
    t.dispatchEvent(new Event('input', { bubbles: true }));
  }
});

$('game-form').addEventListener('click', (e) => {
  const t = e.target as HTMLElement;
  const role = t.dataset.role;
  if (role) {
    form.seats[+t.closest<HTMLElement>('.seat')!.dataset.i!].role = role as FormState['seats'][number]['role'];
    t.parentElement!.querySelectorAll('button').forEach((b) => b.setAttribute('aria-pressed', String(b === t)));
    changed();
  }
  if (t.hasAttribute('data-remove')) {
    const row = t.closest<HTMLElement>('.row')!;
    const list = row.parentElement!.id === 'protocol' ? form.protocol : form.comments;
    list.splice(+row.dataset.j!, 1);
    row.parentElement!.id === 'protocol' ? renderProtocol() : renderComments();
    changed();
  }
});

$('add-protocol').addEventListener('click', () => { form.protocol.push({ slot: 0, version: null, color: null }); renderProtocol(); changed(); });
$('add-comment').addEventListener('click', () => { form.comments.push({ slot: 0, text: '' }); renderComments(); changed(); });
$('cancel').addEventListener('click', async () => { show('list-view'); await refreshList(); });

$('game-form').addEventListener('submit', async (e) => {
  e.preventDefault();
  const r = showMessages(true);
  if (r.errors.length || !user) return;
  const btn = $<HTMLButtonElement>('save');
  btn.disabled = true;
  try {
    const id = await saveGame(formToDoc(form), editing, user);
    store.set(draftKey(editing?.id ?? null), null);
    $('messages').innerHTML = '<p>Гру збережено. У статистиці зʼявиться протягом години.</p>';
    editing = { id, updatedAtMillis: -1 }; // force a reload before any further edit
    setTimeout(async () => { show('list-view'); await refreshList(); }, 1200);
  } catch (err) {
    $('messages').innerHTML = `<p class="msg-error">${esc(explainError(err))}</p>`;
  } finally {
    btn.disabled = false;
  }
});

// ── Opening a game ────────────────────────────────────────────────────────
function openNew() {
  editing = null;
  form = loadDraft(null) ?? emptyForm(page.defaultSeason, today());
  if (form.gameNumber === null) form.gameNumber = nextGameNumber(games, form.date, form.table);
  show('game-form'); renderAll();
}

function openExisting(g: GameDoc & { id: string }) {
  editing = { id: g.id, updatedAtMillis: millis(g.updatedAt) };
  form = loadDraft(g.id) ?? docToForm(g);
  show('game-form'); renderAll();
}

$('new-game').addEventListener('click', openNew);
$('l-season').addEventListener('change', async (e) => {
  const v = Number((e.target as HTMLInputElement).value);
  form.season = v || page.defaultSeason;
  await refreshList();
});
$('games').addEventListener('click', (e) => {
  const id = (e.target as HTMLElement).closest<HTMLElement>('[data-id]')?.dataset.id;
  const g = games.find((x) => x.id === id);
  if (g) openExisting(g);
});

// ── Auth ──────────────────────────────────────────────────────────────────
$('sign-in').addEventListener('click', () => signIn().catch((e) => { $('who').textContent = explainError(e); }));
for (const id of ['sign-out', 'sign-out-2']) $(id).addEventListener('click', () => signOutUser());

onUser(async (u) => {
  if (u === null) { user = null; $('who').textContent = ''; return show('signed-out'); }
  if (u === 'not-host') { user = null; return show('not-host'); }
  user = u;
  $('who').textContent = `${u.name}${u.admin ? ' · адмін' : ''}`;
  show('list-view');
  $<HTMLInputElement>('l-season').value = (form.season ?? page.defaultSeason)?.toString() ?? '';
  try { await refreshList(); } catch (e) { $('games').innerHTML = `<p class="msg-error">${esc(explainError(e))}</p>`; }
});
```

- [ ] **Step 4: Build and check**

Run: `cd site && npm run check && npm test && npm run build`
Expected: `astro check` 0 errors; vitest PASS; build ends with `check-dist: … all links resolve` (the Firebase key is allowed).

- [ ] **Step 5: Manual check in the dev server** (owner signed in as admin from Task 1)

Run: `cd site && npm run dev`, open `http://localhost:4321/FamilyMafiaApp/host/`. Add `localhost` is already an authorized domain by default in Firebase Auth.
Verify, at phone width (DevTools 390 px):
1. Signed out → «Увійти через Google»; after sign-in → list, name shown with «адмін».
2. «Нова гра»: set season `999`, fill 10 players, roles 6/2/1/1, ПУ 6, Опорна 5 = 1, 5, 7 (all red) → «ОП гравця 6: -0.15».
3. Leave host empty → «Зберегти» highlights «Ведучий» and shows «Оберіть ведучого»; nothing saved.
4. Type Штраф `0.5` for seat 6, reload the page mid-entry → form restored from the draft.
5. Fill host + result → save → «Гру збережено…»; it appears in the list; reopen it → Штраф shows `0.5`; in the Firestore console the document has `penalty: -0.5` and `meta/state.updatedAt` changed.

- [ ] **Step 6: Commit**

```bash
git add site/src/pages/host site/src/scripts/host.ts site/src/layouts/Base.astro site/scripts/check-dist.mjs
git commit -m "feat(site): /host/ page — Google sign-in, protocol form with drafts, save to Firestore"
```

---

### Task 10: Hourly rebuild when games change

**Files:**
- Create: `.github/workflows/games-watch.yml`
- Modify: `CLAUDE.md` (Web site section: one paragraph on hosting + watch workflow)

**Interfaces:**
- Consumes: `meta/state` (Task 6 rules make it public-read), `FIREBASE_PROJECT_ID` (Task 1).
- Produces: `workflow_dispatch` of `web.yml` when `meta/state.updatedAt` is new.

- [ ] **Step 1: Workflow**

```yaml
name: Games watch

# Rebuilds the site when a game was saved on /host/ since the last check.
# Must also be on master: GitHub runs `schedule` from the default branch.
on:
  schedule:
    - cron: '17 * * * *' # hourly
  workflow_dispatch:

permissions:
  actions: write
  contents: read

jobs:
  check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    steps:
      - name: Read meta/state.updatedAt
        id: state
        run: |
          ts=$(curl -sf "https://firestore.googleapis.com/v1/projects/<FIREBASE_PROJECT_ID>/databases/(default)/documents/meta/state" \
            | jq -r '.fields.updatedAt.timestampValue // empty')
          echo "ts=${ts:-none}" >> "$GITHUB_OUTPUT"
      - name: Seen before?
        id: seen
        uses: actions/cache/restore@v4
        with:
          path: .games-state
          key: games-state-${{ steps.state.outputs.ts }}
          lookup-only: true
      - name: Rebuild the site
        if: steps.state.outputs.ts != 'none' && steps.seen.outputs.cache-hit != 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh workflow run web.yml --repo "$GITHUB_REPOSITORY" --ref master
      - name: Remember this state
        if: steps.state.outputs.ts != 'none' && steps.seen.outputs.cache-hit != 'true'
        run: echo "${{ steps.state.outputs.ts }}" > .games-state
      - if: steps.state.outputs.ts != 'none' && steps.seen.outputs.cache-hit != 'true'
        uses: actions/cache/save@v4
        with:
          path: .games-state
          key: games-state-${{ steps.state.outputs.ts }}
```

- [ ] **Step 2: CLAUDE.md** — append to the "Web site" section:

```markdown
- **Game hosting (season 32+):** hosts record games on `/host/` (Firebase Auth + Firestore,
  project `<FIREBASE_PROJECT_ID>`, rules in `firestore.rules`, tests in `firebase/rules-test/`).
  Seasons with `"source": "firestore"` are read over REST by `FirestoreService`;
  `games-watch.yml` rebuilds the site hourly when `meta/state.updatedAt` changed. Hosts are
  managed in the Firestore console (`hosts/{email}` = `{name, admin}`).
```

- [ ] **Step 3: Commit and push both branches**

```bash
git add .github/workflows/games-watch.yml CLAUDE.md
git commit -m "ci: hourly site rebuild when games are saved on /host/"
git push origin feature/flutter_migration
git checkout master && git checkout feature/flutter_migration -- .github/workflows/games-watch.yml .github/workflows/firestore-rules.yml \
  && git commit -m "ci: games watch + Firestore rules workflows on master (schedules run from here)" && git push origin master \
  && git checkout feature/flutter_migration
```

- [ ] **Step 4: Verify**

Run: `gh workflow run games-watch.yml --ref master`, then `gh run watch $(gh run list --workflow games-watch.yml --limit 1 --json databaseId -q '.[0].databaseId')`
Expected: `completed success`; since the Task 9 test game bumped `meta/state`, `gh run list --workflow web.yml --limit 1` shows a new `workflow_dispatch` run. Run `games-watch` a second time → no new `web.yml` run (cache hit).

---

### Task 11: End-to-end on test season 999, then clean up

Live config is not touched (season 999 must never appear in the app). The check runs the real pipeline locally against a temporary config.

**Files:**
- Create (temporary, not committed): `$SCRATCH/config-999.json`

- [ ] **Step 1: Snapshot season 999 with the real prefetch**

```bash
cat > "$SCRATCH/config-999.json" <<'EOF'
{"configVersion": 1, "seasons": [
 {"id": 999, "title": "Season 999", "gameLimit": 40, "gamesMultiplier": 0.0, "smallLeagueMinGames": 15, "source": "firestore", "projectId": "<FIREBASE_PROJECT_ID>"}
], "tournaments": []}
EOF
# serve the config over http — start this with the Bash tool's run_in_background, not `&`
python -m http.server 8765 --directory "$SCRATCH"
SHEETS_API_KEY=unused REMOTE_CONFIG_URL=http://localhost:8765/config-999.json dart run tool/prefetch_seasons.dart
```
Expected: `Prefetched 1 remote season(s): 999`; `assets/prefetched/season999.json` holds the game saved in Task 9.

- [ ] **Step 2: Parse it through the app pipeline**

A one-off check in a scratch test (`$SCRATCH/e2e_test.dart` copied to `test/e2e_tmp_test.dart`, deleted after):
```dart
import 'dart:io';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('season 999 snapshot parses', () {
    final games = parseSeasonJsonForTest(999, File('assets/prefetched/season999.json').readAsStringSync());
    expect(games, isNotEmpty);
    expect(games.first.host, isNotEmpty);
    expect(games.first.isNormalGame(), true);
    print('${games.length} game(s); ОП=${games.first.bestMovePoints}; penalty6=${games.first.penaltyPoints![5]}');
  });
}
```
Run: `flutter test test/e2e_tmp_test.dart`
Expected: PASS, prints `ОП=-0.15` and `penalty6=-0.5` for the Task 9 game.

- [ ] **Step 3: Clean up**

```bash
rm test/e2e_tmp_test.dart assets/prefetched/season999.json
# stop the background http.server task (TaskStop)
```
Ask the owner to delete the season-999 game(s) in the Firestore console (or as admin — delete is admin-only in rules). Confirm `git status` is clean.

- [ ] **Step 4: Season 32 go-live (on/after 2026-12-01, owner's call)**

Add to the `seasons` array of **both** `remote_config.json` and `assets/raw/season_config.json` (copy `gameLimit`/`smallLeagueMinGames` from the latest season's entry; ask the owner if they change):
```json
{"id": 32, "title": "Season 32", "gameLimit": 40, "gamesMultiplier": 0.0, "smallLeagueMinGames": 15, "source": "firestore", "projectId": "<FIREBASE_PROJECT_ID>"}
```
Run: `flutter test test/enums/season_test.dart` (config drift check) → PASS.
Commit `feat(config): season 32 recorded on /host/ (Firestore)`, push `feature/flutter_migration` and `master`.
