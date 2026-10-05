# Dynamic Game Threshold Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A `top3` season's main-league threshold follows the sheet's formula while the season is played, freezes when it ends, and an admin can override the final value on `/debug/`.

**Architecture:** A pure `effectiveThreshold` (Dart) decides the limit from the season's rating-game counts, its game dates and a clock. The loader isolate resolves it per season right after parsing, before any rating or stats code reads `gameLimit`, and returns it; the app/site loaders write it back into `SeasonConfig` (`gameLimit`, `thresholdFormula`, `thresholdLive`), so every existing consumer sees the effective int limit unchanged. The site shows the live value; an admin's final value lives in Firestore `config/club.gameLimits` (see the club-config plan, already shipped) and is merged into the season configs before loading.

**Tech Stack:** Dart/Flutter + Riverpod, `flutter_test`; Astro + TypeScript, vitest.

**Spec:** `docs/superpowers/specs/2026-10-05-dynamic-threshold-design.md`

## Global Constraints

- Formula: `(g1 + g2 + g3) / 3 × 0.6 − 5`, g = rating-game counts of the 3 most active players; missing players count 0.
- Main league: `gamesPlayed >= threshold` ⇒ int limit = `ceil(threshold)`, never below 0. Round the formula to 6 decimals before `ceil` (float noise: 55.0 must stay 55).
- In progress = `seasonInProgress(gameDates, now: now)` from `lib/services/stats/accomplishments.dart` (existing).
- Ended `top3` season: the admin's value from `config/club.gameLimits["<id>"]` if present, else `ceil(formula)`. The season JSON config never holds the admin value.
- `fixed` seasons (default; S0–30) behave exactly as today.
- Config: `"gameLimitRule": "top3"`; S31 in both `remote_config.json` and `assets/raw/season_config.json` gets it and loses `"gameLimit": 40`.
- Site chrome is English (match surrounding copy). Numbers shown with one decimal (`15.4`).
- Push both `feature/flutter_migration` and `master` only when the user says so.

## Review Focus

1. Float noise at an exact integer (S28: 300/3·0.6−5) — must give 55, not 56. Pinned in Task 1.
2. A `top3` season with < 3 players or no dated games (first evening, typo dates) — no crash; no dates ⇒ not in progress. Pinned in Task 1.
3. The initial load (latest season only) and background load use different loader instances — the latest season must keep its effective limit after the background load replaces `loadedSeasonConfigsProvider`. Pinned in Task 3 (both configs come from `withThreshold`).
4. An admin value in `config/club.gameLimits` must reach the loader for the latest season too (initial load), not only the background load. Pinned in Task 3 (`applyAdminLimits` used by both).
5. Sheet-path seasons (< 31) use `meta.gameLimit` in `_seasonData`'s main-league merge — it must be the effective limit. Pinned in Task 3 (S28 loader test).

---

### Task 1: Threshold rule (pure)

**Files:**
- Create: `lib/enums/game_limit_rule.dart`
- Create: `lib/services/stats/threshold.dart`
- Test: `test/services/stats/threshold_test.dart`

**Interfaces:**
- Produces:
  - `enum GameLimitRule { fixed, top3 }` with `static GameLimitRule parse(String? s)` (`'top3'` → top3, else fixed).
  - `typedef SeasonThreshold = ({int gameLimit, double? formula, bool live});`
  - `double formulaThreshold(Iterable<int> ratingGames)`
  - `SeasonThreshold effectiveThreshold({required GameLimitRule rule, required int? configured, required Iterable<int> ratingGames, required List<DateTime> gameDates, required DateTime now})`

- [ ] **Step 1: Write the failing test** — `test/services/stats/threshold_test.dart`:

```dart
import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/services/stats/threshold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formulaThreshold', () {
    test('matches the sheets', () {
      expect(formulaThreshold([122, 91, 87, 54]), 55.0); // S28
      expect(formulaThreshold([102, 87, 87]), closeTo(50.2, 1e-9)); // S29
      expect(formulaThreshold([93, 70, 65, 12]), closeTo(40.6, 1e-9)); // S30
      expect(formulaThreshold([40, 38, 24, 17, 3]), closeTo(15.4, 1e-9)); // S31
    });
    test('fewer than 3 players count as 0', () {
      expect(formulaThreshold([10]), closeTo(-3.0, 1e-9));
      expect(formulaThreshold([]), -5.0);
    });
  });

  group('effectiveThreshold', () {
    final oct = DateTime.utc(2026, 10, 5);
    final s31Dates = [DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 15), DateTime.utc(2026, 10, 3)];
    SeasonThreshold eff({GameLimitRule rule = GameLimitRule.top3, int? configured, List<int> games = const [40, 38, 24], List<DateTime>? dates, DateTime? now}) =>
        effectiveThreshold(rule: rule, configured: configured, ratingGames: games, gameDates: dates ?? s31Dates, now: now ?? oct);

    test('in progress: formula, rounded up, live', () {
      final t = eff(configured: 40);
      expect(t.gameLimit, 16);
      expect(t.formula, closeTo(15.4, 1e-9));
      expect(t.live, isTrue);
    });
    test('exact integer is not pushed up by float noise', () {
      expect(eff(games: [122, 91, 87]).gameLimit, 55);
    });
    test('ended without a configured value: ceil(formula)', () {
      final t = eff(now: DateTime.utc(2026, 12, 1));
      expect((t.gameLimit, t.live), (16, false));
      expect(t.formula, closeTo(15.4, 1e-9));
    });
    test('ended with the admin value', () {
      expect(eff(configured: 15, now: DateTime.utc(2026, 12, 1)).gameLimit, 15);
    });
    test('negative formula is 0', () {
      expect(eff(games: [1, 1]).gameLimit, 0);
    });
    test('no dated games: not in progress', () {
      final t = eff(dates: const []);
      expect(t.live, isFalse);
      expect(t.gameLimit, 16);
    });
    test('fixed rule ignores the formula', () {
      final t = eff(rule: GameLimitRule.fixed, configured: 40);
      expect((t.gameLimit, t.formula, t.live), (40, null, false));
    });
  });

  test('GameLimitRule.parse', () {
    expect(GameLimitRule.parse('top3'), GameLimitRule.top3);
    expect(GameLimitRule.parse(null), GameLimitRule.fixed);
    expect(GameLimitRule.parse('other'), GameLimitRule.fixed);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/services/stats/threshold_test.dart`
