# Stats Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add host/date parsing, tournaments, a Season Stats card, a sortable seasons table on the dashboard, a Records tab, and a Leagues section in the player profile.

**Architecture:** The parser gains `host` and `date` on `Game`. Every new number comes from pure, Flutter-free functions in a new `lib/services/stats/` folder: they take games, ratings, configs and players and return plain result objects, and they are unit-tested directly. Riverpod providers next to each screen call those functions. The UI reuses the award badge and ranking widgets and adds one generic `SortableTable` widget, which both the dashboard table and the Records tab use.

**Tech Stack:** Flutter, Dart 3, flutter_riverpod (StateProvider/Provider), freezed (+ build_runner), flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-24-stats-expansion-design.md`

## Global Constraints

- Non-rating games never count anywhere. They are already dropped at load (`isolate_functions.dart`, `.where((g) => g.isRatingGame())`), so no stat shows a non-rating share.
- Hosts are merged with players through the same `players.json` mapping (displayName or nickname → `Player`).
- "ПУ %" = first-killed count / the player's red games (civilian + sheriff). `RatingPlayerStats.percentOfDeath` already holds exactly this.
- Host plus per game = the sum of the positive values in the доп column. Seasons 2–3 read ЛИ from that same column. АД, ОП, protocol points and "Бал ведучого" are never counted.
- Host/player minus per game, by season range:
  - seasons 2–3: −1 per 4-foul player (already stored in `penaltyPoints`);
  - seasons 4–20: negative доп values except exactly −2 (disqualification);
  - seasons 21+: the Штраф column (`penaltyPoints`).
- Points periods for all-time records: `li` = seasons 2–3 and `modern` = seasons 4+. Seasons 0–1 never appear in points tables.
- Averages for hosts require at least **20** hosted games (`kHostMinGamesForAverage = 20`).
- The Season Stats card shows the **top 4** (`kAwardRankingSize`). The Records tab shows the **top 10** plus "Show all".
- Records use the main league only (`gamesPlayed >= config.gameLimit`). Exceptions: "All time" games, "All time" hosts and win streaks.
- Win streaks run across seasons, in order of season and then game order within the season. A loss breaks the streak.
- UI copy is English, matching the rest of the app.
- Tournament types: `minicap`, `maxicap`, `marathon`, `tournament`.

## Review Focus

- **Partial load.** While only the latest season is loaded (`LoadingPhase.latestLoaded`), the dashboard table, Records and Leagues must render the seasons that are present without throwing. A test in Task 8 passes a single season.
- **Seasons 0–1 have no host.** The host badges show "No data" rather than "0 games". `gamesWithoutHost` returns `null` when no game in the set has host data (test in Task 4).
- **Nickname merging.** The same person spelled differently (displayName vs nickname) must merge in all-time hosts and in streaks. Tests in Task 4 and Task 7.
- **Ties.** Equal values order by name ascending, so results are stable between runs. Tests in Task 4 and Task 8.
- **Players with no red games.** They are excluded from Top ПУ % with no division by zero. Test in Task 5.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/models/game.dart` (modify) | + `host`, `date` fields |
| `lib/services/src/game_parsing.dart` (modify) | parse host/date |
| `lib/services/season_loader.dart` (modify) | `@visibleForTesting parseSeasonGamesForTest` |
| `lib/services/stats/game_points.dart` | `GamePoints` extension: slot plus/minus, host plus/minus |
| `lib/services/stats/points_period.dart` | `PointsPeriod` enum |
| `lib/services/stats/player_resolver.dart` | raw name → canonical `Player`, `personKey` |
| `lib/services/stats/host_stats.dart` | host aggregates |
| `lib/services/stats/season_extra_stats.dart` | Season Stats card data |
| `lib/services/stats/win_streaks.dart` | cross-season streaks |
| `lib/services/stats/records.dart` | Records tables data |
| `lib/services/stats/season_rows.dart` | dashboard seasons table rows |
| `lib/services/stats/player_leagues.dart` | league per season for a player |
| `lib/models/tournament.dart` | `Tournament`, `TournamentType` |
| `lib/providers/app_providers.dart` (modify) | tournaments in parsed config, `tournamentsProvider`, `selectedTabProvider` |
| `assets/raw/season_config.json`, `remote_config.json` (modify) | top-level `tournaments` |
| `lib/widgets/hero_card.dart` (modify) | optional second tile row |
| `lib/widgets/sortable_table.dart` | generic sticky-first-column sortable table |
| `lib/screens/home/home_providers.dart` (modify) | players-count fix, league counts, extra stats provider |
| `lib/screens/home/src/season_header_card.dart` (modify) | generic badge/ranking, hero second row |
| `lib/screens/home/src/season_stats_card.dart` | Season Stats card |
| `lib/screens/dashboard/dashboard_providers.dart` (modify) | overview players fix, `seasonRowsProvider` |
| `lib/screens/dashboard/seasons_table.dart` | dashboard card + full-screen table |
| `lib/screens/records/records_providers.dart`, `records_screen.dart` | Records tab |
| `lib/main.dart` (modify) | Records tab, `selectedTabProvider` |
| `lib/screens/players/src/leagues_section.dart` | Leagues section |
| `lib/screens/players/players_providers.dart` (modify) | `playerLeaguesProvider` |

Run all commands from `C:\Users\user\AndroidStudioProjects\FamilyMafiaApp`.

---

### Task 1: Parse host and date

**Files:**
- Modify: `lib/models/game.dart` (factory fields)
- Modify: `lib/services/src/game_parsing.dart` (`_buildGame`, new helpers)
- Modify: `lib/services/season_loader.dart` (test hook)
- Regenerate: `lib/models/game.freezed.dart`
- Test: `test/services/game_parsing_host_test.dart`

**Interfaces:**
- Produces: `Game.host` (`String?`, trimmed, null when blank), `Game.date` (`DateTime?`, UTC midnight of the game day), `parseSeasonGamesForTest(int seasonId, List<Map<String, dynamic>> raw) → List<Game>` (all games, including non-rating ones).

- [ ] **Step 1: Write the failing test**

```dart
// test/services/game_parsing_host_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

List<Game> _season(int id) {
  final raw = (jsonDecode(File('assets/raw/season$id.json').readAsStringSync())
          as List)
      .cast<Map<String, dynamic>>();
  return parseSeasonGamesForTest(id, raw);
}

void main() {
  test('seasons 0-1 have no host or date', () {
    final g = _season(0).first;
    expect(g.host, isNull);
    expect(g.date, isNull);
  });

  test('season 2 reads host from slot 9 and date from slot 10', () {
    final g = _season(2).first;
    expect(g.host, 'Рауль');
    expect(g.date, DateTime.utc(2019, 3, 5));
  });

  test('season 16 ignores the host score next to the host name', () {
    final g = _season(16).first;
    expect(g.host, 'Скай');
    expect(g.date, DateTime.utc(2022, 12, 1));
  });

  test('season 20 reads host from the game header row', () {
    final g = _season(20).first;
    expect(g.host, 'Малишка');
    expect(g.date, DateTime.utc(2023, 3, 12));
  });

  test('most season 16 games have a host', () {
    final games = _season(16).where((g) => g.isRatingGame()).toList();
    final withHost = games.where((g) => g.host != null).length;
    expect(withHost / games.length, greaterThan(0.9));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/game_parsing_host_test.dart`
Expected: FAIL to compile. `parseSeasonGamesForTest` is not defined and `host` is not a getter of `Game`.

- [ ] **Step 3: Add the fields to `Game`**

In `lib/models/game.dart`, add inside `const factory Game({ ... })` after `supportFive`:

```dart
    String? host, // who hosted (ведучий); null for seasons 0-1 or when blank
    DateTime? date, // game day (UTC midnight); null when unknown
```

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `game.freezed.dart` regenerated with no errors.

- [ ] **Step 4: Parse host and date**

In `lib/services/src/game_parsing.dart`, add these helpers at the bottom:

```dart
const _hostLabels = {'Ведущий', 'Ведучий'};

String? _parseHost(String s) {
  final v = s.trim();
  if (v.isEmpty || _hostLabels.contains(v)) return null;
  return v;
}

/// Sheet dates arrive as an ISO timestamp (local midnight exported as UTC,
/// e.g. 2019-03-04T22:00:00.000Z), a plain `YYYY-MM-DD`, `M/D/YYYY`, or a
/// Sheets serial day number. Returns UTC midnight of the game day.
DateTime? _parseSheetDate(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final serial = int.tryParse(v);
  if (serial != null) {
    final d = DateTime.utc(1899, 12, 30).add(Duration(days: serial));
    return DateTime.utc(d.year, d.month, d.day);
  }
  if (v.contains('/')) {
    final parts = v.split('/');
    if (parts.length != 3) return null;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (m == null || d == null || y == null) return null;
    return DateTime.utc(y, m, d);
  }
  final parsed = DateTime.tryParse(v);
  if (parsed == null) return null;
  // Shift by 12h so a local-midnight timestamp lands on the right day.
  final shifted = v.contains('T') ? parsed.toUtc().add(const Duration(hours: 12)) : parsed;
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}
```

In the `seasonId <= kMidFormatMaxSeason` branch and the `seasonId <= kLegacyMaxSeason` branch, add these two arguments to the `Game(...)` constructor (slot 9 = `p[8]`, slot 10 = `p[9]`):

```dart
      host: _parseHost(p[8].c),
      date: p[9].b.trim() == 'Дата' ? _parseSheetDate(p[9].c) : null,
```

In both season 17+ `Game(...)` constructors (the `kPreProtocolMaxSeason` one and the 29+ one), add:

```dart
      host: _hostLabels.contains(p[0].c.trim()) ? _parseHost(p[0].d) : null,
      date: p[0].a.trim() == 'Дата' ? _parseSheetDate(p[0].b) : null,
```

- [ ] **Step 5: Add the test hook**

In `lib/services/season_loader.dart`, after the `part` lines, add:

```dart
/// Parses one season's raw JSON rows into games, including non-rating ones.
@visibleForTesting
List<Game> parseSeasonGamesForTest(
        int seasonId, List<Map<String, dynamic>> raw) =>
    _getGamesDataSeason(
      seasonId,
      raw
          .map(GamesDataSeason.fromJson)
          .where((d) => _filterRawData(d, seasonId))
          .toList(),
    );
```

(`package:flutter/foundation.dart` is already imported there and provides `visibleForTesting`.)

- [ ] **Step 6: Run the tests**

Run: `flutter test test/services/game_parsing_host_test.dart`
Expected: PASS (5 tests). If the season 2 date is off by one day, check the +12h shift. If the season 16 host is `-0.4`, the column is wrong: it must be `c`, not `b`.

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/models/game.dart lib/models/game.freezed.dart lib/services/src/game_parsing.dart lib/services/season_loader.dart test/services/game_parsing_host_test.dart
git commit -m "feat: parse host and date for every game"
```

---

### Task 2: Game points helpers and periods

**Files:**
- Create: `lib/services/stats/game_points.dart`
- Create: `lib/services/stats/points_period.dart`
- Test: `test/services/stats/game_points_test.dart`

**Interfaces:**
- Produces:
  - `extension GamePoints on Game`: `double slotPlus(int slot)`, `double slotMinus(int slot)`, `double get hostPlus`, `double get hostMinus`. Slots are 0-based indices into `players`. Minus values are ≤ 0.
  - `enum PointsPeriod { li, modern }`: `bool contains(int seasonId)` and `String get label` (`'Seasons 2–3'` / `'Seasons 4+'`).

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/game_points_test.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g({List<double>? add, List<double>? pen, List<double>? auto}) => Game(
      seasonId: 10,
      players: List.generate(10, (i) => 'p$i'),
      roles: List.filled(10, 'Мирный'),
      cityWon: true,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
      additionalPoints: add,
      penaltyPoints: pen,
      autoAdditionalPoints: auto,
    );

List<double> _row(Map<int, double> values) =>
    List.generate(10, (i) => values[i] ?? 0.0);

void main() {
  test('plus sums positive доп only', () {
    final g = _g(add: _row({0: 0.3, 1: 0.5, 2: -0.2}));
    expect(g.hostPlus, closeTo(0.8, 1e-9));
    expect(g.slotPlus(2), 0.0);
  });

  test('minus takes negative доп but skips the -2 disqualification', () {
    final g = _g(add: _row({0: -0.3, 1: -2.0}));
    expect(g.hostMinus, closeTo(-0.3, 1e-9));
    expect(g.slotMinus(1), 0.0);
  });

  test('minus adds the penalty column', () {
    final g = _g(add: _row({0: 0.4}), pen: _row({3: -0.5, 4: -1.0}));
    expect(g.hostMinus, closeTo(-1.5, 1e-9));
    expect(g.hostPlus, closeTo(0.4, 1e-9));
  });

  test('auto additional points are ignored', () {
    final g = _g(auto: _row({0: 0.3, 1: 0.3}));
    expect(g.hostPlus, 0.0);
  });

  test('games without point columns give zero', () {
    final g = _g();
    expect(g.hostPlus, 0.0);
    expect(g.hostMinus, 0.0);
  });

  test('periods split seasons 2-3 from 4+ and skip 0-1', () {
    expect(PointsPeriod.li.contains(2), isTrue);
    expect(PointsPeriod.li.contains(4), isFalse);
    expect(PointsPeriod.modern.contains(4), isTrue);
    expect(PointsPeriod.modern.contains(30), isTrue);
    expect(PointsPeriod.li.contains(1), isFalse);
    expect(PointsPeriod.modern.contains(0), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/game_points_test.dart`
Expected: FAIL. The imports do not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/points_period.dart

/// The two доп systems all-time records are split by. Seasons 0-1 had no
/// доп at all and belong to neither.
enum PointsPeriod {
  /// Seasons 2-3: the host picked ЛИ 1 (1 point) and up to two ЛИ 2 (0.5).
  li(2, 3, 'Seasons 2–3'),

  /// Seasons 4 onward: per-player доп from the host.
  modern(4, 1 << 30, 'Seasons 4+');

