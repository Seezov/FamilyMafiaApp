# Small League (Мала Ліга) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a second standing to the season screen — the small league — showing players who played at least `smallLeagueMinGames` but fewer than the season's `gameLimit`.

**Architecture:** The small league is a *filter over already-computed `RatingPlayerStats`*, not a second rating formula — the source spreadsheets hold identical numbers in both tabs. So no code in `lib/services/` or `rating_formulas.dart` changes. A new per-season config field carries the lower bound; the upper bound is the existing `gameLimit`. A `StateProvider<League>` selects which predicate `currentSeasonStatsProvider` applies, and a `SegmentedButton` on `HomeScreen` drives it.

**Tech Stack:** Dart / Flutter 3.x, Material 3, Riverpod 2.6.1, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-09-24-small-league-design.md`

## Global Constraints

- A player with exactly `gameLimit` games belongs to the **main league only**. Main league predicate stays `gamesPlayed >= limit`, unchanged.
- Small league predicate is `gamesPlayed >= smallLeagueMinGames && gamesPlayed < limit`. The leagues never overlap.
- `smallLeagueMinGames` defaults to `15`. Exceptions: season `0` → `8`, season `6` → `30`, seasons `12`, `14`, `15` → `20`.
- `SeasonConfig.fromJson` must parse the field as optional (`as int? ?? 15`) so an older `remote_config.json` and any locally cached config from a previous app version keep working. No migration.
- Magic numbers go in `lib/constants/season_constants.dart` with doc comments (repo convention).
- Large files use `part` / `part of` with parts under `src/` (repo convention).
- The working tree has unrelated uncommitted changes in `season_header_card.dart`, `debug_screen.dart`, `season_stats.dart` and others. **Stage only the files each task names** — never `git add -A` or `git commit -a`.

---

### Task 1: Config field

**Files:**
- Modify: `lib/constants/season_constants.dart`
- Modify: `lib/models/season_config.dart`
- Test: `test/models/season_config_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `SeasonConfig.smallLeagueMinGames` (`int`, non-nullable, required named param); `kDefaultSmallLeagueMinGames` (`int`, value `15`).

- [ ] **Step 1: Write the failing test**

Create `test/models/season_config_test.dart`:

```dart
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeasonConfig.fromJson smallLeagueMinGames', () {
    test('reads the field when present', () {
      final config = SeasonConfig.fromJson({
        'id': 30,
        'title': 'Season 30',
        'gameLimit': 40,
        'gamesMultiplier': 0.0,
        'smallLeagueMinGames': 20,
        'source': 'remote',
        'spreadsheetId': 'abc',
        'sheetName': 'Ігри',
        'range': 'A2:Q',
      });

      expect(config.smallLeagueMinGames, 20);
    });

    test('defaults to 15 when the field is absent', () {
      final config = SeasonConfig.fromJson({
        'id': 28,
        'title': 'Season 28',
        'gameLimit': 55,
        'gamesMultiplier': 0.0,
        'source': 'bundled',
        'jsonFile': 'season28.json',
      });

      expect(config.smallLeagueMinGames, 15);
    });

    test('round-trips through toJson', () {
      const config = SeasonConfig(
        id: 6,
        title: 'Season 6',
        gameLimit: 70,
        gamesMultiplier: 0.004,
        smallLeagueMinGames: 30,
        source: BundledSource(jsonFile: 'season6.json'),
      );

      expect(SeasonConfig.fromJson(config.toJson()).smallLeagueMinGames, 30);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/models/season_config_test.dart`
Expected: compile error — `SeasonConfig` has no named parameter `smallLeagueMinGames`.

- [ ] **Step 3: Add the constant**

Append to `lib/constants/season_constants.dart`:

```dart
/// Default lower bound (inclusive) on games played for the small league.
///
/// The upper bound is always the season's own [SeasonConfig.gameLimit], so it
/// is never stored separately. Four seasons override this default: season 0
/// uses 8 (short first season, gameLimit 17), season 6 uses 30 (doubled
/// season), and seasons 12, 14 and 15 use 20.
const int kDefaultSmallLeagueMinGames = 15;
```

