# Game Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A public `/season/N/games/` page on the stats site listing every game of every season with a full game card (seats, points columns, ПУ / best move, protocol, host comments, event label), linked from player profiles.

**Architecture:** The Dart side gets a pure parser (`sheet_game_extras.dart`) that reads host comments, event labels and table numbers from the *unfiltered* sheet rows and zips them onto the parsed games; Firestore games map their own `comments`/`table`. A new export module writes `site/data/games/N.json` from **all** parsed games (rating and non-rating). Astro renders one static page per season; a small client script does filters and deep links.

**Tech Stack:** Dart / Flutter test, freezed (build_runner), Riverpod; Astro 7, TypeScript, vitest.

**Spec:** `docs/superpowers/specs/2026-10-05-game-browser-design.md`

## Global Constraints

- Branch `feature/flutter_migration`; commit per task; after the last task fast-forward `master` to the same commit (no force-push) — both branches are pushed only when the user says so.
- Seasons: all loaded seasons (0–31 + Firestore). Old seasons show what they have; a block or column with no data is not rendered.
- Read-only and public. No Firebase on this page.
- Site chrome is **English**, like every other page of the site (`Main league`, `Player ratings`, …). The spec's Ukrainian UI strings become English; sheet abbreviations go into tooltips (`Add.` → «доп», `Best move` → «ЛХ/КХ/ОП», `Prot. +` → «ПрДод»). Sheet text (names, comments, labels) is shown as written.
- The games come from the **rules pass** (`_parseSeasonGames(..., sheet: false)`), with canonical player names (`_canonicalNames`).
- Penalties are stored negative: totals **add** them.
- Never render comment or label text with `set:html`; Astro's `{text}` escaping is required.
- `flutter analyze` clean and `flutter test` green at every commit; `cd site && npm test && npm run build` green from Task 6 on.
- Windows: stop any running `astro preview` before `npm ci` (EPERM on a locked `.node`).

## Review Focus