  const PointsPeriod(this.firstSeason, this.lastSeason, this.label);

  final int firstSeason;
  final int lastSeason;
  final String label;

  bool contains(int seasonId) =>
      seasonId >= firstSeason && seasonId <= lastSeason;
}
```

```dart
// lib/services/stats/game_points.dart
import 'dart:math';

import 'package:family_mafia_app/models/game.dart';

/// A доп of exactly -2 marks a disqualification (seasons 4-5), not a minus
/// the host handed out.
const kDisqualificationPoints = -2.0;

/// Points the host handed out in a game. ЛИ (2-3) and доп (4+) share the
/// `additionalPoints` column; minuses come from negative доп (4-20) and the
/// penalty column (4 fouls in 2-3, Штраф in 21+). АД, protocol points and the
/// host's own score are deliberately left out.
extension GamePoints on Game {
  double slotPlus(int slot) => max(additionalPoints?[slot] ?? 0.0, 0.0);

  double slotMinus(int slot) {
    var minus = 0.0;
    final add = additionalPoints?[slot] ?? 0.0;
    if (add < 0 && add != kDisqualificationPoints) minus += add;
    final pen = penaltyPoints?[slot] ?? 0.0;
    if (pen < 0) minus += pen;
    return minus;
  }

  double get hostPlus =>
      [for (var i = 0; i < players.length; i++) slotPlus(i)].fold(0.0, (a, b) => a + b);