Expected: FAIL (files don't exist).

- [ ] **Step 3: Implement**

`lib/enums/game_limit_rule.dart`:

```dart
/// How a season's main-league threshold is set.
enum GameLimitRule {
  /// `gameLimit` from the config.
  fixed,

  /// The sheet's «Поточний поріг» formula while the season is played; at the
  /// end the config's `gameLimit` (admin) or the rounded-up formula.
  top3;

  static GameLimitRule parse(String? s) => s == 'top3' ? top3 : fixed;
}
```

`lib/services/stats/threshold.dart`:

```dart
import 'dart:math';

import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/services/stats/accomplishments.dart';

/// A season's effective main-league threshold: the int limit every league
/// split compares against, the formula value (top3 seasons only) and whether
/// it is still moving (season in progress).
typedef SeasonThreshold = ({int gameLimit, double? formula, bool live});

/// The sheet's «Поточний поріг»: the three highest rating-game counts,
/// averaged, × 0.6 − 5 (missing players count 0). Rounded to 6 decimals so
/// float noise never lifts an exact integer over the next `ceil`.
double formulaThreshold(Iterable<int> ratingGames) {
  final top = ratingGames.toList()..sort((a, b) => b.compareTo(a));
  final sum = top.take(3).fold(0, (s, g) => s + g);
  return (((sum / 3) * 0.6 - 5) * 1e6).round() / 1e6;
}

/// See [GameLimitRule]. A player is in the main league with
/// `gamesPlayed >= formula`, i.e. `>= ceil(formula)`.
SeasonThreshold effectiveThreshold({
  required GameLimitRule rule,
  required int? configured,
  required Iterable<int> ratingGames,
  required List<DateTime> gameDates,
  required DateTime now,
}) {
  if (rule == GameLimitRule.fixed) {
    return (gameLimit: configured!, formula: null, live: false);
  }
  final formula = formulaThreshold(ratingGames);
  final rounded = max(0, formula.ceil());
  final live = seasonInProgress(gameDates, now: now);
  return (
    gameLimit: live ? rounded : configured ?? rounded,
    formula: formula,
    live: live,
  );
}
```

- [ ] **Step 4: Run the test** — `flutter test test/services/stats/threshold_test.dart` → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/enums/game_limit_rule.dart lib/services/stats/threshold.dart test/services/stats/threshold_test.dart
git commit -m "feat: sheet threshold formula and effective game limit"
```

---

### Task 2: Season config carries the rule

**Files:**
- Modify: `lib/models/season_config.dart`
- Modify: `remote_config.json:35`, `assets/raw/season_config.json:35` (S31 line)
- Test: `test/models/season_config_test.dart` (create if missing; else add a group)

**Interfaces:**
- Consumes: `GameLimitRule`, `SeasonThreshold` (Task 1).
- Produces on `SeasonConfig`:
  - `final GameLimitRule gameLimitRule;` (default `fixed`)
  - `final bool gameLimitSet;` (config JSON had `gameLimit`; default `true`)
  - `final double? thresholdFormula;` `final bool thresholdLive;` (default `null` / `false`)
  - `SeasonConfig withThreshold(SeasonThreshold t)` — same config with `gameLimit: t.gameLimit`, `thresholdFormula: t.formula`, `thresholdLive: t.live`.
  - `SeasonConfig withAdminLimit(int limit)` — same config with `gameLimit: limit`, `gameLimitSet: true`.
  - top-level `List<SeasonConfig> applyAdminLimits(List<SeasonConfig> configs, Map<int, int> limits)` — each `top3` config with an entry in [limits] → `withAdminLimit`; others unchanged (a `fixed` season ignores club limits).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> json(Map<String, dynamic> extra) => {
        'id': 31, 'title': 'Season 31', 'gamesMultiplier': 0.0,
        'source': 'bundled', 'jsonFile': 'x.json', ...extra,
      };

  test('top3 without gameLimit', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}));
    expect(c.gameLimitRule, GameLimitRule.top3);
    expect(c.gameLimitSet, isFalse);
    expect(c.toJson().containsKey('gameLimit'), isFalse);
    expect(c.toJson()['gameLimitRule'], 'top3');
  });

  test('top3 with the admin value', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3', 'gameLimit': 41}));
    expect((c.gameLimit, c.gameLimitSet), (41, true));
  });

  test('fixed is the default and needs gameLimit', () {
    final c = SeasonConfig.fromJson(json({'gameLimit': 40}));
    expect(c.gameLimitRule, GameLimitRule.fixed);
    expect(c.toJson().containsKey('gameLimitRule'), isFalse);
    expect(() => SeasonConfig.fromJson(json({})), throwsFormatException);
  });

  test('admin limits from config/club apply to top3 seasons only', () {
    final top3 = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}));
    final fixed = SeasonConfig.fromJson(json({'id': 30, 'gameLimit': 40}));
    final out = applyAdminLimits([top3, fixed], {31: 41, 30: 99});
    expect((out[0].gameLimit, out[0].gameLimitSet), (41, true));
    expect(out[1].gameLimit, 40);
    expect(applyAdminLimits([top3], {}).single.gameLimitSet, isFalse);
  });

  test('withThreshold', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}))
        .withThreshold((gameLimit: 16, formula: 15.4, live: true));
    expect((c.gameLimit, c.thresholdFormula, c.thresholdLive, c.gameLimitSet), (16, 15.4, true, false));
    expect(c.title, 'Season 31');
  });
}
```

- [ ] **Step 2: Run** `flutter test test/models/season_config_test.dart` → FAIL.

- [ ] **Step 3: Implement** in `lib/models/season_config.dart`:
  - Add the four fields to the class and constructor as optional named params with the defaults above (`this.gameLimitRule = GameLimitRule.fixed, this.gameLimitSet = true, this.thresholdFormula, this.thresholdLive = false`). Doc comments: `gameLimitSet` — "whether the config sets `gameLimit`; for a top3 season that is the admin's final value"; `thresholdFormula`/`thresholdLive` — "filled by the loader (see `effectiveThreshold`)".
  - `fromJson`:

```dart
    final rule = GameLimitRule.parse(json['gameLimitRule'] as String?);
    final limit = json['gameLimit'] as int?;
    if (limit == null && rule == GameLimitRule.fixed) {
      throw FormatException('Season ${json['id']}: gameLimit is missing');
    }
    ...
      gameLimit: limit ?? 0,
      gameLimitRule: rule,
      gameLimitSet: limit != null,
```

  - `toJson`: write `'gameLimit'` only when `gameLimitSet`; add `'gameLimitRule': 'top3'` when the rule is top3. Do not write the threshold fields (loader output, not config).
  - `withThreshold`:

```dart
  SeasonConfig withThreshold(SeasonThreshold t) => SeasonConfig(
        id: id, title: title, gameLimit: t.gameLimit,
        smallLeagueMinGames: smallLeagueMinGames, gamesMultiplier: gamesMultiplier,
        source: source, gameLimitRule: gameLimitRule, gameLimitSet: gameLimitSet,
        thresholdFormula: t.formula, thresholdLive: t.live,
      );
```

  - `withAdminLimit` (like `withThreshold`, but `gameLimit: limit, gameLimitSet: true`, threshold fields kept) and

```dart
/// [configs] with admins' final thresholds from `config/club.gameLimits`;
/// only top3 seasons take them.
List<SeasonConfig> applyAdminLimits(List<SeasonConfig> configs, Map<int, int> limits) => [
      for (final c in configs)
        if (c.gameLimitRule == GameLimitRule.top3 && limits[c.id] != null)
          c.withAdminLimit(limits[c.id]!)
        else
          c,
    ];
```

  - Check `SeasonConfig(` call sites still compile (`grep -rn "SeasonConfig(" lib test tool`); `Season.toConfig()` needs no change (fixed default).
- [ ] **Step 4: Config files.** In both `remote_config.json` and `assets/raw/season_config.json`, the S31 line: replace `"gameLimit": 40, ` with `"gameLimitRule": "top3", `. Keep the rest of the line and file byte for byte.
- [ ] **Step 5: Run** `flutter test test/models/season_config_test.dart` → PASS; `flutter analyze` clean.
- [ ] **Step 6: Commit**

```bash
git add lib/models/season_config.dart test/models/season_config_test.dart remote_config.json assets/raw/season_config.json
git commit -m "feat: season config gameLimitRule; S31 uses the sheet formula"
```

---

### Task 3: Loader resolves the effective threshold

**Files:**
- Modify: `lib/services/src/isolate_io.dart` (SeasonMeta, outputs)
- Modify: `lib/services/src/isolate_functions.dart` (`_seasonData`, `_computePartialData`, `_computeAllData`)
- Modify: `lib/services/season_loader.dart` (imports, `seasonMetaFor`, `thresholds`, `applyThresholds`)
- Modify: `lib/providers/app_providers.dart` (metas + configs; `clockProvider` moves here)
- Modify: `lib/screens/players/players_providers.dart` (remove `clockProvider`, keep using it from app_providers)
- Modify: `test/site_export/fixture.dart`
- Test: `test/services/season_threshold_load_test.dart`

**Interfaces:**
- Consumes: Task 1 (`effectiveThreshold`, `SeasonThreshold`, `GameLimitRule`), Task 2 (`SeasonConfig.withThreshold`, `gameLimitRule`, `gameLimitSet`).
- Produces:
  - `SeasonMeta(id, gameLimit, gamesMultiplier, {GameLimitRule rule = GameLimitRule.fixed, bool gameLimitSet = true, DateTime? now})` — existing positional calls keep working.
  - `SeasonMeta seasonMetaFor(SeasonConfig c, DateTime now)` (top-level, `season_loader.dart`).
  - `SeasonLoaderService.thresholds` — `Map<int, SeasonThreshold>`, filled by `loadAll`/`loadSeasons`.
  - `List<SeasonConfig> SeasonLoaderService.applyThresholds(List<SeasonConfig> configs)` — each config with a recorded threshold → `withThreshold`, others unchanged.
  - `clockProvider` (`Provider<DateTime Function()>`) now lives in `lib/providers/app_providers.dart`.

- [ ] **Step 1: Write the failing test** — `test/services/season_threshold_load_test.dart`. S28 is bundled (`assets/raw/season28.json`); its games run Jan 2025 typo + Dec 2025–Feb 2026, so it is in progress on 2026-02-01 and ended on 2026-10-05.

```dart
import 'dart:io';

import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SeasonLoaderService> load(SeasonMeta meta) async {
    final loader = SeasonLoaderService(PlayersRepository(), GamesRepository(),
        RatingRepository(), SeasonRepository(), RolePercentilesRepository());
    await loader.loadSeasons(
      metas: [meta],
      playersJson: File('assets/raw/players.json').readAsStringSync(),
      seasonJsons: [File('assets/raw/season28.json').readAsStringSync()],
    );
    return loader;
  }

  test('top3 season in progress: live formula', () async {
    final l = await load(SeasonMeta(28, 0, 0.0,
        rule: GameLimitRule.top3, gameLimitSet: false, now: DateTime.utc(2026, 2, 1)));
    final t = l.thresholds[28]!;
    expect((t.gameLimit, t.formula, t.live), (55, 55.0, true));
  });

  test('top3 season ended with the admin value', () async {
    final l = await load(SeasonMeta(28, 54, 0.0,
        rule: GameLimitRule.top3, now: DateTime.utc(2026, 10, 5)));
    final t = l.thresholds[28]!;
    expect((t.gameLimit, t.live), (54, false));
  });

  test('the effective limit drives the main league', () async {
    final loader = SeasonLoaderService(PlayersRepository(), GamesRepository(),
        RatingRepository(), SeasonRepository(), RolePercentilesRepository());
    final players = File('assets/raw/players.json').readAsStringSync();
    final json = File('assets/raw/season28.json').readAsStringSync();
    final fixed = seasonStandingsForTest(const SeasonMeta(28, 55, 0.0), players, json);
    final top3 = seasonStandingsForTest(
        SeasonMeta(28, 0, 0.0, rule: GameLimitRule.top3, gameLimitSet: false, now: DateTime.utc(2026, 10, 5)),
        players, json);
    expect(top3.map((p) => p.player.displayName), fixed.map((p) => p.player.displayName));
    expect(loader.thresholds, isEmpty);
  });

  test('fixed seasons record their configured limit', () async {
    final l = await load(const SeasonMeta(28, 55, 0.0));
    expect(l.thresholds[28], (gameLimit: 55, formula: null, live: false));
  });
}
```

- [ ] **Step 2: Run** `flutter test test/services/season_threshold_load_test.dart` → FAIL (named params / `thresholds` missing).

- [ ] **Step 3: `isolate_io.dart`.** Extend `SeasonMeta`:

```dart
class SeasonMeta {
  final int id;
  final int gameLimit;
  final double gamesMultiplier;
  final GameLimitRule rule;

  /// Whether [gameLimit] came from the config (for a top3 season: the
  /// admin's final value); a top3 season without one passes 0 and false.
  final bool gameLimitSet;

  /// The clock for [seasonInProgress]; null = now.
  final DateTime? now;

  const SeasonMeta(this.id, this.gameLimit, this.gamesMultiplier,
      {this.rule = GameLimitRule.fixed, this.gameLimitSet = true, this.now});

  SeasonMeta withGameLimit(int limit) => SeasonMeta(id, limit, gamesMultiplier,
      rule: rule, gameLimitSet: gameLimitSet, now: now);
}
```

Add `final Map<int, SeasonThreshold> thresholds;` (required) to both `_LoadOutput` and `_PartialLoadOutput`.

- [ ] **Step 4: `season_loader.dart` imports** — add `package:family_mafia_app/enums/game_limit_rule.dart`, `package:family_mafia_app/models/season_config.dart`, `package:family_mafia_app/services/stats/threshold.dart`.

- [ ] **Step 5: `isolate_functions.dart`.** Add, above `_seasonData`:

```dart
/// [meta]'s effective threshold from its rating games (see [effectiveThreshold]).
SeasonThreshold _threshold(SeasonMeta meta, List<Game> games) {
  final counts = <String, int>{};
  for (final g in games) {
    for (final p in g.players) {
      if (!p.startsWith('_blank_')) counts[p] = (counts[p] ?? 0) + 1;
    }
  }
  return effectiveThreshold(
    rule: meta.rule,
    configured: meta.gameLimitSet ? meta.gameLimit : null,
    ratingGames: counts.values,
    gameDates: [for (final g in games) if (g.date != null) g.date!],
    now: meta.now ?? DateTime.now(),
  );
}
```

Change `_seasonData` to take `SeasonMeta season` and start:

```dart
({List<Game> games, List<RatingPlayerStats> ratings, SeasonThreshold threshold}) _seasonData(
    SeasonMeta season, String json, PlayerResolver resolver, List<Player> players) {
  final games = _ratingGames(season.id, json, resolver);
  final threshold = _threshold(season, games);
  // Everything below (ratings, the sheet's main-league merge) reads the
  // effective limit.
  final meta = season.withGameLimit(threshold.gameLimit);
```

and return `threshold: threshold` in both returns. In `_computePartialData` and `_computeAllData`: destructure `(:games, :ratings, :threshold)`, keep `thresholds[meta.id] = threshold;` in a new `final thresholds = <int, SeasonThreshold>{};`, call `_generateSeasonStats(sorted, threshold.gameLimit)`, and pass `thresholds: thresholds` to the output.

- [ ] **Step 6: `SeasonLoaderService`.** Add:

```dart
  /// Each loaded season's effective threshold (see [effectiveThreshold]).
  final Map<int, SeasonThreshold> thresholds = {};

  /// [configs] with the thresholds this loader resolved.
  List<SeasonConfig> applyThresholds(List<SeasonConfig> configs) => [
        for (final c in configs)
          if (thresholds[c.id] case final t?) c.withThreshold(t) else c,
      ];
```

In `loadAll` and `loadSeasons` add `thresholds.addAll(out.thresholds);`. Add the top-level helper after `seasonStandingsForTest`:

```dart
/// The isolate's view of [c]; [now] decides whether a top3 season is live.
SeasonMeta seasonMetaFor(SeasonConfig c, DateTime now) => SeasonMeta(
    c.id, c.gameLimit, c.gamesMultiplier,
    rule: c.gameLimitRule, gameLimitSet: c.gameLimitSet, now: now);
```

- [ ] **Step 7: `app_providers.dart`.** Move `clockProvider` here (same code and doc comment: `/// The clock the in-progress checks read; overridden in tests.` `final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);`); delete it from `players_providers.dart` (that file already imports app_providers). Fix any test importing `clockProvider` from players_providers (`grep -rn clockProvider test`). Then:
  - both loads: the configs from `parsedConfigProvider` carry no admin values. In the initial load, right after `parsed.seasons`, replace the `.ignore()` early start with `final club = await ref.read(clubConfigProvider.future);` and `final configs = applyAdminLimits(parsed.seasons, club?.gameLimits ?? const {});`. Store that merged list as `_InitialLoadResult.allConfigs`, so the background load (which reads `shared.allConfigs`) gets the limits too.
  - initial load: `final now = ref.read(clockProvider)();` → `metas: [seasonMetaFor(latestConfig, now)]`; after loading `final latest = loader.applyThresholds([latestConfig]).single;` and use `latest` for `loadedSeasonConfigsProvider`, `selectedSeasonProvider` and `_InitialLoadResult.loadedConfigs: [latest]`.
  - background load: both `metas:` lists → `loadedRemainingConfigs.map((c) => seasonMetaFor(c, now))` with `final now = ref.read(clockProvider)();`; `allLoaded = [...shared.loadedConfigs, ...loader.applyThresholds(loadedRemainingConfigs)]`.
- [ ] **Step 8: `test/site_export/fixture.dart`** — `metas: [for (final c in configs) seasonMetaFor(c, DateTime.now())]` and `container.read(loadedSeasonConfigsProvider.notifier).state = loader.applyThresholds(configs);`.
- [ ] **Step 9: Run** `flutter test test/services/season_threshold_load_test.dart` → PASS, then `flutter test` (all) and `flutter analyze` → clean. Fix the third test if `loader` there is unused — it only proves `seasonStandingsForTest` needs no loader; delete the `loader` lines if analyze flags them.
- [ ] **Step 10: Commit**

```bash
git add lib/services lib/providers/app_providers.dart lib/screens/players/players_providers.dart test
git commit -m "feat: loader resolves the effective game threshold per season"
```

---

### Task 4: Show the threshold on the site

**Files:**
- Modify: `lib/site_export/season_export.dart` (season JSON)
- Modify: `lib/site_export/players_export.dart` (timeline `needed`)
- Modify: `site/src/lib/types.ts` (`SeasonData`, `PlayerData.timeline`)
- Modify: `site/src/components/SeasonPage.astro` (panel note)
- Modify: `site/src/pages/players/[slug].astro` (Games-by-season note)
- Test: `test/site_export/season_export_test.dart` / `players_export_test.dart` (add cases where those files exist; else create `test/site_export/threshold_export_test.dart`)

**Interfaces:**
- Consumes: `SeasonConfig.thresholdFormula`, `thresholdLive`, `gameLimit` (Tasks 2–3).
- Produces JSON: season `thresholdFormula: number | null`, `thresholdLive: boolean`; timeline entry `needed?: number` (games to the main league, only for a live season where `0 < games < gameLimit`).

- [ ] **Step 1: Failing Dart test.** Build an `ExportContext` from `fixtureContainer(seasonIds: [21])`, then override the config to a live top3 one and assert the export:

```dart
test('season JSON carries the live threshold', () async {
  final c = await fixtureContainer(seasonIds: [21]);
  final cfg = c.read(loadedSeasonConfigsProvider).single;
  c.read(loadedSeasonConfigsProvider.notifier).state =
      [cfg.withThreshold((gameLimit: 16, formula: 15.4, live: true))];
  final x = ExportContext(c);
  final j = seasonJson(x, x.seasons.single);
  expect((j['gameLimit'], j['thresholdFormula'], j['thresholdLive']), (16, 15.4, true));
  final p = x.players.firstWhere((p) {
    final g = (playerJson(x, p)['timeline'] as List).cast<Map>().single['games'] as int;
    return g > 0 && g < 16;
  });
  final t = (playerJson(x, p)['timeline'] as List).cast<Map>().single;
  expect(t['needed'], 16 - (t['games'] as int));
});
```

(Use the season-export entry point's real name — check `season_export.dart`'s public function; `playerJson` is in `players_export.dart`.) If no S21 player has 1–15 games, assert on the first player with `games > 0 && games < 16` found among `x.players` — S21 has many low-count players.

- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Dart.** `season_export.dart`, after `'gameLimit'`: `'thresholdFormula': season.thresholdFormula, 'thresholdLive': season.thresholdLive,`. `players_export.dart` timeline entry:

```dart
          if (c.thresholdLive &&
              (perSeason[c.id] ?? 0) > 0 &&
              (perSeason[c.id] ?? 0) < c.gameLimit)
            'needed': c.gameLimit - perSeason[c.id]!,
```

- [ ] **Step 4: Site types** (`types.ts`): `SeasonData` add `thresholdFormula: number | null; thresholdLive: boolean;`; timeline item add `needed?: number`.
- [ ] **Step 5: `SeasonPage.astro`.** Replace the Panel `note` with:

```astro
    <Panel title="Player ratings" note={small
      ? `${season.smallLeagueMinGames}–${season.gameLimit - 1} games`
      : season.thresholdLive && season.thresholdFormula !== null
        ? `${season.gameLimit}+ games · live threshold ${season.thresholdFormula.toFixed(1)}`
        : `${season.gameLimit}+ games`} class="span-12">
```

- [ ] **Step 6: Profile.** In `[slug].astro` frontmatter: `const chase = p.timeline.find((t) => t.needed);` and the Games-by-season panel: `<Panel title="Games by season" note={chase ? `S${chase.seasonId}: ${chase.needed} more game${chase.needed === 1 ? '' : 's'} to the main league` : undefined} class="span-8">`.
- [ ] **Step 7: Verify.** `flutter test` → PASS. `flutter test tool/export_site_data_test.dart` (needs `assets/prefetched/`; skip with a note if absent), then `cd site && npm run check && npm test && npm run build` → PASS. If the export ran, `/season/31/` note reads `16+ games · live threshold 15.4`.
- [ ] **Step 8: Commit**

```bash
git add lib/site_export test/site_export site/src
git commit -m "feat(site): live game threshold on season and player pages"
```

---

### Task 5: Admin threshold on /debug/

**Files:**
- Modify: `lib/site_export/debug_export.dart` (thresholds list)
- Modify: `site/src/lib/config-edit.ts` (`gameLimit` op in `applyOps`)
- Modify: `site/src/lib/config-edit.test.ts`
- Modify: `site/src/lib/club/store.ts` (`saveClub` applies limits)
- Modify: `site/src/lib/types.ts` (`DebugData.thresholds`)
- Modify: `site/src/scripts/debug.ts`, `site/src/pages/debug/index.astro`

**Interfaces:**
- Consumes: `SeasonConfig.gameLimitRule`, `gameLimitSet`, `gameLimit`, `thresholdFormula`, `thresholdLive`; shipped `clubBody`, `applyOps`, `saveClub`.
- Produces:
  - Debug JSON `thresholds: { season: number; title: string; formula: number; gameLimit: number; set: boolean; live: boolean }[]` — top3 seasons only, newest first.
  - `Op` gains `{ kind: 'gameLimit'; season: number; limit: number | null }`.
  - `SeasonConfigFile` gains `gameLimits?: Record<string, number>`; `applyOps` applies `gameLimit` ops to it (set, or delete on null) and throws on a limit that is not an integer ≥ 0.

- [ ] **Step 1: Failing vitest** in `config-edit.test.ts`:

```ts
describe('gameLimit ops', () => {
  it('set, replace and clear a season limit', () => {
    const f: SeasonConfigFile = { tournaments: [], gameLimits: { '30': 40 } };
    const set = applyOps(f, [{ kind: 'gameLimit', season: 31, limit: 41 }]);
    expect(set.gameLimits).toEqual({ '30': 40, '31': 41 });
    expect(applyOps(set, [{ kind: 'gameLimit', season: 31, limit: 39 }]).gameLimits).toEqual({ '30': 40, '31': 39 });
    expect(applyOps(set, [{ kind: 'gameLimit', season: 31, limit: null }]).gameLimits).toEqual({ '30': 40 });
    expect(f.gameLimits).toEqual({ '30': 40 });
  });
  it('rejects a bad value', () => {
    expect(() => applyOps({}, [{ kind: 'gameLimit', season: 31, limit: -1 }])).toThrow();
    expect(() => applyOps({}, [{ kind: 'gameLimit', season: 31, limit: 1.5 }])).toThrow();
  });
  it('clubBody writes the applied limits', () => {
    const next = applyOps({ tournaments: [] }, [{ kind: 'gameLimit', season: 31, limit: 41 }]);
    expect(clubBody(next, next.gameLimits).gameLimits).toEqual({ '31': 41 });
  });
});
```

- [ ] **Step 2: Run** `cd site && npx vitest run src/lib/config-edit.test.ts` → FAIL.
- [ ] **Step 3: `config-edit.ts`.** Add the op variant and `gameLimits?: Record<string, number>` on `SeasonConfigFile`. In `applyOps` start `let limits = { ...(file.gameLimits ?? {}) };`, add

```ts
      case 'gameLimit': {
        if (op.limit !== null && (!Number.isInteger(op.limit) || op.limit < 0)) throw new Error(`Threshold must be a whole number ≥ 0, got ${op.limit}`);
        if (op.limit === null) delete limits[String(op.season)];
        else limits[String(op.season)] = op.limit;
        break;
      }
```

and return `{ ...file, tournaments: list, gameLimits: limits }` (rejected as today).
- [ ] **Step 4: `club/store.ts` `saveClub`:** `const next = applyOps({ tournaments: cur.tournaments ?? [], rejectedCandidates: cur.rejectedCandidates ?? [], gameLimits: cur.gameLimits ?? {} }, ops);` and `tx.set(clubRef(), { ...clubBody(next, next.gameLimits ?? {}), ...stamp(u) });`.
- [ ] **Step 5: Run** vitest → PASS.
- [ ] **Step 6: Debug export.** In `debugJson` add:

```dart
    'thresholds': [
      for (final c in x.seasons.reversed)
        if (c.gameLimitRule == GameLimitRule.top3 && c.thresholdFormula != null)
          {
            'season': c.id,
            'title': c.title,
            'formula': c.thresholdFormula,
            'gameLimit': c.gameLimit,
            'set': c.gameLimitSet,
            'live': c.thresholdLive,
          },
    ],
```

and in `types.ts` `DebugData`: `thresholds: { season: number; title: string; formula: number; gameLimit: number; set: boolean; live: boolean }[];`.

- [ ] **Step 7: Page.** In `debug/index.astro`, before the toolbar:

```astro
  {d.thresholds.length > 0 && (
    <section class="panel thresholds">
      <h2 class="label">Main-league thresholds</h2>
      <p class="hint">While a season is played the threshold follows the sheet formula (top-3 games × 0.6 − 5). After it ends an admin can set the final value; empty = rounded-up formula.</p>
      <div id="thresholds"></div>
    </section>
  )}
```

Global style: `.thresholds { margin-bottom: 16px; } .thr { display: flex; flex-wrap: wrap; align-items: baseline; gap: 6px 12px; padding: 6px 0; } .thr input { width: 6em; }`.

- [ ] **Step 8: Script** (`debug.ts`). Add after `card`:

```ts
function thresholdRows(): string {
  const liveLimits = (live as { gameLimits?: Record<string, number> } | null)?.gameLimits;
  return data.thresholds.map((t) => {
    const op = [...ops].reverse().find((o) => o.kind === 'gameLimit' && o.season === t.season) as Extract<Op, { kind: 'gameLimit' }> | undefined;
    const formula = Math.max(0, Math.ceil(t.formula));
    const saved = liveLimits ? liveLimits[String(t.season)] ?? null : (t.set ? t.gameLimit : null);
    const value = op ? op.limit : saved;
    const state = t.live ? 'live' : value === null ? `${formula} (formula)` : `${value} (admin)`;
    const edit = t.live ? '<span class="label">editable after the season ends</span>'
      : `<form class="thr-form" data-season="${t.season}"><input name="limit" type="number" min="0" step="1" value="${value ?? formula}" aria-label="Threshold for S${t.season}">
         <button class="btn" type="submit">Set</button><button class="btn" type="button" data-reset="${t.season}">Use formula</button></form>`;
    return `<div class="thr ${op ? 'pending-op' : ''}"><b>S${t.season}</b><span>formula ${t.formula.toFixed(1)} → ${formula}</span><span>now ${esc(state)}</span>${edit}</div>`;
  }).join('');
}
```

In `render()`: `const th = document.getElementById('thresholds'); if (th) th.innerHTML = thresholdRows();`. Listeners:

```ts
const thr = document.getElementById('thresholds');
thr?.addEventListener('submit', (ev) => {
  ev.preventDefault();
  const f = ev.target as HTMLFormElement;
  const v = (f.elements.namedItem('limit') as HTMLInputElement).valueAsNumber;
  if (!Number.isInteger(v) || v < 0) return;
  push({ kind: 'gameLimit', season: +f.dataset.season!, limit: v });
});
thr?.addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest<HTMLButtonElement>('button[data-reset]');
  if (b) push({ kind: 'gameLimit', season: +b.dataset.reset!, limit: null });
});
```

`rows()` already ignores ops without `key`/`id`/`entry`; the existing Save sends `gameLimit` ops through `saveClub`.
- [ ] **Step 9: Verify.** `flutter test`, `cd site && npm run check && npm test && npm run build` → PASS. With an exported `site/data/`, `/debug/` lists S31 as `live`.
- [ ] **Step 10: Docs.** `CLAUDE.md` → "Adding a New Season" remote example: add `"gameLimitRule": "top3"` and: "`top3` seasons: threshold follows the sheet formula while the season is played; after it ends the admin's value from `config/club.gameLimits` (set on `/debug/`) or the rounded-up formula."
- [ ] **Step 11: Commit**

```bash
git add lib/site_export/debug_export.dart site/src CLAUDE.md
git commit -m "feat(site): admin can set a finished season's threshold on /debug/"
```