1. **A sheet whose game anchors don't line up with the parsed games** (a stray row passing `_filterRawData`) — expect: no extras for that season (never comments on the wrong game), and the all-seasons alignment test names the season. Test: Task 3 Step 1 (`every bundled season aligns`) + `misaligned extras are dropped`.
2. **A deep link to a game the current filter hides** (`?player=x#g-…` where x didn't play) — expect: filters are cleared, the game opens and scrolls into view. Test: Task 5 `initialView clears filters that hide the target`.
3. **Filtering by a player without a site page** (no slug, e.g. a guest) — expect: the filter key falls back to the name and still matches. Test: Task 5 `matches by name when the player has no slug` + Task 4 `seat without a page has no slug`.
4. **Games without a date** (sheet typos) — expect: ids stay unique (`g-x-<i>`), they are grouped under "No date" at the end. Test: Task 4 `undated games get unique ids and come last`.
5. **Comment text with `<`, `&`, newlines** — expect: shown literally, line breaks kept. Test: Task 2 `keeps < & as written and trims` (parser leaves text raw); Task 6 Step 4 asserts `GameCard.astro` has no `set:html`/`innerHTML` (Astro escapes `{c.text}`), and the card styles comments with `white-space: pre-line`.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/game.dart` (modify) | `GameComment` + optional `comments`, `label`, `table` on `Game` |
| `lib/services/sheet_game_extras.dart` (create) | Pure: raw sheet rows → per-game `SheetGameExtras` (comments, label, table) |
| `lib/services/src/game_parsing.dart` (modify) | Zip extras onto rules-pass games |
| `lib/services/season_loader.dart` (modify) | Public `browserGames(seasonId, json, resolver)` |
| `lib/services/firestore_games.dart` (modify) | Map Firestore `comments` and `table` |
| `lib/site_export/games_export.dart` (create) | `gamesJson(x, season, games)` → `games/N.json` |
| `lib/site_export/site_exporter.dart` (modify) | Load each season's JSON, write `games/N.json` |
| `site/src/lib/types.ts`, `site/src/lib/data.ts` (modify) | `GamesData` type, `loadGames` |
| `site/src/lib/games.ts` (create) | Pure: filters ⇄ query string, matching, hash, number/date format |
| `site/src/lib/url.ts` (modify) | `gamesHref(id, player?)` |
| `site/src/components/SeasonHead.astro` (create) | Season picker + Main / Small / Games pills (shared) |
| `site/src/components/SeasonPage.astro` (modify) | Use `SeasonHead` |
| `site/src/components/GameCard.astro` (create) | One game: `<details>`, seat table, blocks below |
| `site/src/pages/season/[id]/games/index.astro` (create) | The page |
| `site/src/scripts/games.ts` (create) | Filters, open-on-hash, copy link |
| `site/src/components/GamesBySeasonChart.astro`, `site/src/pages/players/[slug].astro` (modify) | Season points link to the filtered games page |

---

### Task 1: `GameComment`, new `Game` fields, Firestore mapping

**Files:**
- Modify: `lib/models/game.dart`
- Modify: `lib/services/firestore_games.dart:22-61` (`gameFromFirestore`)
- Regenerate: `lib/models/game.freezed.dart`
- Test: `test/services/firestore_games_test.dart`

**Interfaces:**
- Produces: `class GameComment { List<int> seats; String text; }` (freezed, in `game.dart`); `Game.comments: List<GameComment>?`, `Game.label: String?`, `Game.table: int?`.

- [ ] **Step 1: Write the failing test** — append to `main()` in `test/services/firestore_games_test.dart`:

```dart
  group('comments and table', () {
    test('maps comments to seats, slot 0 to the whole game, and the table', () {
      final d = doc(table: 2)
        ..['comments'] = [
          {'slot': 6, 'text': 'Зняв 1, заповіт зняти 10'},
          {'slot': 0, 'text': 'Закрили на 2в2'},
          {'slot': 3, 'text': '   '},
          {'slot': 4},
        ];
      final g = gameFromFirestore(32, d);
      expect(g.table, 2);
      expect(g.comments, const [
        GameComment(seats: [6], text: 'Зняв 1, заповіт зняти 10'),
        GameComment(seats: [], text: 'Закрили на 2в2'),
      ]);
      expect(g.label, isNull);
    });

    test('no comments → null', () {
      expect(gameFromFirestore(32, doc()).comments, isNull);
    });
  });
```

Add `import 'package:family_mafia_app/models/game.dart';` at the top.

- [ ] **Step 2: Run it — expect a compile failure** (`GameComment` undefined)

Run: `flutter test test/services/firestore_games_test.dart`

- [ ] **Step 3: Add the model fields.** In `lib/models/game.dart`, inside the `Game` factory after `List<int>? fouls,`:

```dart
    List<GameComment>? comments, // host's comments, sheet order; null = none recorded
    String? label, // event label above the game in the sheet («МІНІКАП», «Гра 3»)
    int? table, // 1/2 when known: Firestore `table`, or a «Стіл N» label in the sheet
```

and below the `Game` class (before `extension GameListExtensions`):

```dart
@freezed
class GameComment with _$GameComment {
  const factory GameComment({
    @Default([]) List<int> seats, // 1-indexed; empty = about the whole game
    required String text,
  }) = _GameComment;
}
```

Run: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Map them in `gameFromFirestore`.** Add before `return Game(`:

```dart
  final comments = [
    for (final c in ((doc['comments'] as List?) ?? const []).whereType<Map>())
      if (c['text'] is String && (c['text'] as String).trim().isNotEmpty)
        GameComment(
          seats: switch (c['slot']) {
            final num s when s >= 1 && s <= 10 => [s.toInt()],
            _ => const [],
          },
          text: (c['text'] as String).trim(),
        ),
  ];
```

and in the `Game(...)` call:

```dart
    comments: comments.isEmpty ? null : comments,
    table: (doc['table'] as num?)?.toInt(),
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/services/firestore_games_test.dart && flutter analyze`
Expected: PASS, no issues.

- [ ] **Step 6: Commit**

```bash
git add lib/models/game.dart lib/models/game.freezed.dart lib/services/firestore_games.dart test/services/firestore_games_test.dart
git commit -m "feat: comments, label and table on Game; map them from Firestore"
```

---

### Task 2: `sheetGameExtras` — comments, labels and tables from raw sheet rows

**Files:**
- Create: `lib/services/sheet_game_extras.dart`
- Test: `test/services/sheet_game_extras_test.dart`

**Interfaces:**
- Consumes: `GameComment` (Task 1), `GamesDataSeason` (`lib/models/games_data_season.dart`, string fields `a`…`q`), `kLegacyMaxSeason` (=16), `kOldFormatMaxSeason` (=1).
- Produces:
  - `class SheetGameExtras { final List<GameComment> comments; final String? label; final int? table; }`
  - `List<SheetGameExtras> sheetGameExtras(int seasonId, List<GamesDataSeason> raw)` — one entry per game anchor, in sheet order.
  - `List<int>? parseSeatList(String cell)`, `List<GameComment> parseCommentText(String text)` (public for tests).

Background (from the spec's survey of every snapshot):

| Seasons | Game anchor (raw row) | Comments |
|---|---|---|
| 0–1 | `int(a) == 1` | a row with only `a` filled, containing a letter → whole-game comment on the game **before** it |
| 2–16 | `int(a) == 1` | seat rows `int(a)` in 4..8 with empty `b` and a letter in `c` → whole-game comment |
| 17+ | `a.trim() == 'Дата'` | (17–18) the row with `b == 'Додаткові бали:'`: its other text cells; (19+) every row after a «Коментарі до дод балів» header up to the next anchor: text cells in columns B..Q |
| 17+ labels | — | rows with only `a` filled (a letter in it) among the 3 raw rows before an anchor |

- [ ] **Step 1: Write the failing tests** — `test/services/sheet_game_extras_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/services/sheet_game_extras.dart';
import 'package:flutter_test/flutter_test.dart';

List<GamesDataSeason> rows(String path) => (jsonDecode(File(path).readAsStringSync()) as List)
    .cast<Map<String, dynamic>>()
    .map(GamesDataSeason.fromJson)
    .toList();

List<GamesDataSeason> season(int id) {
  final bundled = File('assets/raw/season$id.json');
  return rows(bundled.existsSync() ? bundled.path : 'assets/prefetched/season$id.json');
}

Iterable<GameComment> allComments(List<SheetGameExtras> e) => e.expand((g) => g.comments);

GameComment? find(List<SheetGameExtras> e, String textStart) =>
    allComments(e).where((c) => c.text.startsWith(textStart)).firstOrNull;

bool hasPrefetched(int id) => File('assets/prefetched/season$id.json').existsSync();

void main() {
  group('parseSeatList', () {
    test('single, dotted, comma and spaced lists', () {
      expect(parseSeatList('6'), [6]);
      expect(parseSeatList('10'), [10]);
      expect(parseSeatList('10.0'), [10]);
      expect(parseSeatList('6.9'), [6, 9]);
      expect(parseSeatList('3,6'), [3, 6]);
      expect(parseSeatList('3, 6'), [3, 6]);
    });
    test('not seats: dates, out of range, text, empty', () {
      expect(parseSeatList('2025-05-06T21:00:00.000Z'), isNull);
      expect(parseSeatList('28'), isNull);
      expect(parseSeatList('0'), isNull);
      expect(parseSeatList('Номер'), isNull);
      expect(parseSeatList(''), isNull);
    });
  });

  group('parseCommentText', () {
    test('seat prefixes with every separator', () {
      expect(parseCommentText('3 - виграв версію'), const [GameComment(seats: [3], text: 'виграв версію')]);
      expect(parseCommentText('10. Хаотично заголосував чорних'),
          const [GameComment(seats: [10], text: 'Хаотично заголосував чорних')]);
      expect(parseCommentText('3,6 - були мирні'), const [GameComment(seats: [3, 6], text: 'були мирні')]);
      expect(parseCommentText('8-голосував дона'), const [GameComment(seats: [8], text: 'голосував дона')]);
      expect(parseCommentText('6: промах'), const [GameComment(seats: [6], text: 'промах')]);
    });
    test('one cell, several lines', () {
      expect(parseCommentText('5 0.1 ОП\n1 0.6 вписався в 9ці\n'), const [
        GameComment(seats: [5], text: '0.1 ОП'),
        GameComment(seats: [1], text: '0.6 вписався в 9ці'),
      ]);
    });
    test('no prefix or a bad seat → whole-game comment', () {
      expect(parseCommentText('Закрили на 2в2'), const [GameComment(text: 'Закрили на 2в2')]);
      expect(parseCommentText('28 атака'), const [GameComment(text: '28 атака')]);
      expect(parseCommentText('2в2 закрили'), const [GameComment(text: '2в2 закрили')]);
    });
    test('keeps < & as written and trims', () {
      expect(parseCommentText('  4 - <b>&  '), const [GameComment(seats: [4], text: '<b>&')]);
    });
  });

  group('real snapshots', () {
    test('S0: standalone note row goes to the game before it', () {
      final e = sheetGameExtras(0, season(0));
      final c = find(e, 'Ничья, всем по 1 баллу')!;
      expect(c.seats, isEmpty);
      expect(e.first.comments, isEmpty);
    });
    test('S13: sidebar note', () {
      expect(find(sheetGameExtras(13, season(13)), 'Не правильно зарахувала відстріл')!.seats, isEmpty);
    });
    test('S18: «Додаткові бали:» multi-line, host chat ignored', () {
      final e = sheetGameExtras(18, season(18));
      expect(find(e, 'виграв версію, усі заповіти')!.seats, [3]);
      expect(find(e, 'зробив хід у 9-ті')!.seats, [6]);
      expect(allComments(e).where((c) => c.text.contains('сізоу')), isEmpty);
    });
    test('S21: pairs in B/C and H/I', () {
      final e = sheetGameExtras(21, season(21));
      expect(find(e, 'играл в черных, закрыл в угадайке')!.seats, [1]);
      expect(find(e, 'играла во всех черных')!.seats, [8]);
    });
    test('S26: pair in G/H', () {
      final e = sheetGameExtras(26, season(26));
      expect(find(e, 'Стала жертвою стратегії дона')!.seats, [10]);
      expect(find(e, 'Схватив Ская за волосся')!.seats, [5]);
    });
    test('S28: a number cell turned into a date → no seats', () {
      expect(find(sheetGameExtras(28, season(28)), 'голосували в чорних без балансу')!.seats, isEmpty);
    });
    test('S29: one cell with prefixed lines, and text in B', () {
      final e = sheetGameExtras(29, season(29));
      expect(find(e, '0.1 ОП')!.seats, [5]);
      expect(find(e, '0.6 вписався в 9ці')!.seats, [1]);
      expect(find(e, 'були мирні по столу')!.seats, [3, 6]);
    }, skip: !hasPrefetched(29));
    test('S30: «6.9» number cell → two seats', () {
      expect(find(sheetGameExtras(30, season(30)), 'Закрили на 2в2')!.seats, [6, 9]);
    }, skip: !hasPrefetched(30));
    test('labels are not comments', () {
      for (final id in [19, 22, 26]) {
        final texts = allComments(sheetGameExtras(id, season(id))).map((c) => c.text);
        for (final l in ['Номер', 'Коментарі до дод балів', 'Відстріл']) {
          expect(texts, isNot(contains(l)), reason: 'S$id $l');
        }
      }
    });
  });

  group('labels and tables', () {
    test('S25: «СТІЛ 1» / «СТІЛ 2» set the table, not a label', () {
      final e = sheetGameExtras(25, season(25));
      expect(e.where((g) => g.table == 1), isNotEmpty);
      expect(e.where((g) => g.table == 2), isNotEmpty);
      expect(e.map((g) => g.label).whereType<String>().where((l) => l.toLowerCase().contains('стіл')), isEmpty);
    });
    test('S27: stacked titles join, other titles are labels', () {
      final labels = sheetGameExtras(27, season(27)).map((g) => g.label).whereType<String>().toList();
      expect(labels, contains('Класичний вечір 1 · Гра 1'));
      expect(labels, contains('ФІНАЛ МІНІКАПІВ'));
    });
    test('S20: event label', () {
      expect(sheetGameExtras(20, season(20)).map((g) => g.label), contains('Міні міні-кап'));
    });
    test('the table sticks to later games of the same date only', () {
      GamesDataSeason r(Map<String, dynamic> m) => GamesDataSeason.fromJson(m);
      final raw = [
        r({'A': 'СТІЛ 2'}),
        r({'A': 'Дата', 'B': '2025-05-01', 'C': 'Ведучий'}),
        r({'A': 'Дата', 'B': '2025-05-01', 'C': 'Ведучий'}),
        r({'A': 'Дата', 'B': '2025-05-03', 'C': 'Ведучий'}),
      ];
      expect(sheetGameExtras(25, raw).map((g) => g.table), [2, 2, null]);
    });
  });
}
```

- [ ] **Step 2: Run them — expect a compile failure** (`sheet_game_extras.dart` missing)

Run: `flutter test test/services/sheet_game_extras_test.dart`

- [ ] **Step 3: Implement** — `lib/services/sheet_game_extras.dart`:

```dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';

/// What a season sheet says about a game outside its 10/14 parsed rows: the
/// host's comments, the event title above it, and the table it was played at.
class SheetGameExtras {
  const SheetGameExtras({this.comments = const [], this.label, this.table});
  final List<GameComment> comments;
  final String? label;
  final int? table;
}

const _kCommentsHeader = 'Коментарі до дод балів';
const _kExtraPointsHeader = 'Додаткові бали:';
const _kLabels = {
  'Номер', _kCommentsHeader, _kExtraPointsHeader, 'Відстріл', 'Голоси', 'Гравець',
};

final _letter = RegExp(r'\p{L}', unicode: true);
final _seatList = RegExp(r'^\d{1,2}(?:\s*[.,]\s*\d{1,2})*$');
final _prefix = RegExp(r'^(\d{1,2}(?:\s*,\s*\d{1,2})*)\s*(?:[-–—:.)]\s*|\s+)(.+)$', dotAll: true);
final _tableLabel = RegExp(r'(?:^|\s)(?:([12])\s*(?:-?ий)?\s*стіл|стіл\s*([12]))(?:$|[\s,])', caseSensitive: false);
final _onlyTable = RegExp(r'^\s*(?:[12]\s*(?:-?ий)?\s*стіл|стіл\s*[12])\s*$', caseSensitive: false);

bool _isText(String s) {
  final t = s.trim();
  return t.isNotEmpty && _letter.hasMatch(t) && !_kLabels.contains(t) && !t.startsWith('Голосування');
}

/// Seats named by a «Номер» cell: `6`, `10.0`, `6.9`, `3,6`, `3, 6`. Null when
/// the cell is not seat numbers 1–10 — a date the sheet made of «6,5», say.
List<int>? parseSeatList(String cell) {
  var s = cell.trim();
  if (RegExp(r'^\d{1,2}\.0$').hasMatch(s)) s = s.substring(0, s.length - 2);
  if (!_seatList.hasMatch(s)) return null;
  final seats = s.split(RegExp(r'\s*[.,]\s*')).map(int.parse).toList();
  return seats.every((n) => n >= 1 && n <= 10) ? seats : null;
}

/// A comment cell with no seat number beside it: each line may start with
/// seats (`3 - …`, `10. …`, `3,6 - …`, `5 0.1 ОП`); lines without valid seats
/// are about the whole game.
List<GameComment> parseCommentText(String text) => [
      for (final raw in text.split('\n'))
        if (raw.trim().isNotEmpty) _line(raw.trim()),
    ];

GameComment _line(String line) {
  final m = _prefix.firstMatch(line);
  if (m != null) {
    final seats = parseSeatList(m.group(1)!);
    final rest = m.group(2)!.trim();
    if (seats != null && rest.isNotEmpty) return GameComment(seats: seats, text: rest);
  }
  return GameComment(text: line);
}

List<String> _cols(GamesDataSeason r) =>
    [r.a, r.b, r.c, r.d, r.e, r.f, r.g, r.h, r.i, r.j, r.k, r.l, r.m, r.n, r.o, r.p, r.q];

bool _onlyA(GamesDataSeason r) {
  final c = _cols(r);
  return c.first.trim().isNotEmpty && c.skip(1).every((v) => v.trim().isEmpty);
}

/// Comments in one row of a comment block (columns B..Q): a text cell whose
/// left neighbour is a seat list belongs to those seats; one whose left
/// neighbour holds anything else (a date) has no seats; one with an empty
/// left neighbour is split by line prefixes.
List<GameComment> _rowComments(GamesDataSeason r) {
  final c = _cols(r);
  final out = <GameComment>[];
  for (var i = 1; i < c.length; i++) {
    if (!_isText(c[i])) continue;
    final left = i > 1 ? c[i - 1].trim() : '';
    // A label on the left («Додаткові бали:», «Номер») is no seat number either.
    if (left.isEmpty || _isText(left) || _kLabels.contains(left)) {
      out.addAll(parseCommentText(c[i]));
    } else {
      final seats = parseSeatList(left);
      out.add(GameComment(seats: seats ?? const [], text: c[i].trim()));
    }
  }
  return out;
}

/// One [SheetGameExtras] per game anchor in [raw] (unfiltered season rows),
/// in sheet order — the same games, in the same order, as the parser's chunks.
List<SheetGameExtras> sheetGameExtras(int seasonId, List<GamesDataSeason> raw) {
  if (seasonId <= kLegacyMaxSeason) return _legacy(seasonId, raw);
  return _modern(raw);
}

List<SheetGameExtras> _legacy(int seasonId, List<GamesDataSeason> raw) {
  final games = <List<GameComment>>[];
  for (final r in raw) {
    final seat = int.tryParse(r.a.trim());
    if (seat == 1) games.add([]);
    if (games.isEmpty) continue;
    if (seasonId <= kOldFormatMaxSeason) {
      if (seat == null && _onlyA(r) && _isText(r.a)) games.last.add(GameComment(text: r.a.trim()));
    } else if (seat != null && seat >= 4 && seat <= 8 && r.b.trim().isEmpty && _isText(r.c)) {
      games.last.add(GameComment(text: r.c.trim()));
    }
  }
  return [for (final c in games) SheetGameExtras(comments: c)];
}

List<SheetGameExtras> _modern(List<GamesDataSeason> raw) {
  final out = <SheetGameExtras>[];
  var comments = <GameComment>[];
  var inBlock = false;
  int? table;
  String? tableDate;
  bool started = false;

  void close() {
    if (!started) return;
    final last = out.removeLast();
    out.add(SheetGameExtras(comments: comments, label: last.label, table: last.table));
  }

  for (var i = 0; i < raw.length; i++) {
    final r = raw[i];
    if (r.a.trim() == 'Дата') {
      close();
      final date = r.b.trim();
      final titles = [
        for (var k = i - 3; k < i; k++)
          if (k >= 0 && _onlyA(raw[k]) && _isText(raw[k].a)) raw[k].a.trim(),
      ];
      if (date != tableDate) table = null;
      final labels = <String>[];
      for (final t in titles) {
        final m = _tableLabel.firstMatch(t);
        if (m != null) {
          table = int.parse(m.group(1) ?? m.group(2)!);
          if (_onlyTable.hasMatch(t)) continue;
        }
        labels.add(t);
      }
      tableDate = date;
      out.add(SheetGameExtras(label: labels.isEmpty ? null : labels.join(' · '), table: table));
      started = true;
      comments = [];
      inBlock = false;
      continue;
    }
    if (!started) continue;
    final cols = _cols(r);
    if (r.b.trim() == _kExtraPointsHeader) {
      // Seasons 17–18: the comments sit in this one row, after the label.
      comments.addAll(_rowComments(r));
      continue;
    }
    if (cols.any((v) => v.trim() == _kCommentsHeader)) {
      inBlock = true;
      continue;
    }
    if (inBlock && !_onlyA(r)) comments.addAll(_rowComments(r));
  }
  close();
  return out;
}
```

Note on `_rowComments` for the 17–18 label row: its `b` cell is «Додаткові бали:» — skipped as a comment by `_isText`, and as a left neighbour it counts as "no seat cell" (`_kLabels.contains(left)`), so the text in `c` goes through `parseCommentText` and the `3 - …` lines get their seats.

- [ ] **Step 4: Run tests**

Run: `flutter test test/services/sheet_game_extras_test.dart`
Expected: PASS (S29/S30 skipped if `assets/prefetched/` is absent). If a real-snapshot test fails, print the game's raw rows (as in the spec survey) and fix the rule — do not loosen the assertion.

- [ ] **Step 5: Commit**

```bash
git add lib/services/sheet_game_extras.dart test/services/sheet_game_extras_test.dart
git commit -m "feat: read host comments, event labels and tables from the season sheets"
```

---

### Task 3: Zip extras onto parsed games; public `browserGames`

**Files:**
- Modify: `lib/services/src/game_parsing.dart:17-28` (`_parseSeasonGames`)
- Modify: `lib/services/season_loader.dart` (imports; add `browserGames`)
- Test: `test/services/sheet_game_extras_alignment_test.dart`

**Interfaces:**
- Consumes: `sheetGameExtras` (Task 2), `_canonicalNames` (`isolate_functions.dart`), `PlayerResolver`.
- Produces: `List<Game> browserGames(int seasonId, String json, PlayerResolver resolver)` — every parsed game of the season (rating, non-rating, irregular), rules pass, canonical names, extras attached. `parseSeasonJsonForTest` now also returns extras.

- [ ] **Step 1: Write the failing tests** — `test/services/sheet_game_extras_alignment_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/services/sheet_game_extras.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

String? seasonFile(int id) {
  for (final p in ['assets/raw/season$id.json', 'assets/prefetched/season$id.json']) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

void main() {
  test('every bundled and prefetched season aligns extras with games', () {
    for (var id = 0; id <= 40; id++) {
      final path = seasonFile(id);
      if (path == null) continue;
      final json = File(path).readAsStringSync();
      if (json.trimLeft().startsWith('{')) continue; // firestore snapshot
      final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>().map(GamesDataSeason.fromJson).toList();
      expect(sheetGameExtras(id, raw).length, parseSeasonJsonForTest(id, json).length, reason: 'season $id');
    }
  });

  test('S21 games carry their comments; S25 games their tables', () {
    final s21 = parseSeasonJsonForTest(21, File('assets/raw/season21.json').readAsStringSync());
    final g = s21.firstWhere((g) => g.comments?.any((c) => c.text.startsWith('играла во всех черных')) ?? false);
    expect(g.players[7], isNotEmpty); // seat 8 exists
    final s25 = parseSeasonJsonForTest(25, File('assets/raw/season25.json').readAsStringSync());
    expect(s25.where((g) => g.table == 2), isNotEmpty);
  });

  test('misaligned extras are dropped, not shifted', () {
    final rows = (jsonDecode(File('assets/raw/season21.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    // An extra «Дата» row with nothing after it adds an anchor but no game.
    final broken = [...rows, {'A': 'Дата', 'B': '2024-05-31', 'C': ''}];
    final games = parseSeasonJsonForTest(21, jsonEncode(broken));
    expect(games.every((g) => g.comments == null && g.label == null && g.table == null), isTrue);
  });

  test('browserGames keeps non-rating games and canonical names', () {
    final players = (jsonDecode(File('assets/raw/players.json').readAsStringSync()) as List)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
    final json = File('assets/raw/season21.json').readAsStringSync();
    final all = browserGames(21, json, PlayerResolver(players));
    expect(all.length, parseSeasonJsonForTest(21, json).length);
    expect(all.where((g) => !g.isRatingGame()), isNotEmpty);
  });
}
```

(The broken row has `C: ''`, so `_filterRawData` drops it and the game count is unchanged, while `sheetGameExtras` sees one more anchor.)

- [ ] **Step 2: Run — expect failures** (`browserGames` undefined; no extras yet)

Run: `flutter test test/services/sheet_game_extras_alignment_test.dart`

- [ ] **Step 3: Implement.** In `lib/services/season_loader.dart` add `import 'package:family_mafia_app/services/sheet_game_extras.dart';` to the imports and, after `parseSeasonJsonForTest`:

```dart
/// Every game of a season as the site's game browser shows it: rating and
/// non-rating, by the club's rules, names made canonical, comments attached.
List<Game> browserGames(int seasonId, String json, PlayerResolver resolver) =>
    _canonicalNames(_parseSeasonGames(seasonId, json), resolver);
```

In `lib/services/src/game_parsing.dart`, replace the body of `_parseSeasonGames` after the Firestore branch:

```dart
  final raw = (decoded as List)
      .cast<Map<String, dynamic>>()
      .map(GamesDataSeason.fromJson)
      .toList();
  final games = _getGamesDataSeason(
      seasonId, raw.where((d) => _filterRawData(d, seasonId)).toList(),
      sheet: sheet);
  // The sheet-quirk pass only feeds the main-league table; it needs no extras.
  if (sheet) return games;
  return _withExtras(seasonId, games, sheetGameExtras(seasonId, raw));
}

/// [extras] zipped onto [games] by position. If the anchors don't line up the
/// sheet has a stray row; no extras beat comments on the wrong game.
List<Game> _withExtras(int seasonId, List<Game> games, List<SheetGameExtras> extras) {
  if (extras.length != games.length) {
    debugPrint('Season $seasonId: ${extras.length} comment blocks for ${games.length} games, skipping comments');
    return games;
  }
  return [
    for (var i = 0; i < games.length; i++)
      games[i].copyWith(
        comments: extras[i].comments.isEmpty ? null : extras[i].comments,
        label: extras[i].label,
        table: extras[i].table,
      ),
  ];
}
```

- [ ] **Step 4: Run all Dart tests** — the rating code must be unaffected.

Run: `flutter test && flutter analyze`
Expected: PASS. If the alignment test names a season, look at its raw rows around the first mismatch (count anchors vs chunks), and fix the anchor rule in `sheet_game_extras.dart` — not the test.

- [ ] **Step 5: Commit**

```bash
git add lib/services/season_loader.dart lib/services/src/game_parsing.dart test/services/sheet_game_extras_alignment_test.dart
git commit -m "feat: attach sheet comments, labels and tables to parsed games"
```

---

### Task 4: `games/N.json` export

**Files:**
- Create: `lib/site_export/games_export.dart`
- Modify: `lib/site_export/site_exporter.dart`
- Test: `test/site_export/games_export_test.dart`, `test/site_export/site_exporter_test.dart`

**Interfaces:**
- Consumes: `browserGames` (Task 3), `ExportContext` (`x.players`, `x.slugs`, `x.read`), `playerResolverProvider` (`lib/screens/players/players_providers.dart` — check the import used by `debug_export.dart`), `seasonCacheServiceProvider`, `SeasonDataService`.
- Produces:
  - `Map<String, Object?> gamesJson(ExportContext x, SeasonConfig season, List<Game> games)`
  - `Future<void> writeSiteData(ProviderContainer container, Directory out, {Future<String?> Function(SeasonConfig)? seasonJson})`
  - JSON shape (all optional keys omitted when empty/zero/null):

```
{ season, autoLabel: 'ЛХ'|'КХ'|'ОП', players: [{name, key}], hosts: [string],
  days: [{ date: 'YYYY-MM-DD'|null,
           games: [{ id, n, table?, label?, host?, result: 'city'|'mafia'|'unrated',
                     seats: [{ n, player?, slug?, key?, role, fouls?, won?, add?, ad?, bm?, pen?, prAdd?, prPen?, total? }],
                     firstKilled?, bestMove?: [int], bestMovePoints?,
                     supportFive?: [{seat, black}],
                     protocol?: [{killed, version?, colors: [{seat, black}]}],
                     comments?: [{seats: [int], text}] }] }] }
```

`key` = slug when the player has a page, else the name — the filter's identity. `role` is `civilian|sheriff|mafia|don` or the raw cell when unknown. `bm` is the best-move points on the first-killed seat only.

- [ ] **Step 1: Write the failing tests** — `test/site_export/games_export_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/games_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  late ExportContext x;
  setUp(() async => x = ExportContext(await fixtureContainer()));

  List<Game> load(int id) => browserGames(
      id, File('assets/raw/season$id.json').readAsStringSync(), x.read(playerResolverProvider));
  Map json(int id) => jsonDecode(jsonEncode(gamesJson(x, x.seasons.firstWhere((s) => s.id == id), load(id)))) as Map;
  List<Map> games(Map j) => [for (final d in j['days'] as List) ...(d['games'] as List).cast<Map>()];

  test('every parsed game, 10 seats, unique ids', () {
    final j = json(21);
    final gs = games(j);
    expect(gs.length, load(21).length);
    expect(gs.every((g) => (g['seats'] as List).length == 10), isTrue);
    expect(gs.map((g) => g['id']).toSet().length, gs.length);
    expect(j['autoLabel'], 'КХ');
  });

  test('total is the sum of the columns', () {
    for (final g in games(json(21))) {
      for (final s in (g['seats'] as List).cast<Map>()) {
        final sum = ['won', 'add', 'ad', 'bm', 'pen', 'prAdd', 'prPen']
            .map((k) => k == 'won' ? (s['won'] == true ? 1.0 : 0.0) : ((s[k] as num?)?.toDouble() ?? 0))
            .fold(0.0, (a, b) => a + b);
        expect((s['total'] as num? ?? 0).toDouble(), closeTo(sum, 1e-9), reason: '${g['id']} seat ${s['n']}');
      }
    }
  });

  test('comments survive with their seats and raw text', () {
    final c = games(json(21)).expand((g) => (g['comments'] as List? ?? const []).cast<Map>())
        .firstWhere((c) => (c['text'] as String).startsWith('играла во всех черных'));
    expect(c['seats'], [8]);
  });

  test('seat without a page has no slug and keys by name', () {
    final seats = games(json(21)).expand((g) => (g['seats'] as List).cast<Map>()).where((s) => s['player'] != null);
    final withPage = {for (final p in x.players) p.displayName};
    for (final s in seats) {
      if (withPage.contains(s['player'])) {
        expect(s['key'], s['slug']);
      } else {
        expect(s.containsKey('slug'), isFalse);
        expect(s['key'], s['player']);
      }
    }
  });

  test('undated games get unique ids and come last', () {
    final gs = load(21);
    final undated = [gs[0].copyWith(date: null), gs[1].copyWith(date: null), ...gs.skip(2)];
    final j = jsonDecode(jsonEncode(gamesJson(x, x.seasons.firstWhere((s) => s.id == 21), undated))) as Map;
    final days = (j['days'] as List).cast<Map>();
    expect(days.last['date'], isNull);
    expect((days.last['games'] as List).map((g) => g['id']), ['g-x-0', 'g-x-1']);
  });

  test('result, host filter list and players list', () {
    final j = json(21);
    expect(games(j).map((g) => g['result']).toSet(), containsAll(['city', 'mafia', 'unrated']));
    expect(j['hosts'], isNotEmpty);
    expect((j['players'] as List).cast<Map>().every((p) => p['key'] != null && p['name'] != null), isTrue);
  });
}
```

And in `test/site_export/site_exporter_test.dart` change the call and the expected files:

```dart
    await writeSiteData(await fixtureContainer(), out,
        seasonJson: (c) async => File('assets/raw/season${c.id}.json').readAsStringSync());

    for (final f in ['index.json', 'players.json', 'records.json', 'tournaments.json', 'season/17.json', 'season/21.json', 'games/17.json', 'games/21.json']) {
```

- [ ] **Step 2: Run — expect a compile failure** (`games_export.dart` missing)

Run: `flutter test test/site_export/games_export_test.dart test/site_export/site_exporter_test.dart`

- [ ] **Step 3: Implement** — `lib/site_export/games_export.dart`:

```dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';

/// The sheet's name for the best-move points column of [seasonId].
String autoLabel(int seasonId) =>
    seasonId <= kLegacyMaxSeason ? 'ЛХ' : seasonId <= kPreProtocolMaxSeason ? 'КХ' : 'ОП';

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _role(String cell) => switch (Role.findByValue(cell.trim())) {
      Role.civilian => 'civilian',
      Role.sheriff => 'sheriff',
      Role.mafia => 'mafia',
      Role.don => 'don',
      null => cell.trim(),
    };

/// Rounded to 2 decimals; null for zero so the key is left out.
double? _pts(double? v) => v == null || v.roundTo(2) == 0 ? null : v.roundTo(2);

List<Map<String, Object>> _colors(List<int> signed) =>
    [for (final c in signed) {'seat': c.abs(), 'black': c < 0}];

Map<String, Object?> _compact(Map<String, Object?> m) =>
    {for (final e in m.entries) if (e.value != null) e.key: e.value};

/// One season's games for /season/N/games/, grouped by day in sheet order.
Map<String, Object?> gamesJson(ExportContext x, SeasonConfig season, List<Game> games) {
  final resolver = x.read(playerResolverProvider);
  final onSite = {for (final p in x.players) p.id};
  String? slugOf(String name) {
    final p = resolver.resolve(name);
    return onSite.contains(p.id) ? x.slugs[p.id] : null;
  }

  Map<String, Object?> seat(Game g, int i) {
    final raw = g.players[i];
    final blank = raw.startsWith('_blank_');
    final slug = blank ? null : slugOf(raw);
    final won = !blank && g.isRatingGame() && g.hasPlayerWon(raw);
    final bm = g.firstKilled == i + 1 ? g.bestMovePoints : null;
    final parts = [
      won ? 1.0 : 0.0,
      g.additionalPoints?[i] ?? 0, g.autoAdditionalPoints?[i] ?? 0, bm ?? 0,
      g.penaltyPoints?[i] ?? 0, g.protocolAdditionalPoints?[i] ?? 0, g.protocolPenaltyPoints?[i] ?? 0,
    ];
    return _compact({
      'n': i + 1,
      'player': blank ? null : raw,
      'slug': slug,
      'key': blank ? null : (slug ?? raw),
      'role': _role(g.roles[i]),
      'fouls': (g.fouls?[i] ?? 0) == 0 ? null : g.fouls![i],
      'won': won ? true : null,
      'add': _pts(g.additionalPoints?[i]),
      'ad': _pts(g.autoAdditionalPoints?[i]),
      'bm': _pts(bm),
      'pen': _pts(g.penaltyPoints?[i]),
      'prAdd': _pts(g.protocolAdditionalPoints?[i]),
      'prPen': _pts(g.protocolPenaltyPoints?[i]),
      'total': _pts(parts.fold<double>(0, (a, b) => a + b)),
    });
  }

  final byDay = <String?, List<Game>>{};
  for (final g in games) {
    byDay.putIfAbsent(g.date == null ? null : _day(g.date!), () => []).add(g);
  }
  final keys = [...byDay.keys.whereType<String>(), if (byDay.containsKey(null)) null];

  Map<String, Object?> game(Game g, String id, int n) => _compact({
                'id': id,
                'n': n,
                'table': g.table,
                'label': g.label,
                'host': g.host,
                'result': switch (g.cityWon) { true => 'city', false => 'mafia', null => 'unrated' },
                'seats': [for (var i = 0; i < g.players.length; i++) seat(g, i)],
                'firstKilled': g.firstKilled == 0 ? null : g.firstKilled,
                'bestMove': g.bestMove.where((s) => s > 0).isEmpty ? null : g.bestMove.where((s) => s > 0).toList(),
                'bestMovePoints': _pts(g.firstKilled == 0 ? null : g.bestMovePoints),
                'supportFive': g.supportFive == null ? null : _colors(g.supportFive!),
                'protocol': g.protocol == null
                    ? null
                    : [
                        for (final p in g.protocol!)
                          _compact({'killed': p.killedSlot, 'version': p.sheriffVersion, 'colors': _colors(p.colorGuesses)}),
                      ],
                'comments': g.comments == null
                    ? null
                    : [for (final c in g.comments!) {'seats': c.seats, 'text': c.text}],
              });

  final days = <Map<String, Object?>>[];
  for (final d in keys) {
    final counters = <int, int>{}; // per table: n = order within the date and table
    final out = <Map<String, Object?>>[];
    final dayGames = byDay[d]!;
    for (var i = 0; i < dayGames.length; i++) {
      final g = dayGames[i];
      final t = g.table ?? 1;
      final n = counters[t] = (counters[t] ?? 0) + 1;
      out.add(d == null ? game(g, 'g-x-$i', i + 1) : game(g, 'g-$d-$t-$n', n));
    }
    days.add({'date': d, 'games': out});
  }

  final players = <String, String>{};
  for (final g in games) {
    for (final p in g.players.where((p) => !p.startsWith('_blank_'))) {
      players.putIfAbsent(slugOf(p) ?? p, () => p);
    }
  }
  return {
    'season': season.id,
    'autoLabel': autoLabel(season.id),
    'players': [
      for (final e in players.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase())))
        {'name': e.value, 'key': e.key},
    ],
    'hosts': ({for (final g in games) if (g.host != null) g.host!}.toList()..sort()),
    'days': days,
  };
}
```

In `lib/site_export/site_exporter.dart`:

```dart
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/season_data_service.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/site_export/games_export.dart';
```

change the signature and add after the `season/` loop:

```dart
Future<void> writeSiteData(ProviderContainer container, Directory out,
    {Future<String?> Function(SeasonConfig)? seasonJson}) async {
  ...
  // The repositories hold rating games only; the game browser shows them all,
  // so it parses each season's JSON again, the same way the loader does.
  final load = seasonJson ??
      SeasonDataService(
        sheetsService: null,
        cacheService: container.read(seasonCacheServiceProvider),
      ).loadSeasonJson;
  final resolver = x.read(playerResolverProvider);
  for (final season in x.seasons) {
    final json = await load(season);
    if (json == null) throw StateError('Season ${season.id}: no JSON for the games page');
    write('games/${season.id}.json', gamesJson(x, season, browserGames(season.id, json, resolver)));
  }
```

(If `playerResolverProvider` lives elsewhere, use the import `debug_export.dart` uses.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/site_export && flutter analyze`
Expected: PASS.

- [ ] **Step 5: Real export smoke run** (needs `assets/prefetched/`):

Run: `flutter test tool/export_site_data_test.dart && ls site/data/games | wc -l && du -sh site/data/games`
Expected: one file per loaded season (32); total a few MB.

- [ ] **Step 6: Commit**

```bash
git add lib/site_export/games_export.dart lib/site_export/site_exporter.dart test/site_export/games_export_test.dart test/site_export/site_exporter_test.dart
git commit -m "feat(site): export every game of every season to games/N.json"
```

---

### Task 5: Site data types and pure helpers

**Files:**
- Modify: `site/src/lib/types.ts`, `site/src/lib/data.ts`, `site/src/lib/url.ts`
- Create: `site/src/lib/games.ts`
- Test: `site/src/lib/games.test.ts`

**Interfaces:**
- Consumes: `games/N.json` shape (Task 4).
- Produces (TS):

```ts
export interface GameSeat { n: number; player?: string; slug?: string; key?: string; role: string; fouls?: number; won?: boolean;
  add?: number; ad?: number; bm?: number; pen?: number; prAdd?: number; prPen?: number; total?: number }
export interface ColorGuess { seat: number; black: boolean }
export interface GameEntry { id: string; n: number; table?: number; label?: string; host?: string;
  result: 'city' | 'mafia' | 'unrated'; seats: GameSeat[]; firstKilled?: number; bestMove?: number[]; bestMovePoints?: number;
  supportFive?: ColorGuess[]; protocol?: { killed: number; version?: number; colors: ColorGuess[] }[];
  comments?: { seats: number[]; text: string }[] }
export interface GamesData { season: number; autoLabel: string; players: { name: string; key: string }[]; hosts: string[];
  days: { date: string | null; games: GameEntry[] }[] }
```

  `games.ts`: `GameFilters`, `parseFilters(search)`, `filtersToSearch(f)`, `matchesFilters(keys, host, f)`, `gameIdFromHash(hash)`, `initialView(hash, filters, gameMatches)`, `fmtPts(v)`, `dayLabel(date)`.
  `url.ts`: `gamesHref(id: number, player?: string)`.

- [ ] **Step 1: Write the failing tests** — `site/src/lib/games.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { dayLabel, filtersToSearch, fmtPts, gameIdFromHash, initialView, matchesFilters, parseFilters } from './games';

describe('filters', () => {
  it('round-trips through the query string', () => {
    const f = parseFilters('?player=seezov&host=%D0%A8%D0%BF%D0%B0%D0%BA');
    expect(f).toEqual({ player: 'seezov', host: 'Шпак' });
    expect(parseFilters(filtersToSearch(f))).toEqual(f);
    expect(filtersToSearch({ player: null, host: null })).toBe('');
  });
  it('matches by slug, by host, by both', () => {
    expect(matchesFilters(['seezov', 'nimfa'], 'Шпак', { player: 'seezov', host: null })).toBe(true);
    expect(matchesFilters(['seezov'], 'Шпак', { player: null, host: 'Rathma' })).toBe(false);
    expect(matchesFilters(['seezov'], undefined, { player: null, host: null })).toBe(true);
  });
  it('matches by name when the player has no slug', () => {
    expect(matchesFilters(['Гість Петро'], 'Шпак', { player: 'Гість Петро', host: null })).toBe(true);
  });
});

describe('deep links', () => {
  it('reads a game id from the hash', () => {
    expect(gameIdFromHash('#g-2026-09-01-1-3')).toBe('g-2026-09-01-1-3');
    expect(gameIdFromHash('#g-x-0')).toBe('g-x-0');
    expect(gameIdFromHash('#top')).toBeNull();
    expect(gameIdFromHash('')).toBeNull();
  });
  it('initialView clears filters that hide the target', () => {
    const f = { player: 'seezov', host: null };
    expect(initialView('#g-x-0', f, () => false)).toEqual({ open: 'g-x-0', filters: { player: null, host: null } });
    expect(initialView('#g-x-0', f, () => true)).toEqual({ open: 'g-x-0', filters: f });
    expect(initialView('', f, () => false)).toEqual({ open: null, filters: f });
  });
});

describe('format', () => {
  it('drops trailing zeros and uses a real minus', () => {
    expect(fmtPts(0.3)).toBe('0.3');
    expect(fmtPts(1)).toBe('1');
    expect(fmtPts(-0.5)).toBe('−0.5');
    expect(fmtPts(1.25)).toBe('1.25');
    expect(fmtPts(undefined)).toBe('');
  });
  it('labels a day', () => {
    expect(dayLabel('2026-09-01')).toBe('Tue, 1 Sep 2026');
    expect(dayLabel(null)).toBe('No date');
  });
});
```

- [ ] **Step 2: Run — expect failure** (module missing)

Run: `cd site && npx vitest run src/lib/games.test.ts`

- [ ] **Step 3: Implement** — `site/src/lib/games.ts`:

```ts
export interface GameFilters { player: string | null; host: string | null }

export function parseFilters(search: string): GameFilters {
  const q = new URLSearchParams(search);
  return { player: q.get('player') || null, host: q.get('host') || null };
}

export function filtersToSearch(f: GameFilters): string {
  const q = new URLSearchParams();
  if (f.player) q.set('player', f.player);
  if (f.host) q.set('host', f.host);
  const s = q.toString();
  return s ? `?${s}` : '';
}

/** [keys] are the game's player keys (slug, or name for players without a page). */
export const matchesFilters = (keys: string[], host: string | undefined, f: GameFilters) =>
  (!f.player || keys.includes(f.player)) && (!f.host || host === f.host);

export function gameIdFromHash(hash: string): string | null {
  const id = decodeURIComponent(hash.replace(/^#/, ''));
  return /^g-[\w-]+$/.test(id) ? id : null;
}

/** What to show first: the linked game wins over a filter that would hide it. */
export function initialView(hash: string, filters: GameFilters, gameMatches: (id: string, f: GameFilters) => boolean) {
  const open = gameIdFromHash(hash);
  if (open && !gameMatches(open, filters)) return { open, filters: { player: null, host: null } };
  return { open, filters };
}

export function fmtPts(v: number | undefined): string {
  if (v === undefined) return '';
  const s = String(Math.round(v * 100) / 100);
  return s.startsWith('-') ? `−${s.slice(1)}` : s;
}

const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
export function dayLabel(date: string | null): string {
  if (!date) return 'No date';
  const [y, m, d] = date.split('-').map(Number);
  const wd = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return `${days[wd]}, ${d} ${months[m - 1]} ${y}`;
}
```

Append the interfaces from **Interfaces** to `site/src/lib/types.ts`. In `data.ts` add `GamesData` to the type import and:

```ts
export const loadGames = (id: number) => read<GamesData>(`games/${id}.json`);
```

In `url.ts`:

```ts
export const gamesHref = (id: number, player?: string) =>
  href(`season/${id}/games/${player ? `?player=${encodeURIComponent(player)}` : ''}`);
```

- [ ] **Step 4: Run tests**

Run: `cd site && npm test`
Expected: PASS (all suites).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/games.ts site/src/lib/games.test.ts site/src/lib/types.ts site/src/lib/data.ts site/src/lib/url.ts
git commit -m "feat(site): games data types and filter/link helpers"
```

---

### Task 6: The `/season/N/games/` page

**Files:**
- Create: `site/src/components/SeasonHead.astro`, `site/src/components/GameCard.astro`, `site/src/pages/season/[id]/games/index.astro`, `site/src/scripts/games.ts`
- Modify: `site/src/components/SeasonPage.astro` (pagehead → `SeasonHead`)

**Interfaces:**
- Consumes: `loadGames`, `GamesData`, `GameEntry` (Task 5), `fmtPts`, `dayLabel`, `parseFilters`, `filtersToSearch`, `matchesFilters`, `initialView`, `gamesHref`, `seasonHref`, `playerHref`, `PlayerName.astro` (existing — check its props before use).
- Produces: `SeasonHead` props `{ id: number; tab: 'main' | 'small' | 'games' }`.

- [ ] **Step 1: Extract `SeasonHead.astro`** — move the `<div class="pagehead">…</div>` block and its `.picker`/`.pills` styles out of `SeasonPage.astro`, and add a third pill. The picker links keep the current tab:

```astro
---
import { loadIndex, loadSeason } from '../lib/data';
import { gamesHref, seasonHref } from '../lib/url';

interface Props { id: number; tab: 'main' | 'small' | 'games' }
const { id, tab } = Astro.props;
const season = loadSeason(id);
const seasons = [...loadIndex().seasons].reverse();
const link = (sid: number) => (tab === 'games' ? gamesHref(sid) : seasonHref(sid, tab === 'small'));
---
<div class="pagehead">
  <details class="picker">
    <summary class="display">{season.title} <span aria-hidden="true">▾</span></summary>
    <ul>
      {seasons.map((x) => <li><a href={link(x.id)} aria-current={x.id === id ? 'page' : undefined}>{x.title}</a></li>)}
    </ul>
  </details>
  <nav class="pills" aria-label="Section">
    <a class="pill" href={seasonHref(id)} aria-current={tab === 'main' ? 'true' : undefined}>Main league</a>
    <a class="pill" href={seasonHref(id, true)} aria-current={tab === 'small' ? 'true' : undefined}>Small league</a>
    <a class="pill" href={gamesHref(id)} aria-current={tab === 'games' ? 'true' : undefined}>Games</a>
  </nav>
  <slot />
</div>
```

(plus the moved `<style>` rules). In `SeasonPage.astro` replace the block with `<SeasonHead id={id} tab={small ? 'small' : 'main'}>{…tournament pills…}</SeasonHead>`.

Run: `cd site && npm run build` — expected: PASS, season pages look unchanged apart from the new pill.

- [ ] **Step 2: `GameCard.astro`**

```astro
---
import PlayerName from './PlayerName.astro';
import type { GameEntry, ColorGuess } from '../lib/types';
import { fmtPts } from '../lib/games';
import { playerHref } from '../lib/url';

interface Props { game: GameEntry; autoLabel: string; seasonId: number }
const { game: g, autoLabel } = Astro.props;
const roleLabel: Record<string, string> = { civilian: 'Civilian', sheriff: 'Sheriff', mafia: 'Mafia', don: 'Don' };
const result = { city: 'City', mafia: 'Mafia', unrated: 'Unrated' }[g.result];
const cols = [
  { k: 'fouls', label: 'Fouls', tip: 'Фоли' },
  { k: 'won', label: 'Win', tip: 'Бал: 1 for a win' },
  { k: 'add', label: 'Add.', tip: 'Доп — additional points from the host' },
  { k: 'ad', label: 'Auto', tip: 'АД — automatic additional points' },
  { k: 'bm', label: 'Best move', tip: `${autoLabel} — points of the first killed` },
  { k: 'pen', label: 'Penalty', tip: 'Штраф' },
  { k: 'prAdd', label: 'Prot. +', tip: 'ПрДод — protocol bonus' },
  { k: 'prPen', label: 'Prot. −', tip: 'ПрШтраф — protocol penalty' },
] as const;
const shown = cols.filter((c) => g.seats.some((s) => s[c.k] !== undefined));
const cell = (s: GameEntry['seats'][number], k: (typeof cols)[number]['k']) =>
  k === 'won' ? (s.won ? '1' : '') : k === 'fouls' ? (s.fouls ? String(s.fouls) : '') : fmtPts(s[k]);
const seatName = (n: number) => g.seats[n - 1]?.player ?? '—';
const guesses = (cs: ColorGuess[]) => cs.map((c) => `${c.seat}${c.black ? '●' : '○'}`).join(' ');
const keys = g.seats.map((s) => s.key).filter(Boolean).join('|');
---
<details class="game" id={g.id} data-keys={keys} data-host={g.host ?? ''}>
  <summary>
    <span class="num">#{g.n}</span>
    <span class="host">{g.host ?? '—'}</span>
    <span class={`res ${g.result}`}>{result}</span>
    {g.label && <span class="label">{g.label}</span>}
    {g.seats.filter((s) => s.key).map((s) => (
      <span class="pick" data-k={s.key} hidden>{roleLabel[s.role] ?? s.role} · {fmtPts(s.total) || '0'}</span>
    ))}
  </summary>
  <div class="body">
    <div class="scroll">
      <table>
        <thead><tr>
          <th>#</th><th>Player</th><th>Role</th>
          {shown.map((c) => <th title={c.tip}>{c.label}</th>)}
          <th title="Sum of the columns (no СІ top-up)">Total</th>
        </tr></thead>
        <tbody>
          {g.seats.map((s) => (
            <tr>
              <td>{s.n}</td>
              <td>{s.player ? (s.slug ? <a href={playerHref(s.slug)}><PlayerName name={s.player} /></a> : s.player) : '—'}</td>
              <td class={`role ${s.role}`}>{roleLabel[s.role] ?? s.role}</td>
              {shown.map((c) => <td class="num">{cell(s, c.k)}</td>)}
              <td class="num total">{fmtPts(s.total)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
    {g.firstKilled && <p><b>First killed:</b> {g.firstKilled} · {seatName(g.firstKilled)}
      {g.bestMove && <> · <b>Best move:</b> {g.bestMove.join(', ')}</>}
      {g.supportFive && <> · <b>Support 5:</b> {guesses(g.supportFive)}</>}
      {g.bestMovePoints !== undefined && <> ({fmtPts(g.bestMovePoints)})</>}</p>}
    {g.protocol && (
      <div><b>Protocol</b>
        <ol>{g.protocol.map((p) => (
          <li>{p.killed} · {seatName(p.killed)}{p.version && <> — sheriff {p.version}</>}{p.colors.length > 0 && <> — {guesses(p.colors)}</>}</li>
        ))}</ol>
      </div>
    )}
    {g.comments && (
      <ul class="comments">{g.comments.map((c) => (
        <li>{c.seats.length > 0 && <b>{c.seats.join(', ')} — </b>}<span>{c.text}</span></li>
      ))}</ul>
    )}
    <button type="button" class="copy" data-id={g.id}>Copy link</button>
  </div>
</details>

<style>
  .game { border-bottom: 1px solid var(--border); }
  .game summary { display: flex; gap: 12px; align-items: baseline; padding: 8px 0; cursor: pointer; flex-wrap: wrap; }
  .res.city { color: var(--city); } .res.mafia { color: var(--mafia); } .res.unrated { color: var(--muted); }
  .label, .pick { color: var(--muted); font-size: .9em; }
  .scroll { overflow-x: auto; }
  table { border-collapse: collapse; min-width: 100%; }
  th, td { padding: 4px 8px; text-align: left; white-space: nowrap; }
  td.num { text-align: right; font-variant-numeric: tabular-nums; }
  .role.civilian { color: var(--civilian); } .role.sheriff { color: var(--sheriff); }
  .role.mafia { color: var(--mafia); } .role.don { color: var(--don); }
  .comments span { white-space: pre-line; }
  .body { padding: 0 0 12px; }
</style>
```

Check `PlayerName.astro`'s props first and pass what it expects.

- [ ] **Step 3: The page and the script.** `site/src/pages/season/[id]/games/index.astro`:

```astro
---
import Base from '../../../../layouts/Base.astro';
import GameCard from '../../../../components/GameCard.astro';
import SeasonHead from '../../../../components/SeasonHead.astro';
import { loadGames, loadIndex, loadSeason } from '../../../../lib/data';
import { dayLabel } from '../../../../lib/games';

export function getStaticPaths() {
  return loadIndex().seasons.map((s) => ({ params: { id: String(s.id) } }));
}
const id = Number(Astro.params.id);
const season = loadSeason(id);
const data = loadGames(id);
const total = data.days.reduce((n, d) => n + d.games.length, 0);
const tables = (games: typeof data.days[number]['games']) =>
  [...new Set(games.map((g) => g.table ?? 0))].map((t) => ({ t, games: games.filter((g) => (g.table ?? 0) === t) }));
---
<Base title={`${season.title} · Games`} description={`${season.title}: all ${total} games`} active="season">
  <SeasonHead id={id} tab="games" />
  <div class="toolbar">
    <input id="f-player" list="players" placeholder="Player" autocomplete="off" />
    <datalist id="players">{data.players.map((p) => <option value={p.name} data-key={p.key} />)}</datalist>
    <select id="f-host"><option value="">All hosts</option>{data.hosts.map((h) => <option>{h}</option>)}</select>
    <span id="count" class="label">{total} games</span>
  </div>
  {data.days.map((d) => (
    <section class="day">
      <h2 class="label">{dayLabel(d.date)} · {d.games.length} {d.games.length === 1 ? 'game' : 'games'}</h2>
      {tables(d.games).map(({ t, games }) => (
        <div class="table-group">
          {t > 0 && tables(d.games).length > 1 && <h3 class="label">Table {t}</h3>}
          {games.map((g) => <GameCard game={g} autoLabel={data.autoLabel} seasonId={id} />)}
        </div>
      ))}
    </section>
  ))}
  <script type="application/json" id="games-players" set:html={JSON.stringify(data.players)} />
</Base>

<script>
  import '../../../../scripts/games';
</script>

<style>
  .toolbar { display: flex; gap: 12px; flex-wrap: wrap; margin: 16px 0; align-items: center; }
  .day h2 { margin: 24px 0 4px; }
</style>
```

(`set:html` here carries JSON built from player names; `JSON.stringify` output inside a `<script type="application/json">` is safe except for `</script>` — replace `<` with `<`: `JSON.stringify(data.players).replace(/</g, '\\u003c')`.)

`site/src/scripts/games.ts`:

```ts
import { filtersToSearch, initialView, matchesFilters, parseFilters, type GameFilters } from '../lib/games';

const players: { name: string; key: string }[] = JSON.parse(document.getElementById('games-players')!.textContent!);
const games = [...document.querySelectorAll<HTMLDetailsElement>('details.game')];
const input = document.getElementById('f-player') as HTMLInputElement;
const host = document.getElementById('f-host') as HTMLSelectElement;
const count = document.getElementById('count')!;

const keysOf = (g: HTMLElement) => (g.dataset.keys ?? '').split('|').filter(Boolean);
const matches = (g: HTMLElement, f: GameFilters) => matchesFilters(keysOf(g), g.dataset.host || undefined, f);

function apply(f: GameFilters) {
  let shown = 0;
  for (const g of games) {
    const ok = matches(g, f);
    g.hidden = !ok;
    if (ok) shown++;
    for (const p of g.querySelectorAll<HTMLElement>('.pick')) p.hidden = p.dataset.k !== f.player;
  }
  for (const group of document.querySelectorAll<HTMLElement>('.table-group, .day')) {
    group.hidden = !group.querySelector('details.game:not([hidden])');
  }
  count.textContent = `${shown} ${shown === 1 ? 'game' : 'games'}`;
  input.value = players.find((p) => p.key === f.player)?.name ?? '';
  host.value = f.host ?? '';
}

function current(): GameFilters {
  const p = players.find((x) => x.name.toLowerCase() === input.value.trim().toLowerCase());
  return { player: p?.key ?? null, host: host.value || null };
}

function update() {
  const f = current();
  history.replaceState(null, '', filtersToSearch(f) + location.hash);
  apply(f);
}

input.addEventListener('change', update);
host.addEventListener('change', update);

const view = initialView(location.hash, parseFilters(location.search), (id, f) => {
  const g = document.getElementById(id);
  return !!g && matches(g, f);
});
apply(view.filters);
if (view.open) {
  const g = document.getElementById(view.open) as HTMLDetailsElement | null;
  if (g) { g.open = true; g.scrollIntoView({ block: 'start' }); }
  history.replaceState(null, '', filtersToSearch(view.filters) + location.hash);
}

document.addEventListener('click', async (e) => {
  const b = (e.target as HTMLElement).closest<HTMLButtonElement>('button.copy');
  if (!b) return;
  const url = `${location.origin}${location.pathname}#${b.dataset.id}`;
  try { await navigator.clipboard.writeText(url); b.textContent = 'Copied'; } catch { location.hash = b.dataset.id!; }
  setTimeout(() => (b.textContent = 'Copy link'), 1500);
});
```

- [ ] **Step 4: Build and check**

Run: `cd site && npm test && npm run build && ls dist/season/31/games/index.html && du -h dist/season/26/games/index.html && grep -c 'class="game"' dist/season/31/games/index.html`
Expected: PASS; the S26 page is ≲ 2 MB; the S31 count equals the number of games in `data/games/31.json`. Also: `grep -c 'set:html\|innerHTML' src/components/GameCard.astro` → `0`.

- [ ] **Step 5: Look at it.** `npm run preview`, open `/FamilyMafiaApp/season/5/games/`, `/season/22/games/`, `/season/31/games/` at desktop and 375 px width: no horizontal page scroll, a card opens, comments show seat numbers and line breaks, `?player=<slug>` filters and shows role · total in rows, `#<id>` with a non-matching `?player=` opens the game and clears the filter, Copy link works. Stop the preview server afterwards.

- [ ] **Step 6: Commit**

```bash
git add site/src/components/SeasonHead.astro site/src/components/SeasonPage.astro site/src/components/GameCard.astro "site/src/pages/season/[id]/games/index.astro" site/src/scripts/games.ts
git commit -m "feat(site): /season/N/games/ — every game with its card, filters and deep links"
```

---

### Task 7: Profile → games links, docs, branch sync

**Files:**
- Modify: `site/src/components/GamesBySeasonChart.astro`, `site/src/pages/players/[slug].astro:47`
- Modify: `CLAUDE.md` (Web site section)

**Interfaces:**
- Consumes: `gamesHref(id, player)` (Task 5).
- Produces: `GamesBySeasonChart` props `{ timeline; slug: string }`.

- [ ] **Step 1: Link the chart points.** In `GamesBySeasonChart.astro` add `slug: string` to `Props`, import `gamesHref` from `../lib/url`, and wrap each played circle:

```astro
  {played.map((t) => (
    <a href={gamesHref(t.seasonId, slug)} aria-label={`${t.title}: ${t.games} games`}>
      <circle cx={x(t.i)} cy={y(t.games)} r="5" fill="var(--bg)" stroke="var(--text)" stroke-width="2">
        <title>{`${t.title}: ${t.games} games — open the games`}</title>
      </circle>
    </a>
  ))}
```

and in `players/[slug].astro`: `<GamesBySeasonChart timeline={p.timeline} slug={p.slug} />` (use the slug field the page already has — check `PlayerData`).

- [ ] **Step 2: Build** — `check-dist` validates every `href`, query string stripped:

Run: `cd site && npm run build`
Expected: PASS, `check-dist: … all links resolve`.

- [ ] **Step 3: Docs.** In `CLAUDE.md` → Web site, add a bullet:

```markdown
- **Game browser:** `/season/N/games/` shows every parsed game (rating and non-rating) from
  `site/data/games/N.json` (`lib/site_export/games_export.dart`; `browserGames` re-parses each
  season's JSON — the repositories hold rating games only). Host comments, event labels and
  «Стіл N» come from the raw sheet rows via `lib/services/sheet_game_extras.dart`; if a season's
  anchors don't match its games the extras are dropped (alignment test names the season).
```

- [ ] **Step 4: Full verification**

Run: `flutter analyze && flutter test && cd site && npm test && npm run build`
Expected: all green.

- [ ] **Step 5: Commit, sync master**

```bash
git add site/src/components/GamesBySeasonChart.astro "site/src/pages/players/[slug].astro" CLAUDE.md
git commit -m "feat(site): link profile seasons to the player's games"
git checkout master && git merge --ff-only feature/flutter_migration && git checkout feature/flutter_migration
```

(Push both branches only when the user asks.)