  double get hostMinus =>
      [for (var i = 0; i < players.length; i++) slotMinus(i)].fold(0.0, (a, b) => a + b);
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/services/stats/game_points_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats/game_points.dart lib/services/stats/points_period.dart test/services/stats/game_points_test.dart
git commit -m "feat: host plus/minus per game and points periods"
```

---

### Task 3: Tournaments in config

**Files:**
- Create: `lib/models/tournament.dart`
- Modify: `lib/providers/app_providers.dart:47-59` (`_ParsedConfig`, `_parseConfig`), plus a new `tournamentsProvider`
- Modify: `assets/raw/season_config.json`, `remote_config.json` (top-level `"tournaments"`)
- Modify: `test/enums/season_test.dart` (drift check)
- Test: `test/models/tournament_test.dart`

**Interfaces:**
- Produces:
  - `enum TournamentType { minicap, maxicap, marathon, tournament }`, with `String get label` (`Minicap` / `Maxicap` / `Marathon` / `Tournament`), `Color get color` and `Color get lightColor`.
  - `class Tournament { int seasonId; TournamentType type; String name; int games; String? date; factory Tournament.fromJson(Map) }`.
  - `List<Tournament> parseTournaments(Map<String, dynamic> configJson)`, which returns an empty list when the key is missing.
  - `tournamentsProvider: Provider<List<Tournament>>`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/tournament_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a tournament entry', () {
    final t = Tournament.fromJson({
      'season': 27, 'type': 'minicap', 'name': 'Мінікап 30.09',
      'games': 4, 'date': '30.09.2025',
    });
    expect(t.seasonId, 27);
    expect(t.type, TournamentType.minicap);
    expect(t.games, 4);
  });

  test('missing key gives no tournaments', () {
    expect(parseTournaments({'seasons': []}), isEmpty);
  });

  test('bundled config lists the collected tournaments', () {
    final json = jsonDecode(
        File('assets/raw/season_config.json').readAsStringSync());
    final all = parseTournaments(json as Map<String, dynamic>);
    expect(all.where((t) => t.seasonId == 25 && t.type == TournamentType.minicap).length, 5);
    expect(all.where((t) => t.seasonId == 25 && t.type == TournamentType.maxicap).length, 3);
    expect(all.where((t) => t.seasonId == 30).single.name, 'Ліга №1');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/models/tournament_test.dart`
Expected: FAIL. `tournament.dart` does not exist.

- [ ] **Step 3: Implement the model**

```dart
// lib/models/tournament.dart
import 'package:flutter/material.dart';

enum TournamentType {
  minicap('Minicap', Color(0xFF1F7A6D), Color(0xFFE3F2EF)),
  maxicap('Maxicap', Color(0xFFB36B00), Color(0xFFFBEEDB)),
  marathon('Marathon', Color(0xFF4C55A8), Color(0xFFE7E8F6)),
  tournament('Tournament', Color(0xFF6F6A70), Color(0xFFEEECEE));

  const TournamentType(this.label, this.color, this.lightColor);

  final String label;
  final Color color;
  final Color lightColor;

  static TournamentType fromJson(String v) =>
      values.firstWhere((t) => t.name == v, orElse: () => tournament);
}

/// One tournament (minicap, maxicap, marathon or other) held during a season.
class Tournament {
  final int seasonId;
  final TournamentType type;
  final String name;
  final int games;

  /// Free-form day or range as written in the sheet, e.g. `16–17.12.2023`.
  final String? date;

  const Tournament({
    required this.seasonId,
    required this.type,
    required this.name,
    required this.games,
    this.date,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        seasonId: json['season'] as int,
        type: TournamentType.fromJson(json['type'] as String),
        name: json['name'] as String,
        games: json['games'] as int,
        date: json['date'] as String?,
      );
}

List<Tournament> parseTournaments(Map<String, dynamic> configJson) {
  final list = configJson['tournaments'] as List?;
  if (list == null) return const [];
  return list.cast<Map<String, dynamic>>().map(Tournament.fromJson).toList();
}
```

- [ ] **Step 4: Add the data to both config files**

In **both** `assets/raw/season_config.json` and `remote_config.json`, add a top-level key after `"seasons": [...]` (put a comma after the `seasons` array). The contents must be byte-identical in the two files:

```json
  "tournaments": [
    {"season": 0, "type": "tournament", "name": "Family Mafia Cup 2018", "games": 10},
    {"season": 1, "type": "tournament", "name": "Family Mafia Cup January", "games": 8},
    {"season": 3, "type": "tournament", "name": "Spring Cup 2019", "games": 8, "date": "13.07.2019"},
    {"season": 4, "type": "tournament", "name": "Summer Cup 2019", "games": 8, "date": "29.09.2019"},
    {"season": 4, "type": "tournament", "name": "Rookie of the Year 2019", "games": 8, "date": "24.11.2019"},
    {"season": 5, "type": "tournament", "name": "Royal Battle '19", "games": 15},
    {"season": 6, "type": "marathon", "name": "Mini Marathon 2020", "games": 6, "date": "01.03.2020"},
    {"season": 6, "type": "tournament", "name": "Raulchik 2020", "games": 8, "date": "04.07.2020"},
    {"season": 7, "type": "marathon", "name": "Sunday Mini Marathon 2020", "games": 7, "date": "03.10.2020"},
    {"season": 10, "type": "tournament", "name": "CheRog 2021", "games": 8, "date": "20.06.2021"},
    {"season": 12, "type": "marathon", "name": "Марафон 22.02 (CetusFamily)", "games": 8, "date": "22.02.2022"},
    {"season": 15, "type": "marathon", "name": "Mini Marathon 2022", "games": 5, "date": "11.09.2022"},
    {"season": 15, "type": "marathon", "name": "Марафон 30.10", "games": 7, "date": "30.10.2022"},
    {"season": 16, "type": "marathon", "name": "Марафон 18.12", "games": 8, "date": "18.12.2022"},
    {"season": 16, "type": "minicap", "name": "Фінал першого сезону мінікапів", "games": 8, "date": "05.02.2023"},
    {"season": 17, "type": "marathon", "name": "Marathon of wizards", "games": 8, "date": "19.03.2023"},
    {"season": 17, "type": "marathon", "name": "Sunday Marathon", "games": 8, "date": "14.05.2023"},
    {"season": 18, "type": "tournament", "name": "NoTail", "games": 8},
    {"season": 18, "type": "tournament", "name": "Alligators", "games": 8},
    {"season": 18, "type": "tournament", "name": "Біг Смоук", "games": 10},
    {"season": 18, "type": "tournament", "name": "Вівторок", "games": 10},
    {"season": 18, "type": "tournament", "name": "Біг Тейсті", "games": 8},
    {"season": 19, "type": "tournament", "name": "Big Fish", "games": 8, "date": "12.09.2023"},
    {"season": 19, "type": "tournament", "name": "Big Brother", "games": 8, "date": "19.09.2023"},
    {"season": 19, "type": "tournament", "name": "Big Ben", "games": 8, "date": "26.09.2023"},
    {"season": 19, "type": "tournament", "name": "Big Family", "games": 8, "date": "03.10.2023"},
    {"season": 19, "type": "minicap", "name": "Мінікап 10.10", "games": 8, "date": "24.10.2023"},
    {"season": 19, "type": "marathon", "name": "Марафон класичний", "games": 12},
    {"season": 19, "type": "marathon", "name": "Чоловічий марафон", "games": 8},
    {"season": 19, "type": "marathon", "name": "Жіночий марафон", "games": 8},
    {"season": 19, "type": "tournament", "name": "Master Shifu", "games": 12},
    {"season": 19, "type": "tournament", "name": "Біг Сіті Лайф", "games": 8},
    {"season": 20, "type": "minicap", "name": "Мінікап 16.12.2023", "games": 6, "date": "16–17.12.2023"},
    {"season": 20, "type": "minicap", "name": "Мінікап 30.12.2023", "games": 6, "date": "30.12.2023–01.01.2024"},
    {"season": 20, "type": "minicap", "name": "Мінікап 09.01.2024", "games": 6, "date": "09–11.01.2024"},
    {"season": 20, "type": "tournament", "name": "Big Spell Mage", "games": 8, "date": "20.02.2024"},
    {"season": 20, "type": "marathon", "name": "Фінал марафонів", "games": 8, "date": "25.02.2024"},
    {"season": 20, "type": "minicap", "name": "Мінікап 27.02.2024", "games": 6, "date": "27–29.02.2024"},
    {"season": 20, "type": "minicap", "name": "Міні міні-кап", "games": 4, "date": "29.02.2024"},
    {"season": 20, "type": "tournament", "name": "FAS 2023", "games": 19, "date": "12.2023"},
    {"season": 21, "type": "minicap", "name": "Мінікап 26.03.2024", "games": 4, "date": "26.03.2024"},
    {"season": 21, "type": "minicap", "name": "Фінал мінікапів", "games": 9, "date": "31.03–02.04.2024"},
    {"season": 21, "type": "minicap", "name": "Мінікап 03.04.2024", "games": 4, "date": "02.04.2024"},
    {"season": 21, "type": "minicap", "name": "Мінікап 25.04.2024", "games": 5, "date": "25.04.2024"},
    {"season": 22, "type": "minicap", "name": "Мінікап 23.07.2024", "games": 4, "date": "23.07.2024"},
    {"season": 22, "type": "minicap", "name": "Мінікап 08.08.2024", "games": 5, "date": "08–10.08.2024"},
    {"season": 22, "type": "minicap", "name": "Мінікап 29.08.2024", "games": 5, "date": "29–31.08.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 05.09.2024", "games": 5, "date": "05–07.09.2024"},
    {"season": 23, "type": "marathon", "name": "Marathon 08.09", "games": 8, "date": "08.09.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 10.09.2024", "games": 5, "date": "10–12.09.2024"},
    {"season": 23, "type": "marathon", "name": "Marathon 15.09", "games": 8, "date": "15.09.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 24.09.2024", "games": 4, "date": "24.09.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 08.10.2024", "games": 4, "date": "08.10.2024"},
    {"season": 23, "type": "marathon", "name": "Marathon 13.10", "games": 8, "date": "13–15.10.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 05.11.2024", "games": 4, "date": "05.11.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 10.11.2024", "games": 5, "date": "10.11.2024"},
    {"season": 23, "type": "minicap", "name": "Мінікап 26.11.2024", "games": 5, "date": "26.11.2024"},
    {"season": 24, "type": "minicap", "name": "Мінікап 02.01.2025", "games": 4, "date": "02.01.2025"},
    {"season": 24, "type": "minicap", "name": "Мінікап 07.01.2025", "games": 4, "date": "07.01.2025"},
    {"season": 24, "type": "minicap", "name": "Мінікап 14.01.2025", "games": 4, "date": "14.01.2025"},
    {"season": 24, "type": "minicap", "name": "Мінікап 25.02.2025", "games": 5, "date": "25.02.2025"},
    {"season": 25, "type": "minicap", "name": "Мінікап 11.03", "games": 5, "date": "11.03.2025"},
    {"season": 25, "type": "maxicap", "name": "Максікап 18.03", "games": 8, "date": "18.03.2025"},
    {"season": 25, "type": "minicap", "name": "Мінікап 01.04", "games": 5, "date": "01.04.2025"},
    {"season": 25, "type": "minicap", "name": "Мінікап 08.04", "games": 4, "date": "08.04.2025"},
    {"season": 25, "type": "minicap", "name": "Мінікап 24.04", "games": 5, "date": "24.04.2025"},
    {"season": 25, "type": "minicap", "name": "Мінікап 03.05", "games": 5, "date": "03.05.2025"},
    {"season": 25, "type": "maxicap", "name": "Максікап 06.05", "games": 8, "date": "06.05.2025"},
    {"season": 25, "type": "maxicap", "name": "Максікап 20.05", "games": 8, "date": "20.05.2025"},
    {"season": 26, "type": "maxicap", "name": "Максікап 03.06", "games": 8, "date": "03.06.2025"},
    {"season": 26, "type": "maxicap", "name": "Максікап 24.06", "games": 8, "date": "24.06.2025"},
    {"season": 26, "type": "minicap", "name": "Мінікап 08.07", "games": 5, "date": "08.07.2025"},
    {"season": 26, "type": "minicap", "name": "Мінікап 05.08", "games": 4, "date": "05.08.2025"},
    {"season": 26, "type": "maxicap", "name": "Максікап 12.08", "games": 8, "date": "12.08.2025"},
    {"season": 27, "type": "marathon", "name": "Класичний марафон 1", "games": 8, "date": "07.09.2025"},
    {"season": 27, "type": "minicap", "name": "Мінікап 30.09", "games": 4, "date": "30.09.2025"},
    {"season": 27, "type": "minicap", "name": "Мінікап 02.10", "games": 4, "date": "02.10.2025"},
    {"season": 27, "type": "minicap", "name": "Фінал мінікапів", "games": 8, "date": "05.10.2025"},
    {"season": 27, "type": "minicap", "name": "Мінікап 04.11", "games": 4, "date": "04.11.2025"},
    {"season": 27, "type": "maxicap", "name": "Максікап 25.11", "games": 8, "date": "25.11.2025"},
    {"season": 28, "type": "minicap", "name": "Мінікап 02.12.2025", "games": 4, "date": "02.12.2025"},
    {"season": 28, "type": "marathon", "name": "Марафон 15.02", "games": 8, "date": "15.02.2026"},
    {"season": 29, "type": "marathon", "name": "Марафон 15.03", "games": 8, "date": "15.03.2026"},
    {"season": 29, "type": "minicap", "name": "Мінікап 26.03", "games": 4, "date": "26.03.2026"},
    {"season": 29, "type": "marathon", "name": "Марафон 26.04", "games": 8, "date": "26.04.2026"},
    {"season": 29, "type": "marathon", "name": "Марафон 30.05", "games": 8, "date": "30.05.2026"},
    {"season": 30, "type": "tournament", "name": "Ліга №1", "games": 16, "date": "06–14.07.2026"}
  ]
```

- [ ] **Step 5: Wire it into config parsing**

In `lib/providers/app_providers.dart`, replace `_ParsedConfig` and `_parseConfig` with:

```dart
class _ParsedConfig {
  final List<SeasonConfig> seasons;
  final List<Tournament> tournaments;

  const _ParsedConfig(this.seasons, [this.tournaments = const []]);
}

_ParsedConfig _parseConfig(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final seasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  return _ParsedConfig(
    seasons.map((e) => SeasonConfig.fromJson(e)).toList(),
    parseTournaments(map),
  );
}
```

Add `import 'package:family_mafia_app/models/tournament.dart';`. After `seasonConfigsProvider`, add:

```dart
/// Every tournament held in any season, from the season config JSON.
final tournamentsProvider = Provider<List<Tournament>>((ref) {
  return ref.watch(parsedConfigProvider).valueOrNull?.tournaments ?? const [];
});
```

- [ ] **Step 6: Guard against drift between the two files**

In `test/enums/season_test.dart`, add inside `main()` (it already lists both file paths at lines 12-13):

```dart
  test('both config files list the same tournaments', () {
    String tournamentsOf(String path) => jsonEncode(
        (jsonDecode(File(path).readAsStringSync()) as Map)['tournaments']);
    expect(tournamentsOf('remote_config.json'),
        tournamentsOf('assets/raw/season_config.json'));
  });
```

(Add `import 'dart:convert';` and `import 'dart:io';` if they are missing.)

- [ ] **Step 7: Run the tests**

Run: `flutter test test/models/tournament_test.dart test/enums/season_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/models/tournament.dart lib/providers/app_providers.dart assets/raw/season_config.json remote_config.json test/models/tournament_test.dart test/enums/season_test.dart
git commit -m "feat: tournaments per season in config"
```

Note for release: the live app reads `remote_config.json` from `feature/flutter_migration`. After merging, push that branch too.

---

### Task 4: Player resolver and host stats

**Files:**
- Create: `lib/services/stats/player_resolver.dart`
- Create: `lib/services/stats/host_stats.dart`
- Test: `test/services/stats/host_stats_test.dart`

**Interfaces:**
- Consumes: `GamePoints` (Task 2), `Game.host` (Task 1).
- Produces:
  - `class PlayerResolver { PlayerResolver(List<Player> players); Player resolve(String raw); }`. An unknown name resolves to `Player(id: -1, displayName: raw)`.
  - `String personKey(Player p)` returns `'id:<id>'`, or `'name:<displayName>'` when id is -1.
  - `const kHostMinGamesForAverage = 20;`
  - `class HostStat { final Player host; final int hosted; final double plus; final double minus; double get avgPlus; double get avgMinus; }`
  - `List<HostStat> hostStats(Iterable<Game> games, PlayerResolver resolver)`, sorted by hosted desc, then name asc.
  - `int? gamesWithoutHost(Iterable<Game> games)` returns `null` when no game in the set has any host (seasons 0–1).
  - `List<HostStat> rankHostsByAvgPlus(List<HostStat> s)` (desc) and `List<HostStat> rankHostsByAvgMinus(List<HostStat> s)` (most negative first). Both keep only hosts with `hosted >= kHostMinGamesForAverage`; ties go by name.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/host_stats_test.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(String? host, {double plus = 0, double minus = 0, int season = 10}) => Game(
      seasonId: season,
      players: List.generate(10, (i) => 'p$i'),
      roles: List.filled(10, 'Мирный'),
      cityWon: true,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
      host: host,
      additionalPoints: [plus, minus, ...List.filled(8, 0.0)],
    );

final _resolver = PlayerResolver(const [
  Player(id: 7, displayName: 'Seezov', nicknames: ['Сізов']),
]);

void main() {
  test('counts hosted games and merges nicknames', () {
    final stats = hostStats([_g('Seezov'), _g('Сізов'), _g('Луна')], _resolver);
    expect(stats.first.host.displayName, 'Seezov');
    expect(stats.first.hosted, 2);
    expect(stats.last.host.displayName, 'Луна');
  });

  test('averages plus and minus per hosted game', () {
    final stats = hostStats(
        [_g('A', plus: 1.0, minus: -0.2), _g('A', plus: 0.5)], _resolver);
    expect(stats.single.avgPlus, closeTo(0.75, 1e-9));
    expect(stats.single.avgMinus, closeTo(-0.1, 1e-9));
  });

  test('average rankings need 20 hosted games', () {
    final games = [
      for (var i = 0; i < 20; i++) _g('Many', plus: 0.2),
      for (var i = 0; i < 19; i++) _g('Few', plus: 2.0),
    ];
    final ranked = rankHostsByAvgPlus(hostStats(games, _resolver));
    expect(ranked.map((h) => h.host.displayName), ['Many']);
  });

  test('ties are ordered by name', () {
    final stats = hostStats([_g('B'), _g('A')], _resolver);
    expect(stats.map((h) => h.host.displayName), ['A', 'B']);
  });

  test('games without host: null when the season has no host data', () {
    expect(gamesWithoutHost([_g(null), _g(null)]), isNull);
    expect(gamesWithoutHost([_g('A'), _g(null)]), 1);
  });

  test('minus ranking puts the most negative first', () {
    final games = [
      for (var i = 0; i < 20; i++) _g('Soft', minus: -0.1),
      for (var i = 0; i < 20; i++) _g('Hard', minus: -0.5),
    ];
    final ranked = rankHostsByAvgMinus(hostStats(games, _resolver));
    expect(ranked.first.host.displayName, 'Hard');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/host_stats_test.dart`
Expected: FAIL. The imports do not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/player_resolver.dart
import 'package:family_mafia_app/models/player.dart';

/// Maps a raw sheet name to its canonical [Player] the same way the loader
/// does (`displayName` or any nickname), with a lookup table instead of a scan.
class PlayerResolver {
  PlayerResolver(List<Player> players) {
    for (final p in players) {
      _byName.putIfAbsent(p.displayName, () => p);
      for (final n in p.nicknames ?? const <String>[]) {
        _byName.putIfAbsent(n, () => p);
      }
    }
  }

  final _byName = <String, Player>{};

  Player resolve(String raw) =>
      _byName[raw] ?? Player(id: -1, displayName: raw);
}

/// Stable identity for grouping: the player id, or the raw name for players
/// missing from players.json.
String personKey(Player p) =>
    p.id >= 0 ? 'id:${p.id}' : 'name:${p.displayName}';
```

```dart
// lib/services/stats/host_stats.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// Hosts need this many games before their averages are ranked.
const kHostMinGamesForAverage = 20;

class HostStat {
  final Player host;
  final int hosted;

  /// Sum of plus / minus (≤ 0) handed out across [hosted] games.
  final double plus;
  final double minus;

  const HostStat({
    required this.host,
    required this.hosted,
    required this.plus,
    required this.minus,
  });

  double get avgPlus => hosted == 0 ? 0 : plus / hosted;
  double get avgMinus => hosted == 0 ? 0 : minus / hosted;
}

List<HostStat> hostStats(Iterable<Game> games, PlayerResolver resolver) {
  final acc = <String, (Player, int, double, double)>{};
  for (final g in games) {
    final raw = g.host;
    if (raw == null) continue;
    final host = resolver.resolve(raw);
    final key = personKey(host);
    final (p, n, plus, minus) = acc[key] ?? (host, 0, 0.0, 0.0);
    acc[key] = (p, n + 1, plus + g.hostPlus, minus + g.hostMinus);
  }
  final list = [
    for (final (p, n, plus, minus) in acc.values)
      HostStat(host: p, hosted: n, plus: plus, minus: minus),
  ];
  list.sort((a, b) {
    final c = b.hosted.compareTo(a.hosted);
    return c != 0 ? c : a.host.displayName.compareTo(b.host.displayName);
  });
  return list;
}

int? gamesWithoutHost(Iterable<Game> games) {
  if (!games.any((g) => g.host != null)) return null;
  return games.where((g) => g.host == null).length;
}

List<HostStat> _rankAvg(List<HostStat> stats, double Function(HostStat) v,
    {required bool descending}) {
  final eligible =
      stats.where((h) => h.hosted >= kHostMinGamesForAverage).toList();
  eligible.sort((a, b) {
    final c = descending ? v(b).compareTo(v(a)) : v(a).compareTo(v(b));
    return c != 0 ? c : a.host.displayName.compareTo(b.host.displayName);
  });
  return eligible;
}

List<HostStat> rankHostsByAvgPlus(List<HostStat> stats) =>
    _rankAvg(stats, (h) => h.avgPlus, descending: true);

List<HostStat> rankHostsByAvgMinus(List<HostStat> stats) =>
    _rankAvg(stats, (h) => h.avgMinus, descending: false);
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/services/stats/host_stats_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats/player_resolver.dart lib/services/stats/host_stats.dart test/services/stats/host_stats_test.dart
git commit -m "feat: host stats with nickname merging"
```

---

### Task 5: Season extra stats and the players-count fix

**Files:**
- Create: `lib/services/stats/season_extra_stats.dart`
- Modify: `lib/screens/home/home_providers.dart` (players count, new providers)
- Modify: `lib/screens/dashboard/dashboard_providers.dart:74-99` (players count)
- Test: `test/services/stats/season_extra_stats_test.dart`

**Interfaces:**
- Consumes: `hostStats`, `rankHostsByAvgPlus`, `rankHostsByAvgMinus`, `gamesWithoutHost`, `PlayerResolver` (Task 4), `Tournament` (Task 3).
- Produces:
  - `int redGames(RatingPlayerStats p)`, the civilian + sheriff games.
  - `class SeasonExtraStats { List<RatingPlayerStats> mostGames; List<RatingPlayerStats> topFirstKilledPct; List<HostStat> mostHosted; List<HostStat> hostAvgPlus; List<HostStat> hostAvgMinus; int? gamesWithoutHost; int seasonGames; Map<TournamentType, int> tournaments; }`. Every list is capped at `kAwardRankingSize` (4).
  - `SeasonExtraStats buildSeasonExtraStats({required List<RatingPlayerStats> leaguePlayers, required List<Game> seasonGames, required List<Tournament> seasonTournaments, required PlayerResolver resolver})`
  - `({int main, int small}) leagueCounts(List<RatingPlayerStats> all, SeasonConfig season)`
  - Providers in `home_providers.dart`: `seasonLeagueCountsProvider`, `seasonExtraStatsProvider`, `playerResolverProvider`.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/season_extra_stats_test.dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';
import 'package:flutter_test/flutter_test.dart';

RatingPlayerStats _p(int id, int games, {int killed = 0, int civ = 0, int sher = 0}) =>
    RatingPlayerStats(
      seasonId: 26,
      player: Player(id: id, displayName: 'P$id'),
      gamesPlayed: games,
      firstKilled: killed,
      percentOfDeath: (civ + sher) == 0 ? 0 : killed / (civ + sher),
      gamesForRole: [('Мирний', civ), ('Шериф', sher)],
    );

const _season = SeasonConfig(
  id: 26, title: 'Season 26', gameLimit: 40, smallLeagueMinGames: 15,
  gamesMultiplier: 0, source: BundledSource(jsonFile: 'x.json'),
);

void main() {
  final resolver = PlayerResolver(const []);

  test('most games ranks by games, top 4', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: [for (var i = 1; i <= 6; i++) _p(i, i * 10)],
      seasonGames: const [], seasonTournaments: const [], resolver: resolver,
    );
    expect(s.mostGames.map((p) => p.player.id), [6, 5, 4, 3]);
  });

  test('top ПУ % skips players without red games', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: [_p(1, 40, killed: 5, civ: 20), _p(2, 40, killed: 0)],
      seasonGames: const [], seasonTournaments: const [], resolver: resolver,
    );
    expect(s.topFirstKilledPct.map((p) => p.player.id), [1]);
  });