- [ ] **Step 4: Add the field to SeasonConfig**

In `lib/models/season_config.dart`, add the import:

```dart
import 'package:family_mafia_app/constants/season_constants.dart';
```

Add the field next to `gameLimit`:

```dart
  final int smallLeagueMinGames;
```

Add to the constructor, after `gameLimit`:

```dart
    required this.smallLeagueMinGames,
```

In `fromJson`, add to the returned `SeasonConfig`, after `gameLimit`:

```dart
      smallLeagueMinGames: json['smallLeagueMinGames'] as int? ??
          kDefaultSmallLeagueMinGames,
```

In `toJson`, add to the map literal, after `'gameLimit': gameLimit,`:

```dart
      'smallLeagueMinGames': smallLeagueMinGames,
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/models/season_config_test.dart`
Expected: 3 tests PASS.

Note: `lib/enums/season.dart` will not compile yet — its `toConfig()` does not pass the new required param. Task 2 fixes that. Run the single test file, not the whole suite.

- [ ] **Step 6: Commit**

```bash
git add lib/constants/season_constants.dart lib/models/season_config.dart test/models/season_config_test.dart
git commit -m "feat: add smallLeagueMinGames to SeasonConfig"
```

---

### Task 2: Per-season bounds for bundled seasons

**Files:**
- Modify: `lib/enums/season.dart`
- Modify: `remote_config.json`
- Test: `test/enums/season_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonConfig.smallLeagueMinGames`, `kDefaultSmallLeagueMinGames` (Task 1).
- Produces: `Season.smallLeagueMinGames` (`int`); `Season.toConfig()` populating it.

- [ ] **Step 1: Write the failing test**

Create `test/enums/season_test.dart`:

```dart
import 'package:family_mafia_app/enums/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Season.smallLeagueMinGames', () {
    test('season 0 uses 8 (short first season, gameLimit 17)', () {
      expect(Season.findById(0)!.smallLeagueMinGames, 8);
    });

    test('season 6 uses 30 (doubled season)', () {
      expect(Season.findById(6)!.smallLeagueMinGames, 30);
    });

    test('seasons 12, 14 and 15 use 20', () {
      for (final id in [12, 14, 15]) {
        expect(Season.findById(id)!.smallLeagueMinGames, 20,
            reason: 'season $id');
      }
    });

    test('every other season uses 15', () {
      const overridden = {0, 6, 12, 14, 15};
      for (final season in Season.values) {
        if (overridden.contains(season.id)) continue;
        expect(season.smallLeagueMinGames, 15, reason: 'season ${season.id}');
      }
    });

    test('the lower bound is always below the game limit', () {
      for (final season in Season.values) {
        expect(season.smallLeagueMinGames, lessThan(season.gameLimit),
            reason: 'season ${season.id}');
      }
    });

    test('toConfig carries the lower bound through', () {
      expect(Season.findById(6)!.toConfig().smallLeagueMinGames, 30);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/enums/season_test.dart`
Expected: compile error — `Season` has no getter `smallLeagueMinGames`.

- [ ] **Step 3: Add the field to the enum**

In `lib/enums/season.dart`, add `smallLeagueMinGames:` to every one of the 29 enum values. The four exceptions are seasons 0, 6, 12, 14, 15 — all others get `15`. For example:

```dart
  season0(id: 0, title: 'Season 0', jsonFile: 'season0.json', gameLimit: 17, gamesMultiplier: 0.25, smallLeagueMinGames: 8),
  season1(id: 1, title: 'Season 1', jsonFile: 'season1.json', gameLimit: 30, gamesMultiplier: 0.25, smallLeagueMinGames: 15),
  ...
  season6(id: 6, title: 'Season 6', jsonFile: 'season6.json', gameLimit: 70, gamesMultiplier: 0.004, smallLeagueMinGames: 30),
  ...
  season12(id: 12, title: 'Season 12', jsonFile: 'season12.json', gameLimit: 50, gamesMultiplier: 0.004, smallLeagueMinGames: 20),
  ...
  season14(id: 14, title: 'Season 14', jsonFile: 'season14.json', gameLimit: 58, gamesMultiplier: 0.004, smallLeagueMinGames: 20),
  season15(id: 15, title: 'Season 15', jsonFile: 'season15.json', gameLimit: 56, gamesMultiplier: 0.004, smallLeagueMinGames: 20),
  ...
  season28(id: 28, title: 'Season 28', jsonFile: 'season28.json', gameLimit: 55, gamesMultiplier: 0.0, smallLeagueMinGames: 15);
```