  test('tournaments are counted by type', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: const [], seasonGames: const [], resolver: resolver,
      seasonTournaments: const [
        Tournament(seasonId: 26, type: TournamentType.minicap, name: 'a', games: 4),
        Tournament(seasonId: 26, type: TournamentType.minicap, name: 'b', games: 5),
        Tournament(seasonId: 26, type: TournamentType.maxicap, name: 'c', games: 8),
      ],
    );
    expect(s.tournaments, {TournamentType.minicap: 2, TournamentType.maxicap: 1});
  });

  test('league counts use gameLimit and smallLeagueMinGames', () {
    final counts = leagueCounts([_p(1, 14), _p(2, 15), _p(3, 39), _p(4, 40)], _season);
    expect(counts, (main: 1, small: 2));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/season_extra_stats_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/season_extra_stats.dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// Same cap the season awards use: winner plus three runners-up.
const kSeasonStatsRankingSize = 4;

int redGames(RatingPlayerStats p) => p.gamesForRole
    .where((e) =>
        Role.civilian.sheetValues.contains(e.$1) ||
        Role.sheriff.sheetValues.contains(e.$1))
    .fold(0, (s, e) => s + e.$2);

class SeasonExtraStats {
  final List<RatingPlayerStats> mostGames;
  final List<RatingPlayerStats> topFirstKilledPct;
  final List<HostStat> mostHosted;
  final List<HostStat> hostAvgPlus;
  final List<HostStat> hostAvgMinus;

  /// Null when the season has no host data at all (seasons 0-1).
  final int? gamesWithoutHost;
  final int seasonGames;
  final Map<TournamentType, int> tournaments;

  const SeasonExtraStats({
    required this.mostGames,
    required this.topFirstKilledPct,
    required this.mostHosted,
    required this.hostAvgPlus,
    required this.hostAvgMinus,
    required this.gamesWithoutHost,
    required this.seasonGames,
    required this.tournaments,
  });
}

List<T> _top<T>(List<T> list, int Function(T, T) compare) =>
    ([...list]..sort(compare)).take(kSeasonStatsRankingSize).toList();

SeasonExtraStats buildSeasonExtraStats({
  required List<RatingPlayerStats> leaguePlayers,
  required List<Game> seasonGames,
  required List<Tournament> seasonTournaments,
  required PlayerResolver resolver,
}) {
  int byName(RatingPlayerStats a, RatingPlayerStats b) =>
      a.player.displayName.compareTo(b.player.displayName);

  final hosts = hostStats(seasonGames, resolver);
  final tournaments = <TournamentType, int>{};
  for (final t in seasonTournaments) {
    tournaments[t.type] = (tournaments[t.type] ?? 0) + 1;
  }

  return SeasonExtraStats(
    mostGames: _top(leaguePlayers, (a, b) {
      final c = b.gamesPlayed.compareTo(a.gamesPlayed);
      return c != 0 ? c : byName(a, b);
    }),
    topFirstKilledPct: _top(
      leaguePlayers.where((p) => redGames(p) > 0).toList(),
      (a, b) {
        final c = b.percentOfDeath.compareTo(a.percentOfDeath);
        return c != 0 ? c : byName(a, b);
      },
    ),
    mostHosted: hosts.take(kSeasonStatsRankingSize).toList(),
    hostAvgPlus: rankHostsByAvgPlus(hosts).take(kSeasonStatsRankingSize).toList(),
    hostAvgMinus: rankHostsByAvgMinus(hosts).take(kSeasonStatsRankingSize).toList(),
    gamesWithoutHost: gamesWithoutHost(seasonGames),
    seasonGames: seasonGames.length,
    tournaments: tournaments,
  );
}

({int main, int small}) leagueCounts(
    List<RatingPlayerStats> all, SeasonConfig season) {
  final main = all.where((p) => p.gamesPlayed >= season.gameLimit).length;
  final small = all
      .where((p) =>
          p.gamesPlayed >= season.smallLeagueMinGames &&
          p.gamesPlayed < season.gameLimit)
      .length;
  return (main: main, small: small);
}
```

- [ ] **Step 4: Add the providers and fix the players count**

In `lib/screens/home/home_providers.dart`:

1. In `seasonSummaryProvider`, replace the `uniquePlayers` block and the `players:` field with:

```dart
  return (
    games: allGames.length,
    players: allGames.getPlayersList(season.id).length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
    mafiaWR: decided > 0 ? mafiaWins / decided : 0.0,
  );
```

(Add `import 'package:family_mafia_app/models/game.dart';` for the `getPlayersList` extension.)

2. Append:

```dart
/// Canonical-name lookup built once from players.json.
final playerResolverProvider = Provider<PlayerResolver>(
  (ref) => PlayerResolver(ref.watch(playersRepositoryProvider)),
);

/// Main / small league head-counts for the selected season (default limits).
final seasonLeagueCountsProvider = Provider<({int main, int small})?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;
  final full = ref.watch(seasonRepositoryProvider)[season.id];
  if (full == null) return null;
  return leagueCounts(full.playerStats, season);
});

/// Data for the Season Stats card, following the league toggle.
final seasonExtraStatsProvider = Provider<SeasonExtraStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  final stats = ref.watch(currentSeasonStatsProvider);
  if (season == null || stats == null) return null;
  final games = ref
      .watch(gamesRepositoryProvider)
      .where((g) => g.seasonId == season.id)
      .toList();
  return buildSeasonExtraStats(
    leaguePlayers: stats.playerStats,
    seasonGames: games,
    seasonTournaments: ref
        .watch(tournamentsProvider)
        .where((t) => t.seasonId == season.id)
        .toList(),
    resolver: ref.watch(playerResolverProvider),
  );
});
```

Also add these imports: `players_repository.dart`, `services/stats/player_resolver.dart` and `services/stats/season_extra_stats.dart`.

3. In `lib/screens/dashboard/dashboard_providers.dart` `clubOverviewProvider`, replace `uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));` with a per-season exclusion-aware set:

```dart
    uniquePlayers.addAll(g.players.where((p) =>
        p.trim().isNotEmpty &&
        !p.startsWith('_blank_') &&
        !(kExcludedPlayers[g.seasonId]?.contains(p) ?? false)));
```

(`season_constants.dart` is already imported.)

- [ ] **Step 5: Run the tests**

Run: `flutter test test/services/stats/season_extra_stats_test.dart test/screens/home`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/services/stats/season_extra_stats.dart lib/screens/home/home_providers.dart lib/screens/dashboard/dashboard_providers.dart test/services/stats/season_extra_stats_test.dart
git commit -m "feat: season extra stats; players count skips blanks and test players"
```

---

### Task 6: Season screen UI (hero second row and Season Stats card)

**Files:**
- Modify: `lib/widgets/hero_card.dart` (optional `secondaryStatTiles`)
- Modify: `lib/screens/home/src/season_header_card.dart` (generic badge/ranking, hero second row)
- Create: `lib/screens/home/src/season_stats_card.dart`
- Modify: `lib/screens/home/home_screen.dart` (part + sliver)
- Test: `test/widgets/hero_card_test.dart`

**Interfaces:**
- Consumes: `seasonExtraStatsProvider`, `seasonLeagueCountsProvider` (Task 5), `TournamentType` (Task 3), `redGames` (Task 5).
- Produces: `HeroCard(secondaryStatTiles: List<HeroStatTile>?)`; the private `_StatBadge`, `_StatRanking` and `_RankingEntry` inside the home_screen library.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/hero_card_test.dart
import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a second row of tiles when given', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: HeroCard(
          label: 'S26', title: 'Season Summary',
          gradientStart: Colors.teal, gradientEnd: Colors.black,
          statTiles: [HeroStatTile(value: '303', label: 'Games')],
          secondaryStatTiles: [HeroStatTile(value: '22', label: 'Main league')],
        ),
      ),
    ));
    expect(find.text('Main league'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widgets/hero_card_test.dart`
Expected: FAIL. `secondaryStatTiles` is not a parameter yet.

- [ ] **Step 3: Extend `HeroCard`**

In `lib/widgets/hero_card.dart`:
- Add `this.secondaryStatTiles` to the constructor and `final List<HeroStatTile>? secondaryStatTiles;` to the fields.
- Replace the single `Row(children: statTiles.expand(...))` with a helper that is used for both rows:

```dart
  Widget _row(List<HeroStatTile> tiles) => Row(
        children: tiles
            .expand((tile) => [
                  Expanded(child: tile),
                  if (tile != tiles.last) const SizedBox(width: 8),
                ])
            .toList(),
      );
```

  In `build`, put `_row(statTiles),` where the old Row was. Right after it, add:

```dart
            if (secondaryStatTiles != null) ...[
              const SizedBox(height: 8),
              _row(secondaryStatTiles!),
            ],
```

Run: `flutter test test/widgets/hero_card_test.dart`
Expected: PASS.

- [ ] **Step 4: Add the hero second row**

In `_SeasonHeroCard.build` (`season_header_card.dart`), read the counts and pass the second row:

```dart
    final leagues = ref.watch(seasonLeagueCountsProvider);
    final tournamentsCount = ref
        .watch(tournamentsProvider)
        .where((t) => t.seasonId == season.id)
        .length;
```

Then add this to the `HeroCard(...)` call:

```dart
      secondaryStatTiles: [
        HeroStatTile(value: '${leagues?.main ?? 0}', label: 'Main league'),
        HeroStatTile(value: '${leagues?.small ?? 0}', label: 'Small league'),
        HeroStatTile(value: '$tournamentsCount', label: 'Tournaments'),
      ],
```

- [ ] **Step 5: Make the badge and ranking generic**

In `season_header_card.dart`:
1. Add `typedef _RankingEntry = ({String name, String points, String detail});`.
2. Change `_AwardBadge` to take explicit fields instead of `_AwardConfig`: `icon`, `label`, `iconColor`, `bgColor`, `winner`, `isOpen`, `onTap`. Replace every `config.icon` / `config.label` / `config.iconColor` / `config.bgColor` in its build with the new fields. Rename the class to `_StatBadge`.
3. Rename `_AwardRanking` to `_StatRanking` and make it take `icon`, `label`, `iconColor`, `bgColor`, `pointsLabel`, `metricLabel`, `emptyText` and `List<_RankingEntry> entries`. It renders `_RankingHeader(pointsLabel: pointsLabel, metricLabel: metricLabel)` and one `_RankingRow(rank: i + 1, name: e.name, points: e.points, detail: e.detail, accent: iconColor)` per entry. When the list is empty it shows `emptyText` in the same grey style as before.
4. `_RankingHeader` gets a `pointsLabel` field that replaces the hard-coded `'Avg pts'`.
5. In `_SeasonAwardsCardState.build`, build the badge as `_StatBadge(icon: a.icon, label: a.label, iconColor: a.iconColor, bgColor: a.bgColor, winner: _winnerName(a.ranking), isOpen: a.label == _openAward, onTap: () => _toggle(a))`. Build the open panel as:

```dart
_StatRanking(
  icon: open.icon, label: open.label,
  iconColor: open.iconColor, bgColor: open.bgColor,
  pointsLabel: 'Avg pts', metricLabel: open.metricLabel,
  emptyText: 'Nobody played enough games for this award.',
  entries: [
    for (final p in open.ranking.map(_statsFor).whereType<RatingPlayerStats>())
      (name: p.player.displayName, points: open.points(p), detail: open.detail(p)),
  ],
)
```

Run: `flutter test test/screens/home`
Expected: PASS. The awards render the same as before.

- [ ] **Step 6: Build the Season Stats card**

```dart
// lib/screens/home/src/season_stats_card.dart
part of '../home_screen.dart';

class _StatItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final String winner;
  final String pointsLabel;
  final String metricLabel;
  final String emptyText;
  final List<_RankingEntry> entries;

  /// False for count-only items (No host) that have no ranking to open.
  final bool expandable;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.winner,
    required this.pointsLabel,
    required this.metricLabel,
    required this.emptyText,
    required this.entries,
    this.expandable = true,
  });
}

class _SeasonStatsCard extends ConsumerStatefulWidget {
  final bool showHosts;

  const _SeasonStatsCard({required this.showHosts});

  @override
  ConsumerState<_SeasonStatsCard> createState() => _SeasonStatsCardState();
}

class _SeasonStatsCardState extends ConsumerState<_SeasonStatsCard> {
  String? _open;

  static String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
  static String _signed(double v) =>
      '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';

  List<_StatItem> _items(SeasonExtraStats s) {
    String first<T>(List<T> l, String Function(T) f) =>
        l.isEmpty ? '—' : f(l.first);
    return [
      _StatItem(
        icon: Icons.casino, label: 'Most Games',
        iconColor: const Color(0xFF3F51B5), bgColor: const Color(0xFFE8EAF6),
        winner: first(s.mostGames, (p) => '${p.player.displayName} · ${p.gamesPlayed}'),
        pointsLabel: 'WR', metricLabel: 'Games',
        emptyText: 'No players in this league.',
        entries: [
          for (final p in s.mostGames)
            (name: p.player.displayName, points: _pct(p.winRate), detail: '${p.gamesPlayed}'),
        ],
      ),
      _StatItem(
        icon: Icons.nightlight_round, label: 'Top ПУ %',
        iconColor: const Color(0xFFFF9800), bgColor: const Color(0xFFFFF3E0),
        winner: first(s.topFirstKilledPct, (p) => '${p.player.displayName} · ${_pct(p.percentOfDeath)}'),
        pointsLabel: 'ПУ', metricLabel: '% of red',
        emptyText: 'No red games in this league.',
        entries: [
          for (final p in s.topFirstKilledPct)
            (name: p.player.displayName, points: '${p.firstKilled}/${redGames(p)}', detail: _pct(p.percentOfDeath)),
        ],
      ),
      if (widget.showHosts) ...[
        _StatItem(
          icon: Icons.mic, label: 'Most Hosted',
          iconColor: const Color(0xFF00897B), bgColor: const Color(0xFFE0F2F1),
          winner: first(s.mostHosted, (h) => '${h.host.displayName} · ${h.hosted}'),
          pointsLabel: 'Share', metricLabel: 'Games',
          emptyText: 'No host data for this season.',
          entries: [
            for (final h in s.mostHosted)
              (name: h.host.displayName, points: s.seasonGames == 0 ? '—' : _pct(h.hosted / s.seasonGames), detail: '${h.hosted}'),
          ],
        ),
        _StatItem(
          icon: Icons.add_circle_outline, label: 'Host avg доп',
          iconColor: const Color(0xFF43A047), bgColor: const Color(0xFFE8F5E9),
          winner: first(s.hostAvgPlus, (h) => '${h.host.displayName} · ${_signed(h.avgPlus)}'),
          pointsLabel: 'Games', metricLabel: 'Avg / game',
          emptyText: 'No host hosted $kHostMinGamesForAverage+ games.',
          entries: [
            for (final h in s.hostAvgPlus)
              (name: h.host.displayName, points: '${h.hosted}', detail: _signed(h.avgPlus)),
          ],
        ),
        _StatItem(
          icon: Icons.remove_circle_outline, label: 'Host avg мінус',
          iconColor: const Color(0xFFE53935), bgColor: const Color(0xFFFFEBEE),
          winner: first(s.hostAvgMinus, (h) => '${h.host.displayName} · ${_signed(h.avgMinus)}'),
          pointsLabel: 'Games', metricLabel: 'Avg / game',
          emptyText: 'No host hosted $kHostMinGamesForAverage+ games.',
          entries: [
            for (final h in s.hostAvgMinus)
              (name: h.host.displayName, points: '${h.hosted}', detail: _signed(h.avgMinus)),
          ],
        ),
        _StatItem(
          icon: Icons.help_outline, label: 'No host',
          iconColor: const Color(0xFF757575), bgColor: const Color(0xFFF5F5F5),
          winner: s.gamesWithoutHost == null ? 'No data' : '${s.gamesWithoutHost} games',
          pointsLabel: '', metricLabel: '', emptyText: '', entries: const [],
          expandable: false,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(seasonExtraStatsProvider);
    if (s == null) return const SizedBox.shrink();
    final items = _items(s);
    final open = items.where((i) => i.label == _open).firstOrNull;

    return SectionCard(
      title: 'Season Stats',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: [
              for (final i in items)
                _StatBadge(
                  icon: i.icon, label: i.label,
                  iconColor: i.iconColor, bgColor: i.bgColor,
                  winner: i.winner,
                  isOpen: i.label == _open,
                  onTap: i.expandable
                      ? () => setState(() => _open = _open == i.label ? null : i.label)
                      : null,
                ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open == null
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _StatRanking(
                      icon: open.icon, label: open.label,
                      iconColor: open.iconColor, bgColor: open.bgColor,
                      pointsLabel: open.pointsLabel, metricLabel: open.metricLabel,
                      emptyText: open.emptyText, entries: open.entries,
                    ),
                  ),
          ),
          if (s.tournaments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in TournamentType.values)
                  if ((s.tournaments[t] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${s.tournaments[t]} ${t.label.toLowerCase()}${s.tournaments[t]! > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.color),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

`_StatBadge.onTap` must become `VoidCallback?`. When it is null, hide the chevron: `if (onTap != null) AnimatedRotation(...)`.

- [ ] **Step 7: Wire it into the season screen**

In `lib/screens/home/home_screen.dart`:
- Add `part 'src/season_stats_card.dart';`.
- Add these imports: `models/tournament.dart`, `services/stats/host_stats.dart` (for `kHostMinGamesForAverage`) and `services/stats/season_extra_stats.dart`.
- After the awards block (`if (league == League.main) ...[ ... ]`), insert:

```dart
            SliverToBoxAdapter(
              child: _SeasonStatsCard(showHosts: league == League.main),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 10)),
```

- [ ] **Step 8: Run and look**

Run: `flutter test`
Expected: all pass.

Run: `flutter analyze`
Expected: no new issues.

Run the app (`flutter run`), open Season 26, and check each of these:
- the hero shows Main league / Small league / Tournaments;
- Season Stats shows 6 badges on Main and 2 on Small;
- tapping Most Hosted opens the top 4;
- Season 0 shows "No host · No data".

- [ ] **Step 9: Commit**

```bash
git add lib/widgets/hero_card.dart lib/screens/home test/widgets/hero_card_test.dart
git commit -m "feat: Season Stats card and league/tournament tiles"
```

---

### Task 7: Cross-season win streaks

**Files:**
- Create: `lib/services/stats/win_streaks.dart`
- Test: `test/services/stats/win_streaks_test.dart`

**Interfaces:**
- Consumes: `PlayerResolver`, `personKey` (Task 4).
- Produces: `class WinStreak { Player player; int length; int fromSeason; int toSeason; String get seasonsLabel; }` (`'S19'` or `'S18–S19'`), and `List<WinStreak> bestWinStreaks(List<Game> games, PlayerResolver resolver)`, which returns each player's best streak, sorted by length desc and then name.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/win_streaks_test.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game where [name] sits in slot 0 as a civilian; city wins when [won].
Game _g(int season, String name, bool won) => Game(
      seasonId: season,
      players: [name, ...List.generate(9, (i) => 'x$i')],
      roles: ['Мирный', 'Мафия', 'Мафия', 'Дон', 'Шериф', ...List.filled(5, 'Мирный')],
      cityWon: won,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
    );

final _r = PlayerResolver(const [
  Player(id: 1, displayName: 'Seezov', nicknames: ['Сізов']),
]);

String? _best(List<WinStreak> s, String name) =>
    s.where((w) => w.player.displayName == name).map((w) => '${w.length} ${w.seasonsLabel}').firstOrNull;

void main() {
  test('a loss breaks the streak', () {
    final s = bestWinStreaks([_g(19, 'A', true), _g(19, 'A', true), _g(19, 'A', false), _g(19, 'A', true)], _r);
    expect(_best(s, 'A'), '2 S19');
  });

  test('streaks continue across seasons', () {
    final s = bestWinStreaks([_g(18, 'A', true), _g(19, 'A', true), _g(19, 'A', true)], _r);
    expect(_best(s, 'A'), '3 S18–S19');
  });

  test('games are ordered by season even if loaded out of order', () {
    final s = bestWinStreaks([_g(19, 'A', true), _g(18, 'A', false), _g(20, 'A', true)], _r);
    expect(_best(s, 'A'), '2 S19–S20');
  });

  test('nicknames merge into one streak', () {
    final s = bestWinStreaks([_g(18, 'Seezov', true), _g(19, 'Сізов', true)], _r);
    expect(_best(s, 'Seezov'), '2 S18–S19');
  });

  test('blank slots are ignored', () {
    final s = bestWinStreaks([_g(18, '_blank_0', true)], _r);
    expect(s.where((w) => w.player.displayName.startsWith('_blank_')), isEmpty);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/win_streaks_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/win_streaks.dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

class WinStreak {
  final Player player;
  final int length;
  final int fromSeason;
  final int toSeason;

  const WinStreak({
    required this.player,
    required this.length,
    required this.fromSeason,
    required this.toSeason,
  });

  String get seasonsLabel =>
      fromSeason == toSeason ? 'S$fromSeason' : 'S$fromSeason–S$toSeason';
}

/// Each player's longest run of consecutive rating-game wins. Games are
/// ordered by season, then by their order in the season sheet; the run may
/// cross season boundaries.
List<WinStreak> bestWinStreaks(List<Game> games, PlayerResolver resolver) {
  final ordered = games.indexed.where((e) => e.$2.isRatingGame()).toList()
    ..sort((a, b) {
      final c = a.$2.seasonId.compareTo(b.$2.seasonId);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

  final current = <String, (Player, int, int)>{}; // key → (player, len, fromSeason)
  final best = <String, WinStreak>{};

  void close(String key, int toSeason) {
    final cur = current.remove(key);
    if (cur == null || cur.$2 == 0) return;
    final prev = best[key];
    if (prev == null || cur.$2 > prev.length) {
      best[key] = WinStreak(player: cur.$1, length: cur.$2, fromSeason: cur.$3, toSeason: toSeason);
    }
  }

  final lastSeason = <String, int>{};
  for (final (_, g) in ordered) {
    final excluded = kExcludedPlayers[g.seasonId] ?? const <String>[];
    for (final raw in g.players) {
      if (raw.startsWith('_blank_') || excluded.contains(raw)) continue;
      final player = resolver.resolve(raw);
      final key = personKey(player);
      if (g.hasPlayerWon(raw)) {
        final cur = current[key];
        current[key] = cur == null ? (player, 1, g.seasonId) : (cur.$1, cur.$2 + 1, cur.$3);
        lastSeason[key] = g.seasonId;
      } else {
        close(key, lastSeason[key] ?? g.seasonId);
      }
    }
  }
  for (final key in current.keys.toList()) {
    close(key, lastSeason[key]!);
  }

  return best.values.toList()
    ..sort((a, b) {
      final c = b.length.compareTo(a.length);
      return c != 0 ? c : a.player.displayName.compareTo(b.player.displayName);
    });
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/services/stats/win_streaks_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats/win_streaks.dart test/services/stats/win_streaks_test.dart
git commit -m "feat: cross-season win streaks"
```

---

### Task 8: Records computations

**Files:**
- Create: `lib/services/stats/records.dart`
- Test: `test/services/stats/records_test.dart`

**Interfaces:**
- Consumes: `GamePoints` (Task 2), `PointsPeriod` (Task 2), `PlayerResolver`/`personKey` (Task 4), `hostStats` (Task 4).
- Produces (every function takes `RecordsInput`):
  - `class RecordsInput { Map<int, List<RatingPlayerStats>> ratings; List<SeasonConfig> configs; List<Game> games; PlayerResolver resolver; }`
  - `class MvpRecord { Player player; int seasonId; double addPerGame; double maxSingleAdd; double totalAdd; double winRate; }` from `List<MvpRecord> mvpRecords(RecordsInput i, PointsPeriod period)`
  - `class RoleRecord { Player player; int seasonId; Role role; double pointsPerGame; int games; double winRate; }` from `List<RoleRecord> roleRecords(RecordsInput i, Role role, PointsPeriod period)`
  - `class GamesRecord { Player player; int? seasonId; int games; double winRate; }` from `List<GamesRecord> gamesRecords(RecordsInput i, {required bool allTime})`
  - `class FirstKillRecord { Player player; int seasonId; int count; int redGames; double pct; }` from `List<FirstKillRecord> firstKillRecords(RecordsInput i)`
  - `class PenaltyRecord { Player player; int seasonId; double minusPerGame; double maxSingleMinus; double totalMinus; double winRate; }` from `List<PenaltyRecord> penaltyRecords(RecordsInput i, PointsPeriod period)`
  - `class HostRecord { Player host; int? seasonId; int hosted; double avgPlus; double avgMinus; }` from `List<HostRecord> hostRecords(RecordsInput i, {required bool allTime, PointsPeriod? period})`

  Each list is returned in its default sort (first metric desc, or most-negative-first for minus), with name as the tie-break. The UI re-sorts.

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/records_test.dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _cfg(int id) => SeasonConfig(
    id: id, title: 'S$id', gameLimit: 2, smallLeagueMinGames: 1,
    gamesMultiplier: 0, source: const BundledSource(jsonFile: 'x'));

RatingPlayerStats _r(int season, int id, {int games = 2, int wins = 1, double add = 0.6}) =>
    RatingPlayerStats(
      seasonId: season, player: Player(id: id, displayName: 'P$id'),
      gamesPlayed: games, wins: wins, winRate: wins / games, additionalPoints: add,
      firstKilled: 1, percentOfDeath: 0.5,
      gamesForRole: [('Мирний', 2)], winByRole: [('Мирний', wins)],
      bestMoveAndAdditionalPointsByRole: [('Мирний', add)],
    );

Game _g(int season, {double add0 = 0, double add1 = 0, String? host}) => Game(
      seasonId: season,
      players: ['P1', 'P2', ...List.generate(8, (i) => 'x$i')],
      roles: List.filled(10, 'Мирный'),
      cityWon: true, firstKilled: 0, bestMovePoints: 0, bestMove: const [],
      additionalPoints: [add0, add1, ...List.filled(8, 0.0)],
      host: host,
    );

RecordsInput _input({Map<int, List<RatingPlayerStats>>? ratings, List<Game>? games}) => RecordsInput(
      ratings: ratings ?? {10: [_r(10, 1), _r(10, 2, games: 1)]},
      configs: [_cfg(2), _cfg(10)],
      games: games ?? [_g(10, add0: 0.5, add1: -0.3), _g(10, add0: 0.1)],
      resolver: PlayerResolver(const [Player(id: 1, displayName: 'P1'), Player(id: 2, displayName: 'P2')]),
    );

void main() {
  test('MVP: main league only, per game and max single доп', () {
    final r = mvpRecords(_input(), PointsPeriod.modern);
    expect(r.map((e) => e.player.id), [1]); // P2 has 1 game < gameLimit 2
    expect(r.single.addPerGame, closeTo(0.3, 1e-9));
    expect(r.single.maxSingleAdd, closeTo(0.5, 1e-9));
  });

  test('periods keep seasons 2-3 apart from 4+', () {
    final input = _input(ratings: {2: [_r(2, 1)], 10: [_r(10, 1)]});
    expect(mvpRecords(input, PointsPeriod.li).single.seasonId, 2);
    expect(mvpRecords(input, PointsPeriod.modern).single.seasonId, 10);
  });

  test('penalties read the minus from games', () {
    final input = _input(ratings: {10: [_r(10, 2)]});
    final r = penaltyRecords(input, PointsPeriod.modern);
    expect(r.single.totalMinus, closeTo(-0.3, 1e-9));
    expect(r.single.maxSingleMinus, closeTo(-0.3, 1e-9));
  });

  test('all-time games include every player and sum seasons', () {
    final input = _input(ratings: {2: [_r(2, 1, games: 1)], 10: [_r(10, 1, games: 1)]});
    expect(gamesRecords(input, allTime: true).single.games, 2);
    expect(gamesRecords(input, allTime: false), isEmpty); // both below gameLimit
  });

  test('roles use the role games and points', () {
    final r = roleRecords(_input(), Role.civilian, PointsPeriod.modern);
    expect(r.single.games, 2);
  });

  test('works with a single loaded season and no games', () {
    final input = RecordsInput(ratings: {10: [_r(10, 1)]}, configs: [_cfg(10)], games: const [], resolver: PlayerResolver(const []));
    expect(mvpRecords(input, PointsPeriod.modern).single.maxSingleAdd, 0);
    expect(hostRecords(input, allTime: true), isEmpty);
  });

  test('ties sort by name', () {
    final input = _input(ratings: {10: [_r(10, 2), _r(10, 1)]});
    expect(mvpRecords(input, PointsPeriod.modern).map((e) => e.player.id), [1, 2]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/records_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/records.dart
import 'dart:math';

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';

class RecordsInput {
  final Map<int, List<RatingPlayerStats>> ratings;
  final List<SeasonConfig> configs;
  final List<Game> games;
  final PlayerResolver resolver;

  const RecordsInput({required this.ratings, required this.configs, required this.games, required this.resolver});
}

class MvpRecord {
  final Player player; final int seasonId;
  final double addPerGame, maxSingleAdd, totalAdd, winRate;
  const MvpRecord(this.player, this.seasonId, this.addPerGame, this.maxSingleAdd, this.totalAdd, this.winRate);
}

class RoleRecord {
  final Player player; final int seasonId; final Role role;
  final double pointsPerGame; final int games; final double winRate;
  const RoleRecord(this.player, this.seasonId, this.role, this.pointsPerGame, this.games, this.winRate);
}

class GamesRecord {
  final Player player; final int? seasonId; final int games; final double winRate;
  const GamesRecord(this.player, this.seasonId, this.games, this.winRate);
}

class FirstKillRecord {
  final Player player; final int seasonId; final int count, redGames; final double pct;
  const FirstKillRecord(this.player, this.seasonId, this.count, this.redGames, this.pct);
}

class PenaltyRecord {
  final Player player; final int seasonId;
  final double minusPerGame, maxSingleMinus, totalMinus, winRate;
  const PenaltyRecord(this.player, this.seasonId, this.minusPerGame, this.maxSingleMinus, this.totalMinus, this.winRate);
}

class HostRecord {
  final Player host; final int? seasonId; final int hosted; final double avgPlus, avgMinus;
  const HostRecord(this.host, this.seasonId, this.hosted, this.avgPlus, this.avgMinus);
}

/// Main-league rows (player reached the season's gameLimit) in [period].
Iterable<RatingPlayerStats> _mainLeague(RecordsInput i, {PointsPeriod? period}) sync* {
  final limits = {for (final c in i.configs) c.id: c.gameLimit};
  for (final MapEntry(key: season, value: list) in i.ratings.entries) {
    if (period != null && !period.contains(season)) continue;
    final limit = limits[season];
    if (limit == null) continue;
    yield* list.where((p) => p.gamesPlayed >= limit);
  }
}

/// Per (season, player key): max single plus, max single minus, total minus.
Map<(int, String), (double, double, double)> _perGamePoints(RecordsInput i) {
  final out = <(int, String), (double, double, double)>{};
  for (final g in i.games) {
    for (var s = 0; s < g.players.length; s++) {
      final key = (g.seasonId, personKey(i.resolver.resolve(g.players[s])));
      final (maxPlus, maxMinus, total) = out[key] ?? (0.0, 0.0, 0.0);
      final minus = g.slotMinus(s);
      out[key] = (max(maxPlus, g.slotPlus(s)), min(maxMinus, minus), total + minus);
    }
  }
  return out;
}

int _byName(Player a, Player b) => a.displayName.compareTo(b.displayName);

List<T> _sorted<T>(List<T> l, double Function(T) v, Player Function(T) p, {bool desc = true}) =>
    l..sort((a, b) {
      final c = desc ? v(b).compareTo(v(a)) : v(a).compareTo(v(b));
      return c != 0 ? c : _byName(p(a), p(b));
    });

List<MvpRecord> mvpRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final rows = [
    for (final p in _mainLeague(i, period: period))
      MvpRecord(p.player, p.seasonId, p.additionalPoints / p.gamesPlayed,
          pts[(p.seasonId, personKey(p.player))]?.$1 ?? 0, p.additionalPoints, p.winRate),
  ];
  return _sorted(rows, (r) => r.addPerGame, (r) => r.player);
}

(int, int, double) _role(RatingPlayerStats p, Role role) {
  bool isRole(String v) => role.sheetValues.contains(v);
  final games = p.gamesForRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final wins = p.winByRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final points = p.bestMoveAndAdditionalPointsByRole.where((e) => isRole(e.$1)).fold(0.0, (s, e) => s + e.$2);
  return (games, wins, points);
}

List<RoleRecord> roleRecords(RecordsInput i, Role role, PointsPeriod period) {
  final limits = {for (final c in i.configs) c.id: c.gameLimit};
  final rows = <RoleRecord>[];
  for (final p in _mainLeague(i, period: period)) {
    final (games, wins, points) = _role(p, role);
    if (games == 0 || games < (limits[p.seasonId] ?? 0) * role.chanceToDraw) continue;
    rows.add(RoleRecord(p.player, p.seasonId, role, points / games, games, wins / games));
  }
  return _sorted(rows, (r) => r.pointsPerGame, (r) => r.player);
}

List<GamesRecord> gamesRecords(RecordsInput i, {required bool allTime}) {
  if (!allTime) {
    return _sorted([
      for (final p in _mainLeague(i)) GamesRecord(p.player, p.seasonId, p.gamesPlayed, p.winRate),
    ], (r) => r.games.toDouble(), (r) => r.player);
  }
  final acc = <String, (Player, int, int)>{};
  for (final list in i.ratings.values) {
    for (final p in list) {
      final key = personKey(p.player);
      final (pl, g, w) = acc[key] ?? (p.player, 0, 0);
      acc[key] = (pl, g + p.gamesPlayed, w + p.wins);
    }
  }
  return _sorted([
    for (final (p, g, w) in acc.values) GamesRecord(p, null, g, g == 0 ? 0 : w / g),
  ], (r) => r.games.toDouble(), (r) => r.player);
}

List<FirstKillRecord> firstKillRecords(RecordsInput i) => _sorted([
      for (final p in _mainLeague(i))
        if (redGames(p) > 0)
          FirstKillRecord(p.player, p.seasonId, p.firstKilled, redGames(p), p.percentOfDeath),
    ], (r) => r.count.toDouble(), (r) => r.player);

List<PenaltyRecord> penaltyRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final rows = [
    for (final p in _mainLeague(i, period: period))
      () {
        final (_, maxMinus, total) = pts[(p.seasonId, personKey(p.player))] ?? (0.0, 0.0, 0.0);
        return PenaltyRecord(p.player, p.seasonId, total / p.gamesPlayed, maxMinus, total, p.winRate);
      }(),
  ];
  return _sorted(rows, (r) => r.minusPerGame, (r) => r.player, desc: false);
}

List<HostRecord> hostRecords(RecordsInput i, {required bool allTime, PointsPeriod? period}) {
  Iterable<Game> inPeriod(Iterable<Game> g) =>
      period == null ? g : g.where((x) => period.contains(x.seasonId));
  final rows = <HostRecord>[];
  if (allTime) {
    for (final h in hostStats(inPeriod(i.games), i.resolver)) {
      rows.add(HostRecord(h.host, null, h.hosted, h.avgPlus, h.avgMinus));
    }
  } else {
    final seasons = i.games.map((g) => g.seasonId).toSet();
    for (final s in seasons) {
      if (period != null && !period.contains(s)) continue;
      for (final h in hostStats(i.games.where((g) => g.seasonId == s), i.resolver)) {
        rows.add(HostRecord(h.host, s, h.hosted, h.avgPlus, h.avgMinus));
      }
    }
  }
  return _sorted(rows, (r) => r.hosted.toDouble(), (r) => r.host);
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/services/stats/records_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/stats/records.dart test/services/stats/records_test.dart
git commit -m "feat: all-time records computations"
```

---

### Task 9: SortableTable widget

**Files:**
- Create: `lib/widgets/sortable_table.dart`
- Test: `test/widgets/sortable_table_test.dart`

**Interfaces:**
- Produces:
  - `class SortableColumn<T> { final String label; final double width; final String Function(T) text; final num Function(T)? sortValue; }`. A null `sortValue` makes the column not sortable.
  - `class SortableTable<T> extends StatefulWidget { columns; rows; int initialSortIndex; bool initialDescending; int? collapsedRowCount; bool showRank; }`. `columns[0]` is sticky. `showRank` adds a medal-coloured `#` column in front. When `collapsedRowCount` is set, a "Show all (N)" button expands the rest.

- [ ] **Step 1: Write the failing test**

```dart
// test/widgets/sortable_table_test.dart
import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Row = ({String name, int games});

Widget _app(List<_Row> rows, {int? collapsed}) => MaterialApp(
      home: Scaffold(
        body: SortableTable<_Row>(
          columns: [
            SortableColumn(label: 'Name', width: 90, text: (r) => r.name),
            SortableColumn(label: 'Games', width: 60, text: (r) => '${r.games}', sortValue: (r) => r.games),
          ],
          rows: rows,
          initialSortIndex: 1,
          collapsedRowCount: collapsed,
        ),
      ),
    );

void main() {
  const rows = [(name: 'A', games: 1), (name: 'B', games: 3), (name: 'C', games: 2)];

  testWidgets('sorts descending by the initial column', (t) async {
    await t.pumpWidget(_app(rows));
    final names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['B', 'C', 'A']);
  });

  testWidgets('tapping the header flips the direction', (t) async {
    await t.pumpWidget(_app(rows));
    await t.tap(find.textContaining('Games'));
    await t.pump();
    final names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['A', 'C', 'B']);
  });

  testWidgets('collapses to N rows with a Show all button', (t) async {
    await t.pumpWidget(_app(rows, collapsed: 2));
    expect(find.text('A'), findsNothing);
    await t.tap(find.text('Show all (3)'));
    await t.pump();
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/widgets/sortable_table_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/widgets/sortable_table.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

class SortableColumn<T> {
  final String label;
  final double width;
  final String Function(T) text;
  final num Function(T)? sortValue;

  const SortableColumn({required this.label, required this.width, required this.text, this.sortValue});
}

/// A table whose first column stays put while the rest scroll sideways.
/// Tapping a sortable header sorts by it; tapping again flips the direction.
class SortableTable<T> extends StatefulWidget {
  final List<SortableColumn<T>> columns;
  final List<T> rows;
  final int initialSortIndex;
  final bool initialDescending;
  final int? collapsedRowCount;
  final bool showRank;

  const SortableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.initialSortIndex = 0,
    this.initialDescending = true,
    this.collapsedRowCount,
    this.showRank = false,
  });

  @override
  State<SortableTable<T>> createState() => _SortableTableState<T>();
}

class _SortableTableState<T> extends State<SortableTable<T>> {
  static const _rowHeight = 34.0;
  static const _rankWidth = 26.0;
  static const _medals = [Color(0xFFF9A825), Color(0xFF90A4AE), Color(0xFFBF8970)];

  late int _sortIndex = widget.initialSortIndex;
  late bool _desc = widget.initialDescending;
  bool _expanded = false;

  List<T> get _sorted {
    final value = widget.columns[_sortIndex].sortValue;
    if (value == null) return widget.rows;
    final list = [...widget.rows];
    list.sort((a, b) => _desc ? value(b).compareTo(value(a)) : value(a).compareTo(value(b)));
    return list;
  }

  void _tap(int i) {
    if (widget.columns[i].sortValue == null) return;
    setState(() {
      if (_sortIndex == i) {
        _desc = !_desc;
      } else {
        _sortIndex = i;
        _desc = true;
      }
    });
  }

  Widget _header(int i) {
    final c = widget.columns[i];
    final active = i == _sortIndex;
    return InkWell(
      onTap: c.sortValue == null ? null : () => _tap(i),
      child: Container(
        width: c.width,
        height: _rowHeight,
        alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          active ? '${c.label} ${_desc ? '▼' : '▲'}' : c.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF00897B) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _cell(int col, T row) {
    final c = widget.columns[col];
    final active = col == _sortIndex;
    return Container(
      width: c.width,
      height: _rowHeight,
      alignment: col == 0 ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Text(
        c.text(row),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: col == 0 || active ? FontWeight.w700 : FontWeight.w400,
          color: active ? const Color(0xFF004D40) : const Color(0xDD000000),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _rank(int index) => Container(
        width: _rankWidth,
        height: _rowHeight,
        alignment: Alignment.center,
        child: Text('${index + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: index < 3 ? _medals[index] : Colors.grey,
            )),
      );

  @override
  Widget build(BuildContext context) {
    final all = _sorted;
    final limit = widget.collapsedRowCount;
    final rows = (!_expanded && limit != null) ? all.take(limit).toList() : all;
    final rest = List.generate(widget.columns.length - 1, (i) => i + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showRank)
              Column(children: [
                const SizedBox(width: _rankWidth, height: _rowHeight),
                for (var i = 0; i < rows.length; i++) _rank(i),
              ]),
            Column(children: [_header(0), for (final r in rows) _cell(0, r)]),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [for (final i in rest) _header(i)]),
                    for (final r in rows) Row(children: [for (final i in rest) _cell(i, r)]),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (limit != null && all.length > limit)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show all (${all.length})'),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/widgets/sortable_table_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/sortable_table.dart test/widgets/sortable_table_test.dart
git commit -m "feat: sortable table with sticky first column"
```

---

### Task 10: Dashboard seasons table

**Files:**
- Create: `lib/services/stats/season_rows.dart`
- Create: `lib/screens/dashboard/seasons_table.dart`
- Modify: `lib/screens/dashboard/dashboard_providers.dart` (`seasonRowsProvider`)
- Modify: `lib/screens/dashboard/dashboard_screen.dart` (insert card after Club Overview)
- Test: `test/services/stats/season_rows_test.dart`

**Interfaces:**
- Consumes: `SeasonStats` rankings (existing), `leagueCounts`, `buildSeasonExtraStats` (Task 5), `Tournament` (Task 3), `SortableTable` (Task 9), `PlayerResolver` (Task 4).
- Produces:
  - `class SeasonRow { int seasonId; int games; double cityWR; double mafiaWR; int players; int mainLeague; Map<TournamentType,int> tournaments; ({String name, num value})? mostGames, mvp, mostKilled, topKilledPct, mostHosted, hostAvgPlus, bestDon, bestSheriff, bestCivilian, bestMafia; }`
  - `List<SeasonRow> buildSeasonRows({required List<SeasonConfig> configs, required Map<int, SeasonStats> seasons, required List<Game> games, required List<Tournament> tournaments, required PlayerResolver resolver})`
  - `seasonRowsProvider: Provider<List<SeasonRow>>`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/season_rows_test.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(bool city) => Game(
      seasonId: 26, players: ['A', 'B', ...List.generate(8, (i) => 'x$i')],
      roles: List.filled(10, 'Мирный'), cityWon: city, firstKilled: 0,
      bestMovePoints: 0, bestMove: const [], host: 'H',
    );

void main() {
  test('builds one row per loaded season, skipping seasons without stats', () {
    final a = RatingPlayerStats(seasonId: 26, player: const Player(id: 1, displayName: 'A'), gamesPlayed: 3, mvp: 0.4);
    final rows = buildSeasonRows(
      configs: const [
        SeasonConfig(id: 26, title: 'S26', gameLimit: 2, smallLeagueMinGames: 1, gamesMultiplier: 0, source: BundledSource(jsonFile: 'x')),
        SeasonConfig(id: 27, title: 'S27', gameLimit: 2, smallLeagueMinGames: 1, gamesMultiplier: 0, source: BundledSource(jsonFile: 'y')),
      ],
      seasons: {
        26: SeasonStats(playerStats: [a], mvpRanking: const [1], bestSheriffRanking: const [], bestDonRanking: const [],
            bestCivilianRanking: const [], bestMafiaRanking: const [], mostKilledRanking: const []),
      },
      games: [_g(true), _g(true), _g(false)],
      tournaments: const [Tournament(seasonId: 26, type: TournamentType.minicap, name: 'm', games: 4)],
      resolver: PlayerResolver(const []),
    );
    expect(rows.single.seasonId, 26);
    expect(rows.single.games, 3);
    expect(rows.single.cityWR, closeTo(2 / 3, 1e-9));
    expect(rows.single.mvp?.name, 'A');
    expect(rows.single.mostHosted?.name, 'H');
    expect(rows.single.tournaments[TournamentType.minicap], 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/season_rows_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement the builder**

```dart
// lib/services/stats/season_rows.dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';

typedef NamedValue = ({String name, num value});

class SeasonRow {
  final int seasonId, games, players, mainLeague;
  final double cityWR, mafiaWR;
  final Map<TournamentType, int> tournaments;
  final NamedValue? mostGames, mvp, mostKilled, topKilledPct, mostHosted, hostAvgPlus;
  final NamedValue? bestDon, bestSheriff, bestCivilian, bestMafia;

  const SeasonRow({
    required this.seasonId, required this.games, required this.players, required this.mainLeague,
    required this.cityWR, required this.mafiaWR, required this.tournaments,
    this.mostGames, this.mvp, this.mostKilled, this.topKilledPct, this.mostHosted, this.hostAvgPlus,
    this.bestDon, this.bestSheriff, this.bestCivilian, this.bestMafia,
  });
}

double _roleWr(RatingPlayerStats p, Role role) {
  bool isRole(String v) => role.sheetValues.contains(v);
  final g = p.gamesForRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final w = p.winByRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  return g == 0 ? 0 : w / g;
}

List<SeasonRow> buildSeasonRows({
  required List<SeasonConfig> configs,
  required Map<int, SeasonStats> seasons,
  required List<Game> games,
  required List<Tournament> tournaments,
  required PlayerResolver resolver,
}) {
  final rows = <SeasonRow>[];
  for (final c in configs) {
    final stats = seasons[c.id];
    if (stats == null) continue;
    final seasonGames = games.where((g) => g.seasonId == c.id).toList();
    final byId = {for (final p in stats.playerStats) p.player.id: p};
    RatingPlayerStats? winner(List<int> r) => r.isEmpty ? null : byId[r.first];
    NamedValue? named(RatingPlayerStats? p, num Function(RatingPlayerStats) v) =>
        p == null ? null : (name: p.player.displayName, value: v(p));

    final main = stats.playerStats.where((p) => p.gamesPlayed >= c.gameLimit).toList();
    final extra = buildSeasonExtraStats(
      leaguePlayers: main,
      seasonGames: seasonGames,
      seasonTournaments: tournaments.where((t) => t.seasonId == c.id).toList(),
      resolver: resolver,
    );
    final city = seasonGames.where((g) => g.cityWon == true).length;
    final decided = seasonGames.where((g) => g.cityWon != null).length;

    rows.add(SeasonRow(
      seasonId: c.id,
      games: seasonGames.length,
      players: seasonGames.getPlayersList(c.id).length,
      mainLeague: leagueCounts(stats.playerStats, c).main,
      cityWR: decided == 0 ? 0 : city / decided,
      mafiaWR: decided == 0 ? 0 : (decided - city) / decided,
      tournaments: extra.tournaments,
      mostGames: extra.mostGames.isEmpty ? null : named(extra.mostGames.first, (p) => p.gamesPlayed),
      mvp: named(winner(stats.mvpRanking), (p) => p.mvp),
      mostKilled: named(winner(stats.mostKilledRanking), (p) => p.firstKilled),
      topKilledPct: extra.topFirstKilledPct.isEmpty ? null : named(extra.topFirstKilledPct.first, (p) => p.percentOfDeath),
      mostHosted: extra.mostHosted.isEmpty ? null : (name: extra.mostHosted.first.host.displayName, value: extra.mostHosted.first.hosted),
      hostAvgPlus: extra.hostAvgPlus.isEmpty ? null : (name: extra.hostAvgPlus.first.host.displayName, value: extra.hostAvgPlus.first.avgPlus),
      bestDon: named(winner(stats.bestDonRanking), (p) => _roleWr(p, Role.don)),
      bestSheriff: named(winner(stats.bestSheriffRanking), (p) => _roleWr(p, Role.sheriff)),
      bestCivilian: named(winner(stats.bestCivilianRanking), (p) => _roleWr(p, Role.civilian)),
      bestMafia: named(winner(stats.bestMafiaRanking), (p) => _roleWr(p, Role.mafia)),
    ));
  }
  return rows;
}
```

Run: `flutter test test/services/stats/season_rows_test.dart`
Expected: PASS.

- [ ] **Step 4: Add the provider**

In `dashboard_providers.dart`, append the provider below. Add imports for `season_repository.dart`, `services/stats/season_rows.dart` and `screens/home/home_providers.dart` (for `playerResolverProvider`).

```dart
/// One row per loaded season for the dashboard comparison table.
final seasonRowsProvider = Provider<List<SeasonRow>>((ref) => buildSeasonRows(
      configs: ref.watch(loadedSeasonConfigsProvider),
      seasons: ref.watch(seasonRepositoryProvider),
      games: ref.watch(gamesRepositoryProvider),
      tournaments: ref.watch(tournamentsProvider),
      resolver: ref.watch(playerResolverProvider),
    ));
```

- [ ] **Step 5: Build the card and the full-screen table**

```dart
// lib/screens/dashboard/seasons_table.dart
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

SortableColumn<SeasonRow> _named(String label, NamedValue? Function(SeasonRow) f, String Function(num) fmt) =>
    SortableColumn(
      label: label,
      width: 120,
      text: (r) => f(r) == null ? '—' : '${f(r)!.name} ${fmt(f(r)!.value)}',
      sortValue: (r) => f(r)?.value ?? -1,
    );

List<SortableColumn<SeasonRow>> _columns() => [
      SortableColumn(label: 'Season', width: 58, text: (r) => 'S${r.seasonId}', sortValue: (r) => r.seasonId),
      SortableColumn(label: 'Games', width: 56, text: (r) => '${r.games}', sortValue: (r) => r.games),
      SortableColumn(label: 'City WR', width: 60, text: (r) => _pct(r.cityWR), sortValue: (r) => r.cityWR),
      SortableColumn(label: 'Mafia WR', width: 64, text: (r) => _pct(r.mafiaWR), sortValue: (r) => r.mafiaWR),
      SortableColumn(label: 'Players', width: 58, text: (r) => '${r.players}', sortValue: (r) => r.players),
      SortableColumn(label: 'Main lg', width: 58, text: (r) => '${r.mainLeague}', sortValue: (r) => r.mainLeague),
      for (final t in TournamentType.values)
        SortableColumn(label: '${t.label}s', width: 78, text: (r) => '${r.tournaments[t] ?? 0}', sortValue: (r) => r.tournaments[t] ?? 0),
      _named('Most games', (r) => r.mostGames, (v) => '$v'),
      _named('MVP', (r) => r.mvp, (v) => v.toStringAsFixed(2)),
      _named('Most ПУ', (r) => r.mostKilled, (v) => '$v'),
      _named('Top ПУ %', (r) => r.topKilledPct, (v) => _pct(v.toDouble())),
      _named('Most hosted', (r) => r.mostHosted, (v) => '$v'),
      _named('Host avg +', (r) => r.hostAvgPlus, (v) => v.toStringAsFixed(2)),
      _named('Best Don', (r) => r.bestDon, (v) => _pct(v.toDouble())),
      _named('Best Sheriff', (r) => r.bestSheriff, (v) => _pct(v.toDouble())),
      _named('Best Civilian', (r) => r.bestCivilian, (v) => _pct(v.toDouble())),
      _named('Best Mafia', (r) => r.bestMafia, (v) => _pct(v.toDouble())),
    ];

class SeasonsTableCard extends ConsumerWidget {
  const SeasonsTableCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(seasonRowsProvider);
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Seasons',
      trailing: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SeasonsTableScreen()),
        ),
        child: const Text('Expand'),
      ),
      child: SortableTable<SeasonRow>(
        columns: _columns(),
        rows: rows,
        initialSortIndex: 0,
        collapsedRowCount: 5,
      ),
    );
  }
}

class SeasonsTableScreen extends ConsumerWidget {
  const SeasonsTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(seasonRowsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seasons')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SortableTable<SeasonRow>(columns: _columns(), rows: rows, initialSortIndex: 0),
      ),
    );
  }
}
```

In `dashboard_screen.dart`, import `seasons_table.dart`. Right after the Club Overview `HeroCard(...)` entry in the `SliverChildListDelegate` list, insert:

```dart
              const SizedBox(height: 16),
              const SeasonsTableCard(),
```

- [ ] **Step 6: Run and look**

Run: `flutter test` then `flutter analyze`
Expected: pass / no new issues.

Run the app and open Dashboard. The Seasons card shows 5 rows, newest first. Tapping "Games" sorts. "Expand" opens all seasons.

- [ ] **Step 7: Commit**

```bash
git add lib/services/stats/season_rows.dart lib/screens/dashboard test/services/stats/season_rows_test.dart
git commit -m "feat: sortable seasons table on the dashboard"
```

---

### Task 11: Records tab

**Files:**
- Modify: `lib/providers/app_providers.dart` (`selectedTabProvider`)
- Modify: `lib/main.dart` (use the provider, add Records)
- Create: `lib/screens/records/records_providers.dart`
- Create: `lib/screens/records/records_screen.dart`
- Test: `test/screens/records/records_screen_test.dart`

**Interfaces:**
- Consumes: every function in `records.dart` (Task 8), `bestWinStreaks` (Task 7), `SortableTable` (Task 9), `playerResolverProvider` (Task 5).
- Produces:
  - `selectedTabProvider: StateProvider<int>`. Indexes: 0 Season, 1 Players, 2 Dashboard, 3 Records, 4 Chat, 5 Debug.
  - `enum RecordCategory { mvp, roles, games, hosts, firstKilled, penalties, streaks }`
  - `recordsInputProvider`, `recordCategoryProvider`, `recordPeriodProvider`, `recordAllTimeProvider`, `recordRoleProvider`.

- [ ] **Step 1: Add the tab provider and the Records destination**

In `app_providers.dart`, add:

```dart
/// Selected bottom-nav tab. 0 Season, 1 Players, 2 Dashboard, 3 Records, 4 Chat, 5 Debug.
final selectedTabProvider = StateProvider<int>((ref) => 0);
```

In `lib/main.dart`, replace the local `_index` state with `final index = ref.watch(selectedTabProvider);` and `onDestinationSelected: (i) => ref.read(selectedTabProvider.notifier).state = i`. Insert `RecordsScreen()` into `_screens` after `DashboardScreen()`, and insert this destination after Dashboard:

```dart
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Records',
              ),
```

Import `screens/records/records_screen.dart`.

- [ ] **Step 2: Providers**

```dart
// lib/screens/records/records_providers.dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecordCategory {
  mvp('MVP'), roles('Roles'), games('Games'), hosts('Hosts'),
  firstKilled('ПУ'), penalties('Penalties'), streaks('Streaks');

  const RecordCategory(this.label);
  final String label;

  bool get hasPeriod => this == mvp || this == roles || this == penalties || this == hosts;
  bool get hasAllTime => this == games || this == hosts;
}

final recordCategoryProvider = StateProvider<RecordCategory>((ref) => RecordCategory.mvp);
final recordPeriodProvider = StateProvider<PointsPeriod>((ref) => PointsPeriod.modern);
final recordAllTimeProvider = StateProvider<bool>((ref) => false);
final recordRoleProvider = StateProvider<Role>((ref) => Role.don);

final recordsInputProvider = Provider<RecordsInput>((ref) => RecordsInput(
      ratings: ref.watch(ratingRepositoryProvider),
      configs: ref.watch(loadedSeasonConfigsProvider),
      games: ref.watch(gamesRepositoryProvider),
      resolver: ref.watch(playerResolverProvider),
    ));

final winStreaksProvider = Provider<List<WinStreak>>((ref) =>
    bestWinStreaks(ref.watch(gamesRepositoryProvider), ref.watch(playerResolverProvider)));
```

(Check that `ratingRepositoryProvider` holds a `Map<int, List<RatingPlayerStats>>`. `dashboard_providers.dart:17` iterates `.values` over exactly that.)

- [ ] **Step 3: Write the failing screen test**

```dart
// test/screens/records/records_screen_test.dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/screens/records/records_screen.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows MVP rows and switches category', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        recordsInputProvider.overrideWithValue(RecordsInput(
          ratings: {
            26: [RatingPlayerStats(seasonId: 26, player: const Player(id: 1, displayName: 'Braun'),
                gamesPlayed: 50, wins: 30, winRate: 0.6, additionalPoints: 20)],
          },
          configs: const [SeasonConfig(id: 26, title: 'S26', gameLimit: 40, smallLeagueMinGames: 15,
              gamesMultiplier: 0, source: BundledSource(jsonFile: 'x'))],
          games: const [],
          resolver: PlayerResolver(const []),
        )),
        winStreaksProvider.overrideWithValue(const []),
      ],
      child: const MaterialApp(home: RecordsScreen()),
    ));
    expect(find.text('Braun'), findsOneWidget);
    await t.tap(find.text('Games'));
    await t.pump();
    expect(find.text('Braun'), findsOneWidget);
    expect(find.text('50'), findsWidgets);
  });
}
```

Run: `flutter test test/screens/records/records_screen_test.dart`
Expected: FAIL. `records_screen.dart` does not exist yet.

- [ ] **Step 4: Build the screen**

```dart
// lib/screens/records/records_screen.dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
String _f(double v) => v.toStringAsFixed(2);
String _season(int? s) => s == null ? 'All time' : 'S$s';

const _topN = 10;

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(recordCategoryProvider);
    final period = ref.watch(recordPeriodProvider);
    final allTime = ref.watch(recordAllTimeProvider);
    final role = ref.watch(recordRoleProvider);
    final input = ref.watch(recordsInputProvider);

    Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) onTap) =>
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final v in values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label(v)),
                  selected: v == selected,
                  onSelected: (_) => onTap(v),
                ),
              ),
          ]),
        );

    final table = switch (category) {
      RecordCategory.mvp => SortableTable<MvpRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: mvpRecords(input, period),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Доп/game', width: 70, text: (r) => _f(r.addPerGame), sortValue: (r) => r.addPerGame),
            SortableColumn(label: 'Max', width: 50, text: (r) => _f(r.maxSingleAdd), sortValue: (r) => r.maxSingleAdd),
            SortableColumn(label: 'Total', width: 56, text: (r) => r.totalAdd.toStringAsFixed(1), sortValue: (r) => r.totalAdd),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.roles => SortableTable<RoleRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: roleRecords(input, role, period),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Pts/game', width: 66, text: (r) => _f(r.pointsPerGame), sortValue: (r) => r.pointsPerGame),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Games', width: 54, text: (r) => '${r.games}', sortValue: (r) => r.games),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.games => SortableTable<GamesRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: gamesRecords(input, allTime: allTime),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Games', width: 56, text: (r) => '${r.games}', sortValue: (r) => r.games),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 64, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId ?? -1),
          ]),
      RecordCategory.hosts => SortableTable<HostRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: hostRecords(input, allTime: allTime, period: period),
          columns: [
            SortableColumn(label: 'Host', width: 130, text: (r) => r.host.displayName),
            SortableColumn(label: 'Hosted', width: 58, text: (r) => '${r.hosted}', sortValue: (r) => r.hosted),
            SortableColumn(label: 'Avg +', width: 54,
                text: (r) => r.hosted >= kHostMinGamesForAverage ? _f(r.avgPlus) : '—',
                sortValue: (r) => r.hosted >= kHostMinGamesForAverage ? r.avgPlus : -99),
            SortableColumn(label: 'Avg −', width: 54,
                text: (r) => r.hosted >= kHostMinGamesForAverage ? _f(r.avgMinus) : '—',
                sortValue: (r) => r.hosted >= kHostMinGamesForAverage ? -r.avgMinus : -99),
            SortableColumn(label: 'Season', width: 64, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId ?? -1),
          ]),
      RecordCategory.firstKilled => SortableTable<FirstKillRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: firstKillRecords(input),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'ПУ', width: 44, text: (r) => '${r.count}', sortValue: (r) => r.count),
            SortableColumn(label: '% of red', width: 62, text: (r) => _pct(r.pct), sortValue: (r) => r.pct),
            SortableColumn(label: 'Red games', width: 70, text: (r) => '${r.redGames}', sortValue: (r) => r.redGames),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.penalties => SortableTable<PenaltyRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: penaltyRecords(input, period),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            // Negated so "most minus" sorts first when descending.
            SortableColumn(label: 'Minus/game', width: 76, text: (r) => _f(r.minusPerGame), sortValue: (r) => -r.minusPerGame),
            SortableColumn(label: 'Max', width: 50, text: (r) => _f(r.maxSingleMinus), sortValue: (r) => -r.maxSingleMinus),
            SortableColumn(label: 'Total', width: 56, text: (r) => r.totalMinus.toStringAsFixed(1), sortValue: (r) => -r.totalMinus),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.streaks => SortableTable<WinStreak>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: ref.watch(winStreaksProvider),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Wins in a row', width: 96, text: (r) => '${r.length}', sortValue: (r) => r.length),
            SortableColumn(label: 'Seasons', width: 80, text: (r) => r.seasonsLabel, sortValue: (r) => r.fromSeason),
          ]),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Records'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          chips(RecordCategory.values, category, (c) => c.label,
              (c) => ref.read(recordCategoryProvider.notifier).state = c),
          const SizedBox(height: 8),
          if (category == RecordCategory.roles)
            chips(Role.values, role, (r) => r.name[0].toUpperCase() + r.name.substring(1),
                (r) => ref.read(recordRoleProvider.notifier).state = r),
          if (category.hasAllTime)
            chips([false, true], allTime, (v) => v ? 'All time' : 'Per season',
                (v) => ref.read(recordAllTimeProvider.notifier).state = v),
          if (category.hasPeriod)
            chips(PointsPeriod.values, period, (p) => p.label,
                (p) => ref.read(recordPeriodProvider.notifier).state = p),
          const SizedBox(height: 8),
          SectionCard(
            title: category.label,
            trailing: Text(
              category == RecordCategory.streaks || (category.hasAllTime && allTime)
                  ? 'All players'
                  : 'Main league only',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            child: table,
          ),
        ],
      ),
    );
  }
}
```

Every table uses the same convention: a "Player" (or "Host") first column plus a separate "Season" column.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/screens/records/records_screen_test.dart` then `flutter test`
Expected: PASS.

Run: `flutter analyze`
Expected: no new issues.

Run the app. Records is in the bottom nav. Every category renders. Period, All time and Role chips change the table. "Show all" expands the list.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/app_providers.dart lib/main.dart lib/screens/records test/screens/records
git commit -m "feat: Records tab"
```

---

### Task 12: Player profile Leagues section

**Files:**
- Create: `lib/services/stats/player_leagues.dart`
- Modify: `lib/screens/players/players_providers.dart` (`playerLeaguesProvider`)
- Create: `lib/screens/players/src/leagues_section.dart`
- Modify: `lib/screens/players/player_profile_screen.dart` (part + section after Accomplishments)
- Test: `test/services/stats/player_leagues_test.dart`

**Interfaces:**
- Consumes: `selectedTabProvider` (Task 11), `selectedSeasonProvider` (existing), `personKey` (Task 4).
- Produces:
  - `enum SeasonLeague { main, small, below, none }`
  - `Map<int, SeasonLeague> leaguesForPlayer(Player player, Map<int, List<RatingPlayerStats>> ratings, List<SeasonConfig> configs)`, with one entry per config.
  - `playerLeaguesProvider: Provider.family<Map<int, SeasonLeague>, Player>`

- [ ] **Step 1: Write the failing test**

```dart
// test/services/stats/player_leagues_test.dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_leagues.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _c(int id) => SeasonConfig(id: id, title: 'S$id', gameLimit: 40, smallLeagueMinGames: 15,
    gamesMultiplier: 0, source: const BundledSource(jsonFile: 'x'));

void main() {
  const me = Player(id: 3, displayName: 'Braun');
  RatingPlayerStats r(int s, int g) => RatingPlayerStats(seasonId: s, player: me, gamesPlayed: g);

  test('classifies every configured season', () {
    final leagues = leaguesForPlayer(
      me,
      {1: [r(1, 40)], 2: [r(2, 39)], 3: [r(3, 14)]},
      [_c(1), _c(2), _c(3), _c(4)],
    );
    expect(leagues, {
      1: SeasonLeague.main,
      2: SeasonLeague.small,
      3: SeasonLeague.below,
      4: SeasonLeague.none,
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/services/stats/player_leagues_test.dart`
Expected: FAIL. The import does not exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/services/stats/player_leagues.dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

enum SeasonLeague { main, small, below, none }

Map<int, SeasonLeague> leaguesForPlayer(
  Player player,
  Map<int, List<RatingPlayerStats>> ratings,
  List<SeasonConfig> configs,
) {
  final key = personKey(player);
  return {
    for (final c in configs)
      c.id: () {
        final games = (ratings[c.id] ?? const [])
            .where((p) => personKey(p.player) == key)
            .fold(0, (s, p) => s + p.gamesPlayed);
        if (games == 0) return SeasonLeague.none;
        if (games >= c.gameLimit) return SeasonLeague.main;
        if (games >= c.smallLeagueMinGames) return SeasonLeague.small;
        return SeasonLeague.below;
      }(),
  };
}
```

Run: `flutter test test/services/stats/player_leagues_test.dart`
Expected: PASS.

- [ ] **Step 4: Provider and section**

In `players_providers.dart`, add:

```dart
final playerLeaguesProvider =
    Provider.family<Map<int, SeasonLeague>, Player>((ref, player) => leaguesForPlayer(
          player,
          ref.watch(ratingRepositoryProvider),
          [...ref.watch(loadedSeasonConfigsProvider)]..sort((a, b) => a.id.compareTo(b.id)),
        ));
```

Import `services/stats/player_leagues.dart`. The spread copy matters: sorting the provider's own list in place would mutate shared state.

```dart
// lib/screens/players/src/leagues_section.dart
part of '../player_profile_screen.dart';

class _LeaguesSection extends ConsumerWidget {
  final Player player;

  const _LeaguesSection({required this.player});

  static const _colors = {
    SeasonLeague.main: Color(0xFF00897B),
    SeasonLeague.small: Color(0xFF80CBC4),
    SeasonLeague.below: Color(0xFFECEFF1),
    SeasonLeague.none: Colors.transparent,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leagues = ref.watch(playerLeaguesProvider(player));
    final main = leagues.values.where((l) => l == SeasonLeague.main).length;
    final small = leagues.values.where((l) => l == SeasonLeague.small).length;
    final configs = ref.watch(loadedSeasonConfigsProvider);

    Widget big(String value, String label, Color bg) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF004D40))),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          ),
        );

    return SectionCard(
      title: 'Leagues',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          big('$main', 'seasons in main league', const Color(0xFFE0F2F1)),
          const SizedBox(width: 8),
          big('$small', 'seasons in small league', const Color(0xFFF1F8F7)),
        ]),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final MapEntry(key: season, value: league) in leagues.entries)
              GestureDetector(
                onTap: league == SeasonLeague.none
                    ? null
                    : () {
                        final config = configs.where((c) => c.id == season).firstOrNull;
                        if (config == null) return;
                        ref.read(selectedSeasonProvider.notifier).state = config;
                        ref.read(selectedTabProvider.notifier).state = 0;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _colors[league],
                    borderRadius: BorderRadius.circular(4),
                    border: league == SeasonLeague.none
                        ? Border.all(color: const Color(0xFFCFD8DC))
                        : null,
                  ),
                  child: Text('$season',
                      style: TextStyle(
                        fontSize: 7,
                        color: league == SeasonLeague.main ? Colors.white : const Color(0xFF90A4AE),
                      )),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Wrap(spacing: 12, children: [
          _Legend(color: Color(0xFF00897B), label: 'Main'),
          _Legend(color: Color(0xFF80CBC4), label: 'Small'),
          _Legend(color: Color(0xFFECEFF1), label: 'Played, below threshold'),
          _Legend(color: Colors.transparent, label: "Didn't play", outlined: true),
        ]),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _Legend({required this.color, required this.label, this.outlined = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            border: outlined ? Border.all(color: const Color(0xFFCFD8DC)) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ]);
}
```

In `player_profile_screen.dart`:
- add `part 'src/leagues_section.dart';` and `import 'package:family_mafia_app/services/stats/player_leagues.dart';`;
- right after the Accomplishments block (`if (acc.sumOfNominations() > 0 || !isFullyLoaded) ...[ ... ]`), insert:

```dart
              _LeaguesSection(player: player),
              const SizedBox(height: 16),
```

(`player` is the screen's `Player` field. Check its name at the top of `PlayerProfileScreen`.)

- [ ] **Step 5: Run and look**

Run: `flutter test` then `flutter analyze`
Expected: pass / no new issues.

Run the app and open a long-time player. Leagues shows two counts and one cell per season. Tapping a coloured cell opens that season on the Season tab.

- [ ] **Step 6: Commit**

```bash
git add lib/services/stats/player_leagues.dart lib/screens/players test/services/stats/player_leagues_test.dart
git commit -m "feat: Leagues section in player profile"
```

---

### Task 13: Verify against the club's sheets

**Files:** none (verification only).

- [ ] **Step 1: Full test and analyze**

Run: `flutter test`
Expected: all pass.

Run: `flutter analyze`
Expected: no new issues compared with `master`.

- [ ] **Step 2: Spot-check the numbers in the running app**

| Where | Check | Expected (from the sheets survey) |
|---|---|---|
| Season 2 → Season Stats → No host | games without host | small (source: 202 of 213 had a host) |
| Season 16 → Most Hosted | top host | Скай (47), Floppy (40), Луна (38) |
| Season 0 → No host | label | "No data" |
| Season 25 hero | Tournaments | 8 |
| Dashboard → Seasons → sort Minicaps | top | S23 (7) |
| Records → Hosts → All time | merges Seezov / Сізов | one row |

If a number is off, fix the owning task's function and add a test for the case.

- [ ] **Step 3: Commit any fixes, then report**

```bash
git status
```

Expected: clean tree.