Add to the constructor, after `required this.gameLimit,`:

```dart
    required this.smallLeagueMinGames,
```

Add the field declaration, after `final int gameLimit;`:

```dart
  final int smallLeagueMinGames;
```

Add to `toConfig()`, after `gameLimit: gameLimit,`:

```dart
        smallLeagueMinGames: smallLeagueMinGames,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/enums/season_test.dart`
Expected: 6 tests PASS.

- [ ] **Step 5: Add the field to the remote config**

In `remote_config.json`, add `"smallLeagueMinGames": 15` to the season 29 and season 30 entries, after `"gamesMultiplier"`:

```json
    {"id": 29, "title": "Season 29", "gameLimit": 50, "gamesMultiplier": 0.0, "smallLeagueMinGames": 15, "source": "remote", "spreadsheetId": "1gHRCyYMzFSrq3t20wDRlKPzUHX4BTc7HQDepp64-jNM", "sheetName": "Ігри", "range": "A2:Q"},
    {"id": 30, "title": "Season 30", "gameLimit": 40, "gamesMultiplier": 0.0, "smallLeagueMinGames": 15, "source": "remote", "spreadsheetId": "1bhqOF5wU-ddyDZkE12kaBSQFFhSDSVcyXuWwvwq2hzc", "sheetName": "Ігри", "range": "A2:Q"}
```

- [ ] **Step 6: Verify the whole suite compiles again**

Run: `flutter analyze`
Expected: no new errors. (Pre-existing warnings in files with uncommitted changes may appear — ignore those.)

- [ ] **Step 7: Commit**

```bash
git add lib/enums/season.dart remote_config.json test/enums/season_test.dart
git commit -m "feat: per-season small league lower bounds"
```

Note: `remote_config.json` is fetched from GitHub raw at runtime. The committed change only takes effect once this branch is pushed — the bundled `Season` enum covers seasons 0–28 regardless.

---

### Task 3: League selection in providers

**Files:**
- Modify: `lib/screens/home/home_providers.dart`
- Test: `test/screens/home/home_providers_test.dart` (create)

**Interfaces:**
- Consumes: `SeasonConfig.smallLeagueMinGames` (Task 1).
- Produces: `enum League { main, small }`; `selectedLeagueProvider` (`StateProvider<League>`, default `League.main`); `currentSeasonStatsProvider` filtering by the selected league.

- [ ] **Step 1: Write the failing test**

Create `test/screens/home/home_providers_test.dart`:

```dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _season = SeasonConfig(
  id: 99,
  title: 'Test Season',
  gameLimit: 40,
  gamesMultiplier: 0.0,
  smallLeagueMinGames: 15,
  source: BundledSource(jsonFile: 'none.json'),
);

/// Players sitting on every boundary that matters.
const _gameCounts = [14, 15, 39, 40, 41];

SeasonStats _statsFor(List<int> gameCounts) => SeasonStats(
      playerStats: [
        for (final (index, games) in gameCounts.indexed)
          RatingPlayerStats(
            seasonId: _season.id,
            player: Player(id: index, displayName: 'p$games'),
            gamesPlayed: games,
          ),
      ],
      mvpRanking: const [],
      bestSheriffRanking: const [],
      bestDonRanking: const [],
      bestCivilianRanking: const [],
      bestMafiaRanking: const [],
      mostKilledRanking: const [],
    );

ProviderContainer _containerWith(List<int> gameCounts) {
  final container = ProviderContainer(
    overrides: [
      seasonRepositoryProvider.overrideWith(
        (ref) => SeasonRepository()..addSeason(_season.id, _statsFor(gameCounts)),
      ),
    ],
  );
  // Listeners only run once the provider is alive.
  container.read(leagueOverrideResetProvider);
  container.read(selectedSeasonProvider.notifier).state = _season;
  addTearDown(container.dispose);
  return container;
}

List<int> _gamesIn(ProviderContainer c) =>
    (c.read(currentSeasonStatsProvider)?.playerStats ?? [])
        .map((p) => p.gamesPlayed)
        .toList();

void main() {
  group('currentSeasonStatsProvider league filtering', () {
    test('main league keeps gamesPlayed >= gameLimit (unchanged)', () {
      final c = _containerWith(_gameCounts);
      expect(c.read(selectedLeagueProvider), League.main);
      expect(_gamesIn(c), [40, 41]);
    });

    test('small league keeps min <= gamesPlayed < gameLimit', () {
      final c = _containerWith(_gameCounts);
      c.read(selectedLeagueProvider.notifier).state = League.small;
      expect(_gamesIn(c), [15, 39]);
    });

    test('a player with exactly gameLimit games is main league only', () {
      final c = _containerWith([40]);
      expect(_gamesIn(c), [40]);

      c.read(selectedLeagueProvider.notifier).state = League.small;
      expect(_gamesIn(c), isEmpty);
    });

    test('the leagues never overlap', () {
      final c = _containerWith(_gameCounts);
      final main = _gamesIn(c).toSet();
      c.read(selectedLeagueProvider.notifier).state = League.small;
      final small = _gamesIn(c).toSet();

      expect(main.intersection(small), isEmpty);
    });

    test('selecting the small league clears the game limit override', () {
      final c = _containerWith(_gameCounts);
      c.read(gameLimitOverrideProvider.notifier).state = 20;

      c.read(selectedLeagueProvider.notifier).state = League.small;

      expect(c.read(gameLimitOverrideProvider), isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/home/home_providers_test.dart`
Expected: compile error — `League`, `selectedLeagueProvider` and `leagueOverrideResetProvider` are undefined.

- [ ] **Step 3: Add the league enum and provider**

In `lib/screens/home/home_providers.dart`, above `gameLimitOverrideProvider`:

```dart
/// Which standing the season screen shows.
///
/// Main league: players who reached the season's `gameLimit`.
/// Small league: players between `smallLeagueMinGames` (inclusive) and
/// `gameLimit` (exclusive) — so a player on exactly `gameLimit` is main
/// league only and the two never overlap.
enum League { main, small }

final selectedLeagueProvider = StateProvider<League>((ref) => League.main);
```

- [ ] **Step 4: Branch the filter**

Replace the body of `currentSeasonStatsProvider` (currently at `lib/screens/home/home_providers.dart:67-81`) with:

```dart
final currentSeasonStatsProvider = Provider<SeasonStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;

  final seasonMap = ref.watch(seasonRepositoryProvider);
  final full = seasonMap[season.id];
  if (full == null) return null;

  final limit = ref.watch(effectiveGameLimitProvider);
  final league = ref.watch(selectedLeagueProvider);

  final filtered = switch (league) {
    League.main => full.playerStats.where((p) => p.gamesPlayed >= limit),
    League.small => full.playerStats.where((p) =>
        p.gamesPlayed >= season.smallLeagueMinGames && p.gamesPlayed < limit),
  };

  return full.copyWith(playerStats: filtered.toList());
});
```

- [ ] **Step 5: Clear the override when the small league is selected**

The league toggle and the manual game-limit override both control the same threshold; together they produce a contradictory state. Add a listener so selecting the small league resets the override, mirroring `season_chips.dart:41`.

Append to `lib/screens/home/home_providers.dart`:

```dart
/// Keeps the manual game-limit override from contradicting the league toggle.
///
/// Both control the same threshold, so the override only makes sense while the
/// main league is selected. Watched by [HomeScreen].
final leagueOverrideResetProvider = Provider<void>((ref) {
  ref.listen<League>(selectedLeagueProvider, (previous, next) {
    if (next == League.small) {
      ref.read(gameLimitOverrideProvider.notifier).state = null;
    }
  });
});
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/screens/home/home_providers_test.dart`
Expected: 5 tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/home/home_providers.dart test/screens/home/home_providers_test.dart
git commit -m "feat: small league filtering in season providers"
```

---

### Task 4: League toggle on the season screen

**Files:**
- Create: `lib/screens/home/src/league_toggle.dart`
- Modify: `lib/screens/home/home_screen.dart`

**Interfaces:**
- Consumes: `League`, `selectedLeagueProvider`, `leagueOverrideResetProvider` (Task 3); `SeasonConfig.smallLeagueMinGames` (Task 1).
- Produces: `_LeagueToggle` (private part widget, no public API).

- [ ] **Step 1: Create the toggle widget**

Create `lib/screens/home/src/league_toggle.dart`:

```dart
part of '../home_screen.dart';

class _LeagueToggle extends ConsumerWidget {
  const _LeagueToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final league = ref.watch(selectedLeagueProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SegmentedButton<League>(
        segments: const [
          ButtonSegment(value: League.main, label: Text('Основна')),
          ButtonSegment(value: League.small, label: Text('Мала')),
        ],
        selected: {league},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          ref.read(selectedLeagueProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}
```

- [ ] **Step 2: Wire it into the screen**

In `lib/screens/home/home_screen.dart`, add the part directive after line 18 (`part 'src/season_chips.dart';`):

```dart
part 'src/league_toggle.dart';
```

Activate the reset listener — add next to the other `ref.watch` calls near line 47:

```dart
    ref.watch(leagueOverrideResetProvider);
```

Insert the toggle as its own sliver, immediately after the `SliverAppBar` closing `),` (around line 78) and before the `if (isBackgroundLoading)` block:

```dart
          const SliverToBoxAdapter(child: _LeagueToggle()),
```

- [ ] **Step 3: Fix the empty-list message**

`home_screen.dart:100` shows `'No players meet this game limit'`, which states the wrong reason for an empty small league. Replace that `Padding` widget with:

```dart
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          ref.watch(selectedLeagueProvider) == League.small
                              ? 'Немає гравців у діапазоні '
                                  '${selectedSeason.smallLeagueMinGames}–'
                                  '${selectedSeason.gameLimit - 1} ігор'
                              : 'No players meet this game limit',
                        ),
                      )
```

Drop the `const` from the `if (seasonStats.playerStats.isEmpty)` branch if the analyzer complains — the widget is no longer constant.

- [ ] **Step 4: Verify it analyzes and the suite still passes**

Run: `flutter analyze`
Expected: no new errors.

Run: `flutter test`
Expected: all tests PASS, including the three files added by Tasks 1–3.

- [ ] **Step 5: Verify in the running app**

Run: `flutter run --dart-define=SHEETS_API_KEY=$SHEETS_API_KEY --dart-define=REMOTE_CONFIG_URL=$REMOTE_CONFIG_URL`

(Values are in `assets/.env.json`, which is gitignored.)

Check by hand:
1. The season screen opens on **Основна**, and the list matches what it showed before this change.
2. Tapping **Мала** shows a different, non-empty set of players on a recent season (Season 28 has ~18).
3. No player appears in both lists for the same season.
4. Season 0 on **Мала** shows ~11 players, not 1.
5. Switching seasons keeps the selected league; the list updates.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home/src/league_toggle.dart lib/screens/home/home_screen.dart
git commit -m "feat: league toggle on the season screen"
```

---

## Notes for the executor

- `lib/screens/home/src/season_header_card.dart` has large uncommitted changes from unrelated work. The spec mentions showing the active band in the season header; that is **deliberately not a task here** — it would collide with work in progress. Raise it once that work lands.
- `hasQualifyingPlayersProvider` in `home_providers.dart` has no callers anywhere in `lib/` or `test/`. Leave it alone; it is dead code unrelated to this feature.
- The chat layer (`lib/services/chat/`, `gemini_chat_service.dart`) filters by `gameLimit` in seven places and stays main-league-only. Out of scope per the spec.
