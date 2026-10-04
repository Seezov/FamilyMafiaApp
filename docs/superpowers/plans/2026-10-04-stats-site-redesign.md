# Stats Site Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter Web build at https://seezov.github.io/FamilyMafiaApp/ with a pre-rendered, dark, data-dense Astro stats site fed by JSON that the app's own Dart providers compute.

**Architecture:** `tool/export_site_data_test.dart` runs under `flutter test`, loads all seasons through the app's real provider pipeline into a `ProviderContainer`, and writes display-ready JSON to `site/data/` via small modules in `lib/site_export/`. `site/` is an Astro project that reads that JSON at build time and emits static HTML; a few vanilla-TS islands add sorting, search and records filters. CI builds and deploys `site/dist` instead of `build/web`.

**Tech Stack:** Dart / Flutter 3.41 + Riverpod 2.6 (export), Astro 7 + TypeScript + Vitest 4 (site), Node 24, GitHub Actions + Pages.

**Spec:** `docs/superpowers/specs/2026-10-04-stats-site-redesign-design.md`

## Global Constraints

- Base path `/FamilyMafiaApp/`; every internal URL is built with `href()` from `site/src/lib/url.ts` and ends with `/`.
- Dark only. Tokens: bg `#0B0D10`, panel `#12161B`, border `#1F252D`, text `#E6E8EB`, muted `#8B95A1`; city red / brand `#E5484D`; mafia slate `#A3ADBA`; roles Мирний `#E5484D`, Шериф `#22C3DC`, Мафія `#A3ADBA`, Дон `#A78BFA`; WR good `#3FB950` (≥ 50 %), mid `#D29922` (≥ 35 %), low = muted.
- Fonts: Unbounded (titles, logo, KPI numbers) + Inter (everything else), Google Fonts, Cyrillic subsets; `tabular-nums` on numbers.
- Layout: max width 1280 px, 24 px gutters; below 900 px one column, 16 px gutter; no horizontal page scroll.
- The build must contain no `AIza` string. The export never uses an API key or the network.
- No changes to the Flutter app's UI; `lib/site_export/` is new code only, and app providers are read, not modified.
- Push both `feature/flutter_migration` and `master` when shipping.

## Review Focus

1. **Odd player names** (apostrophes `ʼ'’`, Latin, digits, two players whose names transliterate the same, a name that is only punctuation) → every player still gets a non-empty, unique, URL-safe slug. Pinned in Task 2.
2. **Zero denominators** (0 games in a role, 0 protocol guesses, a season with no decided games) → cells show `–`/`—`, no `NaN`/`Infinity` reaches JSON (which `jsonEncode` would throw on). Pinned in Tasks 2 and 4.
3. **An empty league** (small league with nobody in range, old seasons without `smallLeagueMinGames` players) → the page shows the app's empty message instead of an empty table. Pinned in Task 4 and rendered in Task 11.
4. **Names that are not players** (hosts not in `players.json`, `NamedValue` winners in the seasons table) → plain text, never a link to a missing page. Pinned in Task 4 and enforced by the dist link check in Task 9.
5. **Phone width with the widest tables** (season ratings with protocol + role columns, the seasons table) → the page itself never scrolls sideways; only the table container does. Checked in Task 17.

---

## File Structure

**Dart (export)**
- `lib/site_export/site_table.dart` — `SiteColumn`, `SiteCell`, `SiteTable`: the display-ready table shape and its JSON.
- `lib/site_export/formats.dart` — the app's number formats (`pct0`, `pct1`, `f2`, `signed2`, `rounded`, `seasonLabel`), `roleLabel`, `initials`, role sum helpers.
- `lib/site_export/slugs.dart` — `slugify`, `assignSlugs`.
- `lib/site_export/export_context.dart` — `ExportContext`: container access, slug map, season/league selection, player name cells.
- `lib/site_export/load_container.dart` — `loadSiteContainer()`: the production provider pipeline, web-style overrides.
- `lib/site_export/season_export.dart` — `seasonJson`.
- `lib/site_export/overview_export.dart` — `overviewJson`.
- `lib/site_export/players_export.dart` — `playersJson`, `playerJson`.
- `lib/site_export/records_export.dart` — `recordsJson`.
- `lib/site_export/site_exporter.dart` — `writeSiteData`.
- `tool/export_site_data_test.dart` — the CI/local entry point.
- `test/site_export/fixture.dart` + one test file per module.

**Site**
- `site/package.json`, `site/astro.config.mjs`, `site/tsconfig.json`, `site/.gitignore`
- `site/src/lib/{types,data,url,format,sort}.ts` (+ `format.test.ts`, `sort.test.ts`)
- `site/src/styles/global.css`
- `site/src/layouts/Base.astro`
- `site/src/components/{DataTable,Kpi,Panel,SeasonPage,RankedList,GamesBySeasonChart,RoleRings,Bars}.astro`, `site/src/components/table.ts` (island)
- `site/src/pages/{index,404,overview}.astro`, `site/src/pages/season/[id]/index.astro`, `site/src/pages/season/[id]/small/index.astro`, `site/src/pages/players/{index,[slug]}.astro`, `site/src/pages/records/{index,[category]}.astro`
- `site/scripts/check-dist.mjs`, `site/scripts/make-og.mjs`, `site/public/og.png`, `site/public/favicon.svg`

**Changed:** `.github/workflows/web.yml`, `.gitignore`, `CLAUDE.md`.

---

### Task 1: Export spike — load everything headlessly

Proves the riskiest assumption first: the app's providers load every season under `flutter test` with the web's no-key, snapshot-only setup.

**Files:**
- Create: `lib/site_export/load_container.dart`
- Create: `tool/export_site_data_test.dart`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `Future<ProviderContainer> loadSiteContainer()` — a container whose `appDataProvider` has completed (all seasons, percentiles).

- [ ] **Step 1: Make sure the remote-season snapshot exists locally**

Run (Git Bash, from the repo root; values come from your local `assets/.env.json`):
```bash
ls assets/prefetched/
```
Expected: `remote_config.json season29.json season30.json` (or more). If missing:
```bash
SHEETS_API_KEY=$(jq -r .SHEETS_API_KEY assets/.env.json) REMOTE_CONFIG_URL=$(jq -r .REMOTE_CONFIG_URL assets/.env.json) dart run tool/prefetch_seasons.dart
```

- [ ] **Step 2: Write the loader**

`lib/site_export/load_container.dart`:
```dart
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/asset_season_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's real loading pipeline, set up like the web build: no keys, no
/// network, remote seasons and the config read from the `assets/prefetched/`
/// snapshot. Resolves once every season is loaded and percentiles are final.
Future<ProviderContainer> loadSiteContainer() async {
  final container = ProviderContainer(overrides: [
    // A local `.env.json` holds real keys; the export must never use them.
    envJsonProvider.overrideWith((ref) async => const <String, String>{}),
    seasonCacheServiceProvider
        .overrideWithValue(AssetSeasonCacheService(rootBundle)),
  ]);
  await container.read(appDataProvider.future);
  return container;
}
```

- [ ] **Step 3: Write the entry point as a spike that only proves loading**

`tool/export_site_data_test.dart`:
```dart
// Run with: flutter test tool/export_site_data_test.dart
// Writes the site's JSON into site/data/ (override with SITE_DATA_DIR).
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/site_export/load_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export site data', () async {
    final container = await loadSiteContainer();
    addTearDown(container.dispose);

    final configs = container.read(loadedSeasonConfigsProvider);
    final ratings = container.read(ratingRepositoryProvider);
    expect(configs.length, greaterThan(20));
    expect(ratings.keys, containsAll(configs.map((c) => c.id)));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
```

- [ ] **Step 4: Run the spike**

Run: `flutter test tool/export_site_data_test.dart`
Expected: `All tests passed!`. If it fails on `compute`/isolates or `rootBundle`, stop and report the error — the export approach needs revisiting before anything else is built.

- [ ] **Step 5: Ignore the generated data**

Append to `.gitignore`:
```
# Stats site: JSON exported by tool/export_site_data_test.dart, and build output
site/data/
site/dist/
site/node_modules/
site/.astro/
```

- [ ] **Step 6: Commit**
```bash
git add lib/site_export/load_container.dart tool/export_site_data_test.dart .gitignore
git commit -m "feat(site): load every season headlessly for the site export"
```

---

### Task 2: Table shape, formats and slugs

**Files:**
- Create: `lib/site_export/site_table.dart`, `lib/site_export/formats.dart`, `lib/site_export/slugs.dart`
- Test: `test/site_export/site_table_test.dart`, `test/site_export/formats_test.dart`, `test/site_export/slugs_test.dart`

**Interfaces:**
- Produces:
  - `class SiteColumn(String label, {bool numeric = true, String? tip, String? group, bool phone = true})` with `toJson()`
  - `class SiteCell(String t, {num? s, String? link, String? tone})` with `toJson()` — non-finite `s` is dropped
  - `class SiteTable({required List<SiteColumn> columns, required List<List<SiteCell>> rows, String? title, String? empty, int? sortColumn, bool desc = true, bool showRank = false, int? collapsed})` with `toJson()`; asserts every row has `columns.length` cells
  - `String pct0(double)`, `String pct1(double)`, `String f2(double)`, `String signed2(double)`, `String rounded(double v, int decimals)`, `String seasonLabel(int?)`, `String roleLabel(Role)`, `String initials(String)`, `int roleCount(List<(String, int)>, Role)`, `double rolePoints(List<(String, double)>, Role)`, `const kRoleOrder = [Role.civilian, Role.sheriff, Role.mafia, Role.don]`
  - `String slugify(String name)`, `Map<int, String> assignSlugs(List<Player> players)`

- [ ] **Step 1: Write failing tests**

`test/site_export/site_table_test.dart`:
```dart
import 'dart:convert';

import 'package:family_mafia_app/site_export/site_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cells drop non-finite sort keys so jsonEncode never throws', () {
    final table = SiteTable(
      columns: const [SiteColumn('Player', numeric: false), SiteColumn('WR')],
      rows: [
        [const SiteCell('Sasha', link: 'sasha'), SiteCell('–', s: 0 / 0)],
        [const SiteCell('Olya'), SiteCell('–', s: 1 / 0)],
      ],
    );
    final json = jsonDecode(jsonEncode(table.toJson())) as Map<String, dynamic>;
    final rows = json['rows'] as List;
    expect((rows[0] as List)[1], {'t': '–'});
    expect((rows[0] as List)[0], {'t': 'Sasha', 'link': 'sasha'});
    expect(json['desc'], true);
    expect(json['showRank'], false);
  });

  test('a row with the wrong number of cells is rejected', () {
    expect(
      () => SiteTable(columns: const [SiteColumn('A')], rows: [[], ]).toJson(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('columns only serialise what is set', () {
    expect(const SiteColumn('W/G', group: 'Don', phone: false).toJson(),
        {'label': 'W/G', 'numeric': true, 'group': 'Don', 'phone': false});
  });
}
```

`test/site_export/formats_test.dart`:
```dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('number formats match the app widgets', () {
    expect(pct0(0.546), '55%');
    expect(pct1(0.6123), '61.2%');
    expect(f2(1.0), '1.00');
    expect(signed2(0.5), '+0.50');
    expect(signed2(-0.25), '-0.25');
    expect(signed2(0), '0.00');
    expect(rounded(2.41666, 2), '2.42');
    expect(seasonLabel(null), 'All time');
    expect(seasonLabel(21), 'S21');
  });

  test('initials follow the profile screen', () {
    expect(initials('Олександр Сізов'), 'ОС');
    expect(initials('Sasha'), 'S');
    expect(initials('  '), '?');
  });

  test('role sums accept every sheet spelling of a role', () {
    const games = [('Мирний', 3), ('Мирный', 2), ('Дон', 1)];
    expect(roleCount(games, Role.civilian), 5);
    expect(roleCount(games, Role.sheriff), 0);
    expect(rolePoints(const [('Дон', 0.5), ('Дон', 0.25)], Role.don), 0.75);
  });
}
```

`test/site_export/slugs_test.dart`:
```dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/site_export/slugs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ukrainian and Russian letters are transliterated', () {
    expect(slugify('Олександр Сізов'), 'oleksandr-sizov');
    expect(slugify('Юлія Щербак'), 'iuliia-shcherbak');
    expect(slugify('Аркадий Эйдельман'), 'arkadii-eidelman');
    expect(slugify("Мар'яна"), 'mariana');
    expect(slugify('Марʼяна'), 'mariana');
  });

  test('Latin, digits and punctuation', () {
    expect(slugify('DJ Max 2000!'), 'dj-max-2000');
    expect(slugify('...'), '');
  });

  test('every player gets a unique, non-empty slug', () {
    const players = [
      Player(id: 1, displayName: 'Саша'),
      Player(id: 2, displayName: 'саша'),
      Player(id: 3, displayName: 'Оля'),
      Player(id: 4, displayName: '???'),
    ];
    final slugs = assignSlugs(players);
    expect(slugs[1], 'sasha-1');
    expect(slugs[2], 'sasha-2');
    expect(slugs[3], 'olia');
    expect(slugs[4], 'player-4');
    expect(slugs.values.toSet(), hasLength(4));
  });
}
```

- [ ] **Step 2: Run them — they fail**

Run: `flutter test test/site_export/`
Expected: FAIL, `Target of URI doesn't exist` for the three imports.

- [ ] **Step 3: Implement**

`lib/site_export/site_table.dart`:
```dart
/// The one table shape the site renders. Text is formatted here, in Dart, the
/// way the app's widgets format it; the site only lays out and sorts.
class SiteColumn {
  const SiteColumn(this.label,
      {this.numeric = true, this.tip, this.group, this.phone = true});

  final String label;

  /// Right-aligned, tabular figures.
  final bool numeric;

  /// Header tooltip, for abbreviations.
  final String? tip;

  /// Shared header above adjacent columns, e.g. a role name.
  final String? group;

  /// Shown on phones; hidden columns move into the row's expandable details.
  final bool phone;

  Map<String, Object?> toJson() => {
        'label': label,
        'numeric': numeric,
        if (tip != null) 'tip': tip,
        if (group != null) 'group': group,
        if (!phone) 'phone': false,
      };
}

class SiteCell {
  const SiteCell(this.t, {this.s, this.link, this.tone});

  /// Display text.
  final String t;

  /// Sort key; cells without one sort by text, after the ones that have one.
  final num? s;

  /// Player slug to link to.
  final String? link;

  /// `wr` (colour by [s] as a win rate), `pos`, `neg`.
  final String? tone;

  Map<String, Object?> toJson() => {
        't': t,
        if (s != null && s!.isFinite) 's': s,
        if (link != null) 'link': link,
        if (tone != null) 'tone': tone,
      };
}

class SiteTable {
  const SiteTable({
    required this.columns,
    required this.rows,
    this.title,
    this.empty,
    this.sortColumn,
    this.desc = true,
    this.showRank = false,
    this.collapsed,
  });

  final List<SiteColumn> columns;
  final List<List<SiteCell>> rows;
  final String? title;

  /// Shown instead of the table when [rows] is empty.
  final String? empty;

  /// Column the rows are initially sorted by; null keeps the given order.
  final int? sortColumn;
  final bool desc;
  final bool showRank;

  /// Rows shown before "Show all".
  final int? collapsed;

  Map<String, Object?> toJson() {
    assert(rows.every((r) => r.length == columns.length),
        'every row needs ${columns.length} cells');
    return {
      if (title != null) 'title': title,
      if (empty != null) 'empty': empty,
      'columns': [for (final c in columns) c.toJson()],
      'rows': [
        for (final r in rows) [for (final c in r) c.toJson()]
      ],
      if (sortColumn != null) 'sortColumn': sortColumn,
      'desc': desc,
      'showRank': showRank,
      if (collapsed != null) 'collapsed': collapsed,
    };
  }
}
```

`lib/site_export/formats.dart`:
```dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';

/// The formats the app's widgets use, so the site shows the same text.
String pct0(double v) => '${(v * 100).toStringAsFixed(0)}%';
String pct1(double v) => '${(v * 100).roundTo(1)}%';
String f2(double v) => v.toStringAsFixed(2);
String signed2(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
String rounded(double v, int decimals) => v.roundTo(decimals).toString();
String seasonLabel(int? s) => s == null ? 'All time' : 'S$s';

/// City first, then mafia — the column order of the season ratings table.
const kRoleOrder = [Role.civilian, Role.sheriff, Role.mafia, Role.don];

String roleLabel(Role r) => switch (r) {
      Role.civilian => 'Civilian',
      Role.sheriff => 'Sheriff',
      Role.mafia => 'Mafia',
      Role.don => 'Don',
    };

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

int roleCount(List<(String, int)> perRole, Role role) => perRole
    .where((e) => role.sheetValues.contains(e.$1))
    .fold(0, (s, e) => s + e.$2);

double rolePoints(List<(String, double)> perRole, Role role) => perRole
    .where((e) => role.sheetValues.contains(e.$1))
    .fold(0.0, (s, e) => s + e.$2);
```

`lib/site_export/slugs.dart`:
```dart
import 'package:family_mafia_app/models/player.dart';

// Ukrainian national transliteration (simplified: no word-initial forms),
// plus the Russian letters that appear in older sheets.
const _latin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'h', 'ґ': 'g', 'д': 'd', 'е': 'e',
  'є': 'ie', 'ж': 'zh', 'з': 'z', 'и': 'y', 'і': 'i', 'ї': 'i', 'й': 'i',
  'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
  'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch',
  'ш': 'sh', 'щ': 'shch', 'ь': '', 'ю': 'iu', 'я': 'ia',
  'ы': 'y', 'э': 'e', 'ъ': '', 'ё': 'io',
  "'": '', '’': '', 'ʼ': '',
};

/// Lowercase Latin words joined by hyphens; empty when nothing is left.
String slugify(String name) {
  final out = StringBuffer();
  for (final ch in name.toLowerCase().split('')) {
    out.write(_latin[ch] ?? ch);
  }
  return out
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Player id → URL slug. Colliding or empty slugs get `-<id>` appended, so the
/// result is unique; throws if it somehow is not.
Map<int, String> assignSlugs(List<Player> players) {
  final base = {for (final p in players) p.id: slugify(p.displayName)};
  final counts = <String, int>{};
  for (final s in base.values) {
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final slugs = {
    for (final MapEntry(key: id, value: s) in base.entries)
      id: s.isEmpty
          ? 'player-$id'
          : counts[s]! > 1
              ? '$s-$id'
              : s,
  };
  if (slugs.values.toSet().length != slugs.length) {
    throw StateError('Duplicate player slugs: $slugs');
  }
  return slugs;
}
```

- [ ] **Step 4: Run tests — they pass**

Run: `flutter test test/site_export/`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/site_export/site_table.dart lib/site_export/formats.dart lib/site_export/slugs.dart test/site_export/
git commit -m "feat(site): display-ready table shape, app number formats, player slugs"
```

---

### Task 3: Test fixture and export context

**Files:**
- Create: `lib/site_export/export_context.dart`
- Create: `test/site_export/fixture.dart`
- Test: `test/site_export/export_context_test.dart`

**Interfaces:**
- Consumes: `assignSlugs` (Task 2), `SiteCell` (Task 2).
- Produces:
  - `class ExportContext(ProviderContainer container)` with `final List<Player> players` (= `playersListProvider`), `final Map<int, String> slugs`, `T read<T>(ProviderListenable<T>)`, `SiteCell name(Player p)`, `void select(SeasonConfig season, League league)`, `List<SeasonConfig> get seasons` (sorted by id).
  - Test helper `Future<ProviderContainer> fixtureContainer({List<int> seasonIds = const [17, 21]})` and `const kFixtureTournament`.

- [ ] **Step 1: Write the fixture**

`test/site_export/fixture.dart`:
```dart
import 'dart:io';

import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const kFixtureTournament = Tournament(
  seasonId: 21,
  type: TournamentType.minicap,
  name: 'Fixture cup',
  games: 3,
);

/// Real bundled seasons loaded through [SeasonLoaderService] into a container,
/// the way `loadSiteContainer` ends up — without assets or a snapshot.
Future<ProviderContainer> fixtureContainer(
    {List<int> seasonIds = const [17, 21]}) async {
  final players = PlayersRepository();
  final games = GamesRepository();
  final ratings = RatingRepository();
  final seasons = SeasonRepository();
  final percentiles = RolePercentilesRepository();
  final loader =
      SeasonLoaderService(players, games, ratings, seasons, percentiles);

  final configs = Season.allConfigs()
      .where((c) => seasonIds.contains(c.id))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  await loader.loadSeasons(
    metas: [
      for (final c in configs) SeasonMeta(c.id, c.gameLimit, c.gamesMultiplier)
    ],
    playersJson: File('assets/raw/players.json').readAsStringSync(),
    seasonJsons: [
      for (final c in configs)
        File('assets/raw/season${c.id}.json').readAsStringSync()
    ],
  );
  await loader.recomputePercentiles(
      players: players.state, games: games.state);

  final container = ProviderContainer(overrides: [
    playersRepositoryProvider.overrideWith((ref) => players),
    gamesRepositoryProvider.overrideWith((ref) => games),
    ratingRepositoryProvider.overrideWith((ref) => ratings),
    seasonRepositoryProvider.overrideWith((ref) => seasons),
    rolePercentilesRepositoryProvider.overrideWith((ref) => percentiles),
    tournamentsProvider.overrideWithValue(const [kFixtureTournament]),
  ]);
  container.read(loadedSeasonConfigsProvider.notifier).state = configs;
  addTearDown(container.dispose);
  return container;
}
```

- [ ] **Step 2: Write the failing test**

`test/site_export/export_context_test.dart`:
```dart
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('slugs cover every listed player and name cells link to them', () async {
    final x = ExportContext(await fixtureContainer());
    expect(x.players, isNotEmpty);
    expect(x.slugs.keys.toSet(), x.players.map((p) => p.id).toSet());
    final cell = x.name(x.players.first);
    expect(cell.t, x.players.first.displayName);
    expect(cell.link, x.slugs[x.players.first.id]);
  });

  test('select switches season and league', () async {
    final x = ExportContext(await fixtureContainer());
    expect(x.seasons.map((s) => s.id), [17, 21]);
    x.select(x.seasons.last, League.small);
    expect(x.read(selectedSeasonProvider)!.id, 21);
    expect(x.read(selectedLeagueProvider), League.small);
  });
}
```

- [ ] **Step 3: Run — fails**

Run: `flutter test test/site_export/export_context_test.dart`
Expected: FAIL, `export_context.dart` does not exist.

- [ ] **Step 4: Implement**

`lib/site_export/export_context.dart`:
```dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/site_export/site_table.dart';
import 'package:family_mafia_app/site_export/slugs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What every export module needs: the loaded container, the players the
/// site has pages for, and their slugs.
class ExportContext {
  ExportContext(this.container)
      : players = container.read(playersListProvider),
        slugs = assignSlugs(container.read(playersListProvider));

  final ProviderContainer container;

  /// The players the app lists (junk names excluded), most games first.
  final List<Player> players;
  final Map<int, String> slugs;

  T read<T>(ProviderListenable<T> provider) => container.read(provider);

  /// A player's name, linked when the site has a page for them.
  SiteCell name(Player p) => SiteCell(p.displayName, link: slugs[p.id]);

  /// Sets the providers the Season tab reads, as the user would.
  void select(SeasonConfig season, League league) {
    container.read(selectedSeasonProvider.notifier).state = season;
    container.read(gameLimitOverrideProvider.notifier).state = null;
    container.read(selectedLeagueProvider.notifier).state = league;
  }

  List<SeasonConfig> get seasons =>
      [...read(loadedSeasonConfigsProvider)]..sort((a, b) => a.id.compareTo(b.id));
}
```

- [ ] **Step 5: Run — passes**

Run: `flutter test test/site_export/export_context_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**
```bash
git add lib/site_export/export_context.dart test/site_export/fixture.dart test/site_export/export_context_test.dart
git commit -m "feat(site): export context with slugs and season selection, plus fixture"
```

---

### Task 4: Season export

**Files:**
- Create: `lib/site_export/season_export.dart`
- Test: `test/site_export/season_export_test.dart`

**Interfaces:**
- Consumes: `ExportContext` (Task 3); `SiteTable`, `SiteColumn`, `SiteCell` and formats (Task 2).
- Produces: `Map<String, Object?> seasonJson(ExportContext x, SeasonConfig season)` with keys:
  `id, title, gameLimit, smallLeagueMinGames, summary {games, players, cityWR, mafiaWR} | null, leagueCounts {main, small} | null, tournaments [{type, label, name, games, date, podium}], tournamentCounts [{type, label, count}], leagues {main: League, small: League}` where League = `{ratings: SiteTable, stats: [StatItem], awards?: [Award]}`, StatItem = `{label, winner, table?: SiteTable}`, Award = `{key, label, winner, winnerLink?, table: SiteTable}`.

- [ ] **Step 1: Write failing tests**

`test/site_export/season_export_test.dart`:
```dart
import 'dart:convert';

import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/season_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  late ExportContext x;
  setUp(() async => x = ExportContext(await fixtureContainer()));

  test('ratings rows equal currentSeasonStatsProvider for both leagues', () {
    final season = x.seasons.last;
    final json = seasonJson(x, season);
    for (final league in League.values) {
      x.select(season, league);
      final expected = x.read(currentSeasonStatsProvider)!.playerStats;
      final table = (json['leagues'] as Map)[league.name]['ratings'] as Map;
      final rows = table['rows'] as List;
      expect(rows.map((r) => (r as List).first['t']),
          expected.map((p) => p.player.displayName), reason: league.name);
    }
  });

  test('the JSON encodes (no NaN) and has every section', () {
    final json = jsonDecode(jsonEncode(seasonJson(x, x.seasons.last))) as Map;
    expect(json['summary']['games'], greaterThan(0));
    final main = json['leagues']['main'] as Map;
    expect((main['awards'] as List).map((a) => a['key']),
        ['mvp', 'sheriff', 'civilian', 'mafia', 'don', 'mostKilled']);
    expect((main['stats'] as List).map((s) => s['label']), [
      'Most Games', 'Top ПУ %', 'Most Hosted', 'Host avg доп',
      'Host avg мінус', 'No host',
    ]);
    final small = json['leagues']['small'] as Map;
    expect(small.containsKey('awards'), isFalse);
    expect((small['stats'] as List).map((s) => s['label']),
        ['Most Games', 'Top ПУ %']);
    expect(json['tournamentCounts'], [
      {'type': 'minicap', 'label': 'Minicap', 'count': 1}
    ]);
  });

  test('an empty league carries the app empty message', () {
    final season = x.seasons.first;
    final json = seasonJson(x, season);
    for (final league in League.values) {
      final t = json['leagues'][league.name]['ratings'] as Map;
      expect(t['empty'], isNotEmpty);
      if ((t['rows'] as List).isEmpty) {
        expect(t['empty'], anyOf(startsWith('No players in the'),
            startsWith('No players have played at least')));
      }
    }
  });

  test('a name with no player page is plain text', () {
    final json = seasonJson(x, x.seasons.last);
    final stats = json['leagues']['main']['stats'] as List;
    final hosted = stats.firstWhere((s) => s['label'] == 'Most Hosted');
    for (final row in (hosted['table']['rows'] as List)) {
      final cell = (row as List).first as Map;
      if (cell['link'] != null) {
        expect(x.slugs.values, contains(cell['link']));
      }
    }
  });
}
```

- [ ] **Step 2: Run — fails**

Run: `flutter test test/site_export/season_export_test.dart`
Expected: FAIL, `season_export.dart` does not exist.

- [ ] **Step 3: Implement**

`lib/site_export/season_export.dart`:
```dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Everything the Season tab shows for [season], both leagues.
Map<String, Object?> seasonJson(ExportContext x, SeasonConfig season) {
  final leagues = <String, Object?>{};
  for (final league in League.values) {
    x.select(season, league);
    final stats = x.read(currentSeasonStatsProvider);
    final extra = x.read(seasonExtraStatsProvider);
    leagues[league.name] = {
      'ratings': _ratings(x, season, league, stats).toJson(),
      'stats': extra == null
          ? const []
          : _statItems(x, extra, showHosts: league == League.main),
      if (league == League.main && stats != null) 'awards': _awards(x, stats),
    };
  }

  x.select(season, League.main);
  final summary = x.read(seasonSummaryProvider);
  final counts = x.read(seasonLeagueCountsProvider);
  final extra = x.read(seasonExtraStatsProvider);
  final tournaments =
      x.read(tournamentsProvider).where((t) => t.seasonId == season.id);
  return {
    'id': season.id,
    'title': season.title,
    'gameLimit': season.gameLimit,
    'smallLeagueMinGames': season.smallLeagueMinGames,
    'summary': summary == null
        ? null
        : {
            'games': summary.games,
            'players': summary.players,
            'cityWR': summary.cityWR,
            'mafiaWR': summary.mafiaWR,
          },
    'leagueCounts':
        counts == null ? null : {'main': counts.main, 'small': counts.small},
    'tournaments': [
      for (final t in tournaments)
        {
          'type': t.type.name,
          'label': t.type.label,
          'name': t.name,
          'games': t.games,
          'date': t.date,
          'podium': t.podium,
        }
    ],
    'tournamentCounts': [
      for (final MapEntry(key: type, value: count)
          in (extra?.tournaments ?? const {}).entries)
        {'type': type.name, 'label': type.label, 'count': count}
    ],
    'leagues': leagues,
  };
}

SiteTable _ratings(ExportContext x, SeasonConfig season, League league,
    SeasonStats? stats) {
  final limit = x.read(effectiveGameLimitProvider);
  final protocol = season.id >= 29;
  SiteCell signedCell(double v) => SiteCell(
        v >= 0 ? '+${v.roundTo(2)}' : '${v.roundTo(2)}',
        s: v,
        tone: v > 0 ? 'pos' : v < 0 ? 'neg' : null,
      );

  return SiteTable(
    showRank: true,
    empty: league == League.small
        ? 'No players in the ${season.smallLeagueMinGames}–${limit - 1} game range'
        : 'No players have played at least $limit games',
    columns: [
      const SiteColumn('Player', numeric: false),
      const SiteColumn('WR'),
      const SiteColumn('Rating'),
      const SiteColumn('Games', tip: 'Wins / games'),
      const SiteColumn('Add. Pts', tip: 'Additional points from the host (доп)', phone: false),
      const SiteColumn('Penalty', phone: false),
      SiteColumn(protocol ? 'Support 5' : 'Best Move', phone: false),
      const SiteColumn('MVP', phone: false),
      const SiteColumn('CI/Game', tip: 'Compensation for being killed first, per game', phone: false),
      const SiteColumn('CI', tip: 'Compensation for being killed first', phone: false),
      const SiteColumn('Death %', phone: false),
      const SiteColumn('First Killed', tip: 'ПУ — killed on the first night', phone: false),
      const SiteColumn('City Lost', tip: 'Killed first and the city lost', phone: false),
      if (protocol) ...const [
        SiteColumn('Protocol Pts', phone: false),
        SiteColumn('Guesses', tip: 'Correct / total colour guesses', phone: false),
      ],
      for (final r in kRoleOrder) ...[
        SiteColumn('W/G', group: roleLabel(r), phone: false),
        SiteColumn('±', group: roleLabel(r), tip: 'Points in this role', phone: false),
      ],
    ],
    rows: [
      for (final p in stats?.playerStats ?? const <RatingPlayerStats>[])
        [
          x.name(p.player),
          SiteCell(pct1(p.winRate), s: p.winRate, tone: 'wr'),
          SiteCell(rounded(p.ratingCoefficient, 2), s: p.ratingCoefficient),
          SiteCell('${p.wins}/${p.gamesPlayed}', s: p.gamesPlayed),
          SiteCell(rounded(p.additionalPoints, 2),
              s: p.additionalPoints, tone: p.additionalPoints > 0 ? 'pos' : null),
          SiteCell(rounded(p.penaltyPoints, 2),
              s: p.penaltyPoints, tone: p.penaltyPoints > 0 ? 'neg' : null),
          SiteCell(rounded(p.bestMovePoints, 2),
              s: p.bestMovePoints, tone: p.bestMovePoints > 0 ? 'pos' : null),
          SiteCell(rounded(p.mvp, 4), s: p.mvp),
          SiteCell(rounded(p.ciForGame, 3), s: p.ciForGame),
          SiteCell(rounded(p.ci, 3), s: p.ci),
          SiteCell('${(p.percentOfDeath * 100).roundTo(1)}%', s: p.percentOfDeath),
          SiteCell('${p.firstKilled}', s: p.firstKilled),
          SiteCell('${p.firstKilledCityLost}', s: p.firstKilledCityLost),
          if (protocol) ...[
            SiteCell(rounded(p.protocolPoints, 2), s: p.protocolPoints),
            SiteCell('${p.protocolCorrectGuesses}/${p.protocolTotalGuesses}',
                s: p.protocolTotalGuesses == 0
                    ? null
                    : p.protocolCorrectGuesses / p.protocolTotalGuesses),
          ],
          for (final r in kRoleOrder) ...[
            _roleWinsCell(p, r),
            signedCell(rolePoints(p.bestMoveAndAdditionalPointsByRole, r)),
          ],
        ]
    ],
  );
}

SiteCell _roleWinsCell(RatingPlayerStats p, Role r) {
  final games = roleCount(p.gamesForRole, r);
  final wins = roleCount(p.winByRole, r);
  return games == 0
      ? const SiteCell('–')
      : SiteCell('$wins/$games', s: wins / games, tone: 'wr');
}

/// The Season Awards card (`season_header_card.dart`), main league only.
List<Map<String, Object?>> _awards(ExportContext x, SeasonStats stats) {
  RatingPlayerStats? byId(int id) =>
      stats.playerStats.where((p) => p.player.id == id).firstOrNull;

  SiteCell seasonPts(RatingPlayerStats p) => p.gamesPlayed == 0
      ? const SiteCell('—')
      : _signedCell(p.additionalPoints / p.gamesPlayed);

  SiteCell rolePts(RatingPlayerStats p, Role role) {
    final games = roleCount(p.gamesForRole, role);
    if (games == 0) return const SiteCell('—');
    return _signedCell(rolePoints(p.bestMoveAndAdditionalPointsByRole, role) / games);
  }

  SiteCell record(RatingPlayerStats p, Role role) {
    final games = roleCount(p.gamesForRole, role);
    final wins = roleCount(p.winByRole, role);
    if (games == 0) return const SiteCell('—');
    return SiteCell('$wins/$games  ${(wins / games * 100).toStringAsFixed(1)}%',
        s: wins / games, tone: 'wr');
  }

  Map<String, Object?> award(String key, String label, List<int> ranking,
      String metric, SiteCell Function(RatingPlayerStats) points,
      SiteCell Function(RatingPlayerStats) detail) {
    final ranked = [
      for (final id in ranking)
        if (byId(id) case final p?) p
    ];
    final winner = ranked.firstOrNull;
    return {
      'key': key,
      'label': label,
      'winner': winner?.player.displayName ?? '—',
      if (winner != null && x.slugs[winner.player.id] != null)
        'winnerLink': x.slugs[winner.player.id],
      'table': SiteTable(
        showRank: true,
        empty: 'Nobody qualified.',
        columns: [
          const SiteColumn('Player', numeric: false),
          const SiteColumn('Avg pts'),
          SiteColumn(metric),
        ],
        rows: [
          for (final p in ranked) [x.name(p.player), points(p), detail(p)]
        ],
      ).toJson(),
    };
  }

  return [
    award('mvp', 'MVP', stats.mvpRanking, 'Score', seasonPts,
        (p) => SiteCell(p.mvp.toStringAsFixed(3), s: p.mvp)),
    award('sheriff', 'Sheriff', stats.bestSheriffRanking, 'Record',
        (p) => rolePts(p, Role.sheriff), (p) => record(p, Role.sheriff)),
    award('civilian', 'Civilian', stats.bestCivilianRanking, 'Record',
        (p) => rolePts(p, Role.civilian), (p) => record(p, Role.civilian)),
    award('mafia', 'Mafia', stats.bestMafiaRanking, 'Record',
        (p) => rolePts(p, Role.mafia), (p) => record(p, Role.mafia)),
    award('don', 'Don', stats.bestDonRanking, 'Record',
        (p) => rolePts(p, Role.don), (p) => record(p, Role.don)),
    award('mostKilled', 'Most Killed', stats.mostKilledRanking, 'Deaths',
        seasonPts, (p) => SiteCell('${p.firstKilled}', s: p.firstKilled)),
  ];
}

SiteCell _signedCell(double v) =>
    SiteCell(signed2(v), s: v, tone: v > 0 ? 'pos' : v < 0 ? 'neg' : null);

/// The Season Stats card (`season_stats_card.dart`).
List<Map<String, Object?>> _statItems(ExportContext x, SeasonExtraStats s,
    {required bool showHosts}) {
  String first<T>(List<T> l, String Function(T) f) =>
      l.isEmpty ? '—' : f(l.first);
  Map<String, Object?> item(String label, String winner, String empty,
          String a, String b, List<List<SiteCell>> rows) =>
      {
        'label': label,
        'winner': winner,
        'table': SiteTable(
          showRank: true,
          empty: empty,
          columns: [
            const SiteColumn('Player', numeric: false),
            SiteColumn(a),
            SiteColumn(b),
          ],
          rows: rows,
        ).toJson(),
      };
  final hostEmpty = 'No host hosted $kHostMinGamesForAverage+ games.';

  return [
    item(
      'Most Games',
      first(s.mostGames, (p) => '${p.player.displayName} · ${p.gamesPlayed}'),
      'No players in this league.', 'WR', 'Games',
      [
        for (final p in s.mostGames)
          [
            x.name(p.player),
            SiteCell(pct0(p.winRate), s: p.winRate, tone: 'wr'),
            SiteCell('${p.gamesPlayed}', s: p.gamesPlayed),
          ]
      ],
    ),
    item(
      'Top ПУ %',
      first(s.topFirstKilledPct,
          (p) => '${p.player.displayName} · ${pct0(p.percentOfDeath)}'),
      'No red games in this league.', 'ПУ', '% of red',
      [
        for (final p in s.topFirstKilledPct)
          [
            x.name(p.player),
            SiteCell('${p.firstKilled}/${redGames(p)}', s: p.firstKilled),
            SiteCell(pct0(p.percentOfDeath), s: p.percentOfDeath),
          ]
      ],
    ),
    if (showHosts) ...[
      item(
        'Most Hosted',
        first(s.mostHosted, (h) =>
            '${h.host.displayName} · ${h.hosted} (${s.seasonGames == 0 ? '—' : pct0(h.hosted / s.seasonGames)})'),
        'No host data for this season.', 'Share', 'Games',
        [
          for (final h in s.mostHosted)
            [
              x.name(h.host),
              s.seasonGames == 0
                  ? const SiteCell('—')
                  : SiteCell(pct0(h.hosted / s.seasonGames),
                      s: h.hosted / s.seasonGames),
              SiteCell('${h.hosted}', s: h.hosted),
            ]
        ],
      ),
      item(
        'Host avg доп',
        first(s.hostAvgPlus, (h) => '${h.host.displayName} · ${signed2(h.avgPlus)}'),
        hostEmpty, 'Games', 'Avg / game',
        [
          for (final h in s.hostAvgPlus)
            [x.name(h.host), SiteCell('${h.hosted}', s: h.hosted), _signedCell(h.avgPlus)]
        ],
      ),
      item(
        'Host avg мінус',
        first(s.hostAvgMinus, (h) => '${h.host.displayName} · ${signed2(h.avgMinus)}'),
        hostEmpty, 'Games', 'Avg / game',
        [
          for (final h in s.hostAvgMinus)
            [x.name(h.host), SiteCell('${h.hosted}', s: h.hosted), _signedCell(h.avgMinus)]
        ],
      ),
      {
        'label': 'No host',
        'winner': s.gamesWithoutHost == null
            ? 'No data'
            : '${s.gamesWithoutHost} games',
      },
    ],
  ];
}
```

- [ ] **Step 4: Run — passes**

Run: `flutter test test/site_export/season_export_test.dart`
Expected: PASS. If `tournamentCounts` is empty, check that `buildSeasonExtraStats` counts `kFixtureTournament` (season 21) — the fixture season ids must include 21.

- [ ] **Step 5: Commit**
```bash
git add lib/site_export/season_export.dart test/site_export/season_export_test.dart
git commit -m "feat(site): export the Season tab for both leagues"
```

---

### Task 5: Overview export

**Files:**
- Create: `lib/site_export/overview_export.dart`
- Test: `test/site_export/overview_export_test.dart`

**Interfaces:**
- Consumes: `ExportContext`, `SiteTable`, formats.
- Produces: `Map<String, Object?> overviewJson(ExportContext x)` with keys `seasons [{id, title}]` (ascending), `latestSeasonId`, `club {seasons, games, players, cityWR}`, `roleWR {civilian, sheriff, mafia, don}`, `leaderboardNote`, `leaderboards [{role, label, table}]`, `protocol SiteTable`, `seasonsTable SiteTable`.

- [ ] **Step 1: Write the failing test**

`test/site_export/overview_export_test.dart`:
```dart
import 'dart:convert';

import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/overview_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('overview mirrors the dashboard providers', () async {
    final x = ExportContext(await fixtureContainer());
    final json = jsonDecode(jsonEncode(overviewJson(x))) as Map;

    expect(json['latestSeasonId'], 21);
    expect((json['seasons'] as List).map((s) => s['id']), [17, 21]);
    expect(json['club']['games'], x.read(clubOverviewProvider).games);
    expect((json['roleWR'] as Map).keys,
        containsAll(['civilian', 'sheriff', 'mafia', 'don']));
    expect((json['leaderboards'] as List).map((l) => l['role']),
        ['civilian', 'sheriff', 'mafia', 'don']);

    final seasons = json['seasonsTable'] as Map;
    expect((seasons['rows'] as List), hasLength(2));
    expect((seasons['columns'] as List).first['label'], 'Season');
    for (final row in seasons['rows'] as List) {
      expect((row as List).length, (seasons['columns'] as List).length);
    }
  });
}
```

- [ ] **Step 2: Run — fails**

Run: `flutter test test/site_export/overview_export_test.dart`
Expected: FAIL, missing `overview_export.dart`.

- [ ] **Step 3: Implement**

`lib/site_export/overview_export.dart`:
```dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// The Dashboard tab, plus the season list every page's picker needs.
Map<String, Object?> overviewJson(ExportContext x) {
  final seasons = x.seasons;
  final club = x.read(clubOverviewProvider);
  final roleWR = x.read(roleWinRateProvider);
  final top = x.read(topPlayersByRoleProvider);

  return {
    'seasons': [
      for (final s in seasons) {'id': s.id, 'title': s.title}
    ],
    'latestSeasonId': seasons.last.id,
    'club': {
      'seasons': club.seasons,
      'games': club.games,
      'players': club.players,
      'cityWR': club.cityWR,
    },
    'roleWR': {for (final r in kRoleOrder) r.name: roleWR[r] ?? 0.0},
    'leaderboardNote':
        'All-time win rate, players with at least $kDashboardMinRatingGames rating games.',
    'leaderboards': [
      for (final r in kRoleOrder)
        {
          'role': r.name,
          'label': roleLabel(r),
          'table': SiteTable(
            showRank: true,
            empty: 'Nobody qualifies yet.',
            columns: const [
              SiteColumn('Player', numeric: false),
              SiteColumn('WR'),
              SiteColumn('Games'),
            ],
            rows: [
              for (final e in top[r] ?? const [])
                [
                  x.name(e.player),
                  SiteCell(pct1(e.wr), s: e.wr, tone: 'wr'),
                  SiteCell('${e.games}', s: e.games),
                ]
            ],
          ).toJson(),
        }
    ],
    'protocol': SiteTable(
      showRank: true,
      empty: 'No protocol data yet.',
      columns: const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Accuracy'),
        SiteColumn('Guesses', tip: 'Correct / total colour guesses'),
      ],
      rows: [
        for (final e in x.read(protocolGuessLeaderboardProvider))
          [
            x.name(e.player),
            SiteCell(pct1(e.accuracy), s: e.accuracy, tone: 'wr'),
            SiteCell('${e.correct}/${e.total}', s: e.total),
          ]
      ],
    ).toJson(),
    'seasonsTable': _seasonsTable(x.read(seasonRowsProvider)).toJson(),
  };
}

/// `seasons_table.dart`, column for column.
SiteTable _seasonsTable(List<SeasonRow> rows) {
  SiteCell named(NamedValue? v, String Function(num) fmt) => v == null
      ? const SiteCell('—')
      : SiteCell('${v.name} ${fmt(v.value)}', s: v.value);
  String pct(num v) => pct0(v.toDouble());
  String int_(num v) => '$v';
  String dec(num v) => v.toStringAsFixed(2);

  final named_ = <(String, NamedValue? Function(SeasonRow), String Function(num))>[
    ('Most games', (r) => r.mostGames, int_),
    ('MVP', (r) => r.mvp, dec),
    ('Most ПУ', (r) => r.mostKilled, int_),
    ('Top ПУ %', (r) => r.topKilledPct, pct),
    ('Most hosted', (r) => r.mostHosted, int_),
    ('Host avg +', (r) => r.hostAvgPlus, dec),
    ('Best Don', (r) => r.bestDon, pct),
    ('Best Sheriff', (r) => r.bestSheriff, pct),
    ('Best Civilian', (r) => r.bestCivilian, pct),
    ('Best Mafia', (r) => r.bestMafia, pct),
  ];

  return SiteTable(
    sortColumn: 0,
    columns: [
      const SiteColumn('Season'),
      const SiteColumn('Games'),
      const SiteColumn('City WR'),
      const SiteColumn('Mafia WR'),
      const SiteColumn('Players'),
      const SiteColumn('Main lg', tip: 'Players in the main league'),
      for (final t in TournamentType.values) SiteColumn('${t.label}s'),
      for (final (label, _, _) in named_) SiteColumn(label, numeric: false),
    ],
    rows: [
      for (final r in rows)
        [
          SiteCell('S${r.seasonId}', s: r.seasonId),
          SiteCell('${r.games}', s: r.games),
          SiteCell(pct0(r.cityWR), s: r.cityWR),
          SiteCell(pct0(r.mafiaWR), s: r.mafiaWR),
          SiteCell('${r.players}', s: r.players),
          SiteCell('${r.mainLeague}', s: r.mainLeague),
          for (final t in TournamentType.values)
            SiteCell('${r.tournaments[t] ?? 0}', s: r.tournaments[t] ?? 0),
          for (final (_, get, fmt) in named_) named(get(r), fmt),
        ]
    ],
  );
}
```

- [ ] **Step 4: Run — passes**

Run: `flutter test test/site_export/overview_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/site_export/overview_export.dart test/site_export/overview_export_test.dart
git commit -m "feat(site): export the all-time overview"
```

---

### Task 6: Players export (directory + profiles)

**Files:**
- Create: `lib/site_export/players_export.dart`
- Test: `test/site_export/players_export_test.dart`

**Interfaces:**
- Consumes: `ExportContext`, `SiteTable`, formats.
- Produces:
  - `Map<String, Object?> playersJson(ExportContext x)` → `{players: [PlayerSummary], table: SiteTable}`; PlayerSummary = `{id, slug, name, initials, games, winRate, seasons, latestRating}`.
  - `Map<String, Object?> playerJson(ExportContext x, Player p)` → PlayerSummary plus `accomplishments {total, main [1st,2nd,3rd], small [1st,2nd,3rd], awards {mvp, sheriff, don, civilian, mafia}, tournaments [{type, label, podiums, places [1st,2nd,3rd]}]}`, `timeline [{seasonId, title, games, league}]` (league ∈ main/small/below/none), `roles [{role, label, games, wins, share, top}]` (`top` = "Top 3%" text or null), `firstKill {total, cityLost, civSherGames}`, `bestMoves {firstKilled, zero, one, two, three}`.

- [ ] **Step 1: Write the failing test**

`test/site_export/players_export_test.dart`:
```dart
import 'dart:convert';

import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  late ExportContext x;
  setUp(() async => x = ExportContext(await fixtureContainer()));

  test('directory lists every player once, with slugs', () {
    final json = jsonDecode(jsonEncode(playersJson(x))) as Map;
    final players = json['players'] as List;
    expect(players.map((p) => p['id']), x.players.map((p) => p.id));
    expect(players.map((p) => p['slug']).toSet(), hasLength(players.length));
    expect(players.any((p) => ['/', '.', '..', ''].contains(p['name'])), isFalse);
    expect((json['table']['rows'] as List), hasLength(players.length));
  });

  test('profile numbers come from the profile providers', () {
    final p = x.players.first; // most games
    final json = jsonDecode(jsonEncode(playerJson(x, p))) as Map;
    final stats = x.read(playerStatsMapProvider)[p.displayName]!;
    expect(json['games'], stats.games);
    expect(json['slug'], x.slugs[p.id]);
    expect((json['timeline'] as List).map((t) => t['seasonId']), [17, 21]);
    final roleGames = (json['roles'] as List).fold<int>(0, (s, r) => s + (r['games'] as int));
    expect(roleGames, greaterThan(0));
    final bm = json['bestMoves'] as Map;
    expect(bm['zero'] + bm['one'] + bm['two'] + bm['three'], bm['firstKilled']);
  });
}
```

- [ ] **Step 2: Run — fails**

Run: `flutter test test/site_export/players_export_test.dart`
Expected: FAIL, missing `players_export.dart`.

- [ ] **Step 3: Implement**

`lib/site_export/players_export.dart`:
```dart
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/stats/player_leagues.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Profile order of the role bars (`role_distribution_section.dart`).
const _profileRoleOrder = [Role.civilian, Role.mafia, Role.sheriff, Role.don];

Map<String, Object?> _summary(ExportContext x, Player p) {
  final stats = x.read(playerStatsMapProvider)[p.displayName];
  final seasons = x
          .read(seasonGamesProvider)
          .where((e) => e.name == p.displayName)
          .firstOrNull
          ?.seasonData
          .length ??
      0;
  return {
    'id': p.id,
    'slug': x.slugs[p.id],
    'name': p.displayName,
    'initials': initials(p.displayName),
    'games': stats?.games ?? 0,
    'winRate': stats?.winRate ?? 0.0,
    'seasons': seasons,
    'latestRating': x.read(latestSeasonRatingProvider(p)),
  };
}

/// The Players tab.
Map<String, Object?> playersJson(ExportContext x) {
  final summaries = [for (final p in x.players) _summary(x, p)];
  return {
    'players': summaries,
    'table': SiteTable(
      showRank: true,
      sortColumn: 1,
      columns: const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Games'),
        SiteColumn('WR'),
        SiteColumn('Seasons'),
        SiteColumn('Rating', tip: 'Rating in the latest season played', phone: false),
      ],
      rows: [
        for (final s in summaries)
          [
            SiteCell(s['name']! as String, link: s['slug'] as String?),
            SiteCell('${s['games']}', s: s['games'] as int),
            SiteCell(pct0(s['winRate']! as double),
                s: s['winRate'] as double, tone: 'wr'),
            SiteCell('${s['seasons']}', s: s['seasons'] as int),
            switch (s['latestRating']) {
              final double r => SiteCell(rounded(r, 2), s: r),
              _ => const SiteCell('—'),
            },
          ]
      ],
    ).toJson(),
  };
}

/// One player's profile.
Map<String, Object?> playerJson(ExportContext x, Player p) {
  final acc = x.read(playerAccomplishmentsProvider(p));
  final leagues = x.read(playerLeaguesProvider(p));
  final perSeason = {
    for (final e in x
            .read(seasonGamesProvider)
            .where((e) => e.name == p.displayName)
            .firstOrNull
            ?.seasonData ??
        const <SeasonEntry>[])
      e.seasonId: e.games
  };

  final roleGames = <Role, int>{};
  for (final MapEntry(key: value, value: n) in x.read(playerRoleGamesProvider(p)).entries) {
    if (Role.findByValue(value) case final r?) roleGames[r] = (roleGames[r] ?? 0) + n;
  }
  final roleWins = <Role, int>{};
  for (final MapEntry(key: value, value: n) in x.read(playerRoleWinsProvider(p)).entries) {
    if (Role.findByValue(value) case final r?) roleWins[r] = (roleWins[r] ?? 0) + n;
  }
  final totalRoleGames = roleGames.values.fold(0, (a, b) => a + b);
  final percentiles = x.read(roleWinRatePercentilesProvider(p));
  String? top(double? v) =>
      v == null ? null : 'Top ${v < 1 ? v.toStringAsFixed(1) : v.toInt()}%';

  final fk = x.read(playerFirstKillProvider(p));
  final bm = x.read(playerBestMovesProvider(p));

  return {
    ..._summary(x, p),
    'accomplishments': {
      'total': acc.sumOfNominations(),
      'main': [acc.firsts, acc.seconds, acc.thirds],
      'small': [acc.smallFirsts, acc.smallSeconds, acc.smallThirds],
      'awards': {
        'mvp': acc.mvp,
        'sheriff': acc.bestSheriff,
        'don': acc.bestDon,
        'civilian': acc.bestCivilian,
        'mafia': acc.bestMafia,
      },
      'tournaments': [
        for (final t in TournamentType.values)
          if (acc.tournamentPodiums(t) > 0)
            {
              'type': t.name,
              'label': t.label,
              'podiums': acc.tournamentPodiums(t),
              'places': acc.tournamentPlaces[t] ?? const [0, 0, 0],
            }
      ],
    },
    'timeline': [
      for (final c in x.seasons)
        {
          'seasonId': c.id,
          'title': c.title,
          'games': perSeason[c.id] ?? 0,
          'league': (leagues[c.id] ?? SeasonLeague.none).name,
        }
    ],
    'roles': [
      for (final r in _profileRoleOrder)
        if ((roleGames[r] ?? 0) > 0)
          {
            'role': r.name,
            'label': roleLabel(r),
            'games': roleGames[r],
            'wins': roleWins[r] ?? 0,
            'share': roleGames[r]! / totalRoleGames,
            'top': top(percentiles[r]),
          }
    ],
    'firstKill': {
      'total': fk.total,
      'cityLost': fk.cityLost,
      'civSherGames': fk.civSherGames,
    },
    'bestMoves': {
      'firstKilled': bm.isFirstKilled,
      'zero': bm.zeroBlacks,
      'one': bm.oneBlack,
      'two': bm.twoBlacks,
      'three': bm.threeBlacks,
    },
  };
}
```

- [ ] **Step 4: Run — passes**

Run: `flutter test test/site_export/players_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/site_export/players_export.dart test/site_export/players_export_test.dart
git commit -m "feat(site): export the player directory and profiles"
```

---

### Task 7: Records export

**Files:**
- Create: `lib/site_export/records_export.dart`
- Test: `test/site_export/records_export_test.dart`

**Interfaces:**
- Consumes: `ExportContext`, `SiteTable`, formats; `services/stats/records.dart`, `records_providers.dart`.
- Produces: `Map<String, Object?> recordsJson(ExportContext x)` →
  `{categories: [{slug, label, filters: [..'role'|'scope'|'period']}], roles: [{key, label}], scopes: [{key, label}], periods: [{key, label}], defaults: {role: 'don', scope: 'season', period: 'modern'}, tables: {<key>: {scope, table}}}`.
  Table key = `slug` + (`/role` if the category filters by role) + (`/scope` if by scope) + (`/period` if by period), e.g. `roles/don/modern`, `hosts/alltime/li`, `games/season`, `pu`.

- [ ] **Step 1: Write the failing test**

`test/site_export/records_export_test.dart`:
```dart
import 'dart:convert';

import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/records_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

String keyFor(Map cat, Map<String, String> f) => [
      cat['slug'],
      for (final name in ['role', 'scope', 'period'])
        if ((cat['filters'] as List).contains(name)) f[name],
    ].join('/');

void main() {
  test('every category × filter combination has a table', () async {
    final x = ExportContext(await fixtureContainer());
    final json = jsonDecode(jsonEncode(recordsJson(x))) as Map;
    final tables = json['tables'] as Map;

    var expected = 0;
    for (final cat in (json['categories'] as List).cast<Map>()) {
      final filters = (cat['filters'] as List).cast<String>();
      final roles = filters.contains('role') ? (json['roles'] as List).map((r) => r['key'] as String) : [''];
      final scopes = filters.contains('scope') ? (json['scopes'] as List).map((r) => r['key'] as String) : [''];
      final periods = filters.contains('period') ? (json['periods'] as List).map((r) => r['key'] as String) : [''];
      for (final role in roles) {
        for (final scope in scopes) {
          for (final period in periods) {
            final key = keyFor(cat, {'role': role, 'scope': scope, 'period': period});
            expect(tables.containsKey(key), isTrue, reason: key);
            expected++;
          }
        }
      }
    }
    expect(tables.length, expected);
    expect(tables['penalties']['scope'], startsWith('Main league · Seasons '));
    expect(tables['streaks']['table']['rows'], isNotEmpty);
  });
}
```

- [ ] **Step 2: Run — fails**

Run: `flutter test test/site_export/records_export_test.dart`
Expected: FAIL, missing `records_export.dart`.

- [ ] **Step 3: Implement**

`lib/site_export/records_export.dart`:
```dart
import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

const _topN = 10;

SiteTable _table(List<SiteColumn> columns, List<List<SiteCell>> rows) =>
    SiteTable(
      showRank: true,
      collapsed: _topN,
      sortColumn: 1,
      empty: 'No records yet.',
      columns: columns,
      rows: rows,
    );

/// The Records tab: every category, role, scope and period, pre-ranked.
/// Columns, text and sort keys follow `records_screen.dart`.
Map<String, Object?> recordsJson(ExportContext x) {
  final input = x.read(recordsInputProvider);
  final tables = <String, Object?>{};
  void add(String key, String scope, SiteTable t) =>
      tables[key] = {'scope': scope, 'table': t.toJson()};

  for (final period in PointsPeriod.values) {
    add('mvp/${period.name}', 'Main league only', _table(const [
      SiteColumn('Player', numeric: false),
      SiteColumn('Pts/game'),
      SiteColumn('Max'),
      SiteColumn('Total'),
      SiteColumn('WR'),
      SiteColumn('Season'),
    ], [
      for (final r in mvpRecords(input, period))
        [
          x.name(r.player),
          SiteCell(f2(r.addPerGame), s: r.addPerGame),
          SiteCell(f2(r.maxSingleAdd), s: r.maxSingleAdd),
          SiteCell(r.totalAdd.toStringAsFixed(1), s: r.totalAdd),
          SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
          SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
        ]
    ]));

    for (final role in Role.values) {
      add('roles/${role.name}/${period.name}', 'Main league only', _table(const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Pts/game'),
        SiteColumn('WR'),
        SiteColumn('Games'),
        SiteColumn('Season'),
      ], [
        for (final r in roleRecords(input, role, period))
          [
            x.name(r.player),
            SiteCell(f2(r.pointsPerGame), s: r.pointsPerGame),
            SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
            SiteCell('${r.games}', s: r.games),
            SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
          ]
      ]));
    }

    for (final allTime in [false, true]) {
      add('hosts/${allTime ? 'alltime' : 'season'}/${period.name}', 'All hosts',
          _table(const [
        SiteColumn('Host', numeric: false),
        SiteColumn('Hosted'),
        SiteColumn('Avg +'),
        SiteColumn('Avg −'),
        SiteColumn('Season'),
      ], [
        for (final r in hostRecords(input, allTime: allTime, period: period))
          [
            x.name(r.host),
            SiteCell('${r.hosted}', s: r.hosted),
            r.periodGames >= kHostMinGamesForAverage
                ? SiteCell(f2(r.avgPlus), s: r.avgPlus)
                : const SiteCell('—', s: -99),
            r.periodGames >= kHostMinGamesForAverage
                ? SiteCell(f2(r.avgMinus), s: -r.avgMinus)
                : const SiteCell('—', s: -99),
            SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
          ]
      ]));
    }
  }

  for (final allTime in [false, true]) {
    add('games/${allTime ? 'alltime' : 'season'}',
        allTime ? 'All players' : 'Main league only', _table(const [
      SiteColumn('Player', numeric: false),
      SiteColumn('Games'),
      SiteColumn('WR'),
      SiteColumn('Season'),
    ], [
      for (final r in gamesRecords(input, allTime: allTime))
        [
          x.name(r.player),
          SiteCell('${r.games}', s: r.games),
          SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
          SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
        ]
    ]));
  }

  add('pu', 'Main league only', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('ПУ', tip: 'Killed on the first night'),
    SiteColumn('% of red'),
    SiteColumn('Red games'),
    SiteColumn('Season'),
  ], [
    for (final r in firstKillRecords(input))
      [
        x.name(r.player),
        SiteCell('${r.count}', s: r.count),
        SiteCell(pct0(r.pct), s: r.pct),
        SiteCell('${r.redGames}', s: r.redGames),
        SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
      ]
  ]));

  // Negated sort keys: "most minus" first when descending, as in the app.
  add('penalties', 'Main league · Seasons $kPenaltyColumnFirstSeason+', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('Minus/game'),
    SiteColumn('Max'),
    SiteColumn('Total'),
    SiteColumn('WR'),
    SiteColumn('Season'),
  ], [
    for (final r in penaltyRecords(input))
      [
        x.name(r.player),
        SiteCell(f2(r.minusPerGame), s: -r.minusPerGame),
        SiteCell(f2(r.maxSingleMinus), s: -r.maxSingleMinus),
        SiteCell(r.totalMinus.toStringAsFixed(1), s: -r.totalMinus),
        SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
        SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
      ]
  ]));

  add('streaks', 'All players', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('Wins in a row'),
    SiteColumn('Seasons', numeric: false),
  ], [
    for (final WinStreak r in x.read(winStreaksProvider))
      [
        x.name(r.player),
        SiteCell('${r.length}', s: r.length),
        SiteCell(r.seasonsLabel, s: r.fromSeason),
      ]
  ]));

  return {
    'categories': const [
      {'slug': 'mvp', 'label': 'MVP', 'filters': ['period']},
      {'slug': 'roles', 'label': 'Roles', 'filters': ['role', 'period']},
      {'slug': 'games', 'label': 'Games', 'filters': ['scope']},
      {'slug': 'hosts', 'label': 'Hosts', 'filters': ['scope', 'period']},
      {'slug': 'pu', 'label': 'ПУ', 'filters': <String>[]},
      {'slug': 'penalties', 'label': 'Penalties', 'filters': <String>[]},
      {'slug': 'streaks', 'label': 'Streaks', 'filters': <String>[]},
    ],
    'roles': [
      for (final r in Role.values) {'key': r.name, 'label': roleLabel(r)}
    ],
    'scopes': const [
      {'key': 'season', 'label': 'Per season'},
      {'key': 'alltime', 'label': 'All time'},
    ],
    'periods': [
      for (final p in PointsPeriod.values) {'key': p.name, 'label': p.label}
    ],
    'defaults': const {'role': 'don', 'scope': 'season', 'period': 'modern'},
    'tables': tables,
  };
}
```

- [ ] **Step 4: Run — passes**

Run: `flutter test test/site_export/records_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add lib/site_export/records_export.dart test/site_export/records_export_test.dart
git commit -m "feat(site): export every records table"
```

---

### Task 8: Write all files

**Files:**
- Create: `lib/site_export/site_exporter.dart`
- Modify: `tool/export_site_data_test.dart`
- Test: `test/site_export/site_exporter_test.dart`

**Interfaces:**
- Consumes: `seasonJson`, `overviewJson`, `playersJson`, `playerJson`, `recordsJson`, `ExportContext`.
- Produces: `Future<void> writeSiteData(ProviderContainer container, Directory out)` writing `index.json`, `season/<id>.json`, `players.json`, `player/<slug>.json`, `records.json`; deletes stale files first.

- [ ] **Step 1: Write the failing test**

`test/site_export/site_exporter_test.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/site_export/site_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('writes every file, one page per player, and clears stale ones', () async {
    final out = Directory.systemTemp.createTempSync('site_data');
    addTearDown(() => out.deleteSync(recursive: true));
    File('${out.path}/player/stale.json').createSync(recursive: true);

    await writeSiteData(await fixtureContainer(), out);

    for (final f in ['index.json', 'players.json', 'records.json', 'season/17.json', 'season/21.json']) {
      expect(File('${out.path}/$f').existsSync(), isTrue, reason: f);
    }
    expect(File('${out.path}/player/stale.json').existsSync(), isFalse);
    final players = (jsonDecode(File('${out.path}/players.json').readAsStringSync()) as Map)['players'] as List;
    for (final p in players) {
      expect(File('${out.path}/player/${p['slug']}.json').existsSync(), isTrue);
    }
  });
}
```

- [ ] **Step 2: Run — fails**

Run: `flutter test test/site_export/site_exporter_test.dart`
Expected: FAIL, missing `site_exporter.dart`.

- [ ] **Step 3: Implement the exporter**

`lib/site_export/site_exporter.dart`:
```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/overview_export.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:family_mafia_app/site_export/records_export.dart';
import 'package:family_mafia_app/site_export/season_export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Writes the site's JSON into [out], replacing whatever was there.
Future<void> writeSiteData(ProviderContainer container, Directory out) async {
  final x = ExportContext(container);
  if (out.existsSync()) out.deleteSync(recursive: true);

  void write(String path, Object? json) {
    File('${out.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  write('index.json', overviewJson(x));
  for (final season in x.seasons) {
    write('season/${season.id}.json', seasonJson(x, season));
  }
  write('players.json', playersJson(x));
  for (final p in x.players) {
    write('player/${x.slugs[p.id]}.json', playerJson(x, p));
  }
  write('records.json', recordsJson(x));
}
```

- [ ] **Step 4: Run — passes**

Run: `flutter test test/site_export/site_exporter_test.dart`
Expected: PASS.

- [ ] **Step 5: Turn the spike into the real entry point**

Replace `tool/export_site_data_test.dart` with:
```dart
// Run with: flutter test tool/export_site_data_test.dart
// Writes the site's JSON into site/data/ (override with SITE_DATA_DIR).
// Needs the assets/prefetched/ snapshot for remote seasons — see CLAUDE.md.
import 'dart:io';

import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/site_export/load_container.dart';
import 'package:family_mafia_app/site_export/site_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export site data', () async {
    final container = await loadSiteContainer();
    addTearDown(container.dispose);
    final out = Directory(Platform.environment['SITE_DATA_DIR'] ?? 'site/data');

    await writeSiteData(container, out);

    final configs = container.read(loadedSeasonConfigsProvider);
    for (final c in configs) {
      expect(File('${out.path}/season/${c.id}.json').existsSync(), isTrue);
    }
    // ignore: avoid_print
    print('Wrote ${configs.length} seasons to ${out.absolute.path}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
```

- [ ] **Step 6: Run the real export**

Run: `flutter test tool/export_site_data_test.dart && ls site/data site/data/season | head && du -sh site/data`
Expected: PASS, `Wrote 31 seasons…` (or however many are configured), a few hundred KB to a few MB.

- [ ] **Step 7: Run the whole suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`, all tests pass.

- [ ] **Step 8: Commit**
```bash
git add lib/site_export/site_exporter.dart tool/export_site_data_test.dart test/site_export/site_exporter_test.dart
git commit -m "feat(site): write every site JSON file from the loaded app data"
```

---

### Task 9: Astro scaffold, theme, layout, libs and dist checks

**Files:**
- Create: `site/package.json`, `site/astro.config.mjs`, `site/tsconfig.json`, `site/src/env.d.ts`
- Create: `site/src/lib/types.ts`, `site/src/lib/data.ts`, `site/src/lib/url.ts`, `site/src/lib/format.ts`, `site/src/lib/sort.ts`
- Create: `site/src/lib/format.test.ts`, `site/src/lib/sort.test.ts`
- Create: `site/src/styles/global.css`, `site/src/layouts/Base.astro`, `site/src/components/Panel.astro`, `site/src/components/Kpi.astro`
- Create: `site/src/pages/index.astro`, `site/src/pages/404.astro`
- Create: `site/scripts/check-dist.mjs`, `site/public/favicon.svg`

**Interfaces:**
- Consumes: the JSON from Task 8 in `site/data/` (or `SITE_DATA_DIR`).
- Produces (used by every later site task):
  - `types.ts`: `SiteColumn`, `SiteCell`, `SiteTable`, `IndexData`, `SeasonData`, `LeagueData`, `StatItem`, `Award`, `PlayersData`, `PlayerSummary`, `PlayerData`, `RecordsData`, `RecordCategory`.
  - `data.ts`: `loadIndex(): IndexData`, `loadSeason(id: number): SeasonData`, `loadPlayers(): PlayersData`, `loadPlayer(slug: string): PlayerData`, `loadRecords(): RecordsData`.
  - `url.ts`: `href(path: string): string`, `playerHref(slug: string): string`, `seasonHref(id: number, small?: boolean): string`, `absolute(path: string): string`.
  - `format.ts`: `pct(v: number, digits?: number): string`, `wrTone(v: number | undefined): 'good' | 'mid' | 'low' | undefined`.
  - `sort.ts`: `type Dir = 'asc' | 'desc'`, `compareCells(a, b): number`, `sortedIndices(rows: SiteCell[][], col: number, dir: Dir): number[]`.
  - `Base.astro` props: `{ title: string; description?: string; active?: 'season' | 'players' | 'overview' | 'records' }`.
  - `Panel.astro` props: `{ title?: string; note?: string; class?: string }` with a default slot and optional `actions` slot.
  - `Kpi.astro` props: `{ label: string; value: string; tone?: 'city' | 'mafia' }`.

- [ ] **Step 1: Create the project files**

`site/package.json`:
```json
{
  "name": "family-mafia-site",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "astro dev",
    "build": "astro build && node scripts/check-dist.mjs",
    "preview": "astro preview",
    "check": "astro check",
    "test": "vitest run"
  }
}
```
Then install pinned dependencies:
```bash
cd site && npm install astro@7.3.5 && npm install -D @astrojs/check@0.9.10 typescript@~5.9 vitest@5.0.3 @resvg/resvg-js && cd ..
```
(TypeScript 5.9, not 7: `@astrojs/check` needs the JS compiler API.)

`site/astro.config.mjs`:
```js
import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://seezov.github.io',
  base: '/FamilyMafiaApp',
  trailingSlash: 'always',
  build: { format: 'directory' },
});
```

`site/tsconfig.json`:
```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "src/**/*", "scripts/**/*"],
  "exclude": ["dist"]
}
```

`site/src/env.d.ts`:
```ts
/// <reference types="astro/client" />
```

- [ ] **Step 2: Write failing lib tests**

`site/src/lib/sort.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { sortedIndices } from './sort';
import type { SiteCell } from './types';

const rows: SiteCell[][] = [
  [{ t: 'Olya' }, { t: '50%', s: 0.5 }],
  [{ t: 'Sasha' }, { t: '–' }],
  [{ t: 'Ivan' }, { t: '61%', s: 0.61 }],
  [{ t: 'Anna' }, { t: '50%', s: 0.5 }],
];

describe('sortedIndices', () => {
  it('sorts numerically descending, ties keep the given order', () => {
    expect(sortedIndices(rows, 1, 'desc')).toEqual([2, 0, 3, 1]);
  });
  it('puts cells without a sort key last in both directions', () => {
    expect(sortedIndices(rows, 1, 'asc')).toEqual([0, 3, 2, 1]);
  });
  it('falls back to Ukrainian-aware text order', () => {
    const names: SiteCell[][] = [[{ t: 'Яна' }], [{ t: 'Іра' }], [{ t: 'Аня' }]];
    expect(sortedIndices(names, 0, 'asc')).toEqual([2, 1, 0]);
  });
});
```

`site/src/lib/format.test.ts`:
```ts
import { describe, expect, it } from 'vitest';
import { pct, wrTone } from './format';

describe('format', () => {
  it('formats percentages', () => {
    expect(pct(0.546)).toBe('55%');
    expect(pct(0.6123, 1)).toBe('61.2%');
  });
  it('rounds to one decimal before applying the 50 / 35 thresholds, like the app', () => {
    expect(wrTone(0.5)).toBe('good');
    expect(wrTone(0.4996)).toBe('good');
    expect(wrTone(0.3496)).toBe('mid');
    expect(wrTone(0.349)).toBe('low');
    expect(wrTone(undefined)).toBeUndefined();
  });
});
```

- [ ] **Step 3: Run — fails**

Run: `cd site && npx vitest run; cd ..`
Expected: FAIL, cannot resolve `./sort` / `./format`.

- [ ] **Step 4: Implement the libs**

`site/src/lib/types.ts`:
```ts
export interface SiteColumn { label: string; numeric: boolean; tip?: string; group?: string; phone?: boolean }
export interface SiteCell { t: string; s?: number; link?: string; tone?: 'wr' | 'pos' | 'neg' }
export interface SiteTable {
  title?: string; empty?: string; columns: SiteColumn[]; rows: SiteCell[][];
  sortColumn?: number; desc: boolean; showRank: boolean; collapsed?: number;
}

export type RoleKey = 'civilian' | 'sheriff' | 'mafia' | 'don';

export interface IndexData {
  seasons: { id: number; title: string }[];
  latestSeasonId: number;
  club: { seasons: number; games: number; players: number; cityWR: number };
  roleWR: Record<RoleKey, number>;
  leaderboardNote: string;
  leaderboards: { role: RoleKey; label: string; table: SiteTable }[];
  protocol: SiteTable;
  seasonsTable: SiteTable;
}

export interface StatItem { label: string; winner: string; table?: SiteTable }
export interface Award { key: string; label: string; winner: string; winnerLink?: string; table: SiteTable }
export interface LeagueData { ratings: SiteTable; stats: StatItem[]; awards?: Award[] }
export interface SeasonData {
  id: number; title: string; gameLimit: number; smallLeagueMinGames: number;
  summary: { games: number; players: number; cityWR: number; mafiaWR: number } | null;
  leagueCounts: { main: number; small: number } | null;
  tournaments: { type: string; label: string; name: string; games: number; date: string | null; podium: string[] }[];
  tournamentCounts: { type: string; label: string; count: number }[];
  leagues: { main: LeagueData; small: LeagueData };
}

export interface PlayerSummary {
  id: number; slug: string; name: string; initials: string;
  games: number; winRate: number; seasons: number; latestRating: number | null;
}
export interface PlayersData { players: PlayerSummary[]; table: SiteTable }
export interface PlayerData extends PlayerSummary {
  accomplishments: {
    total: number; main: number[]; small: number[];
    awards: Record<'mvp' | 'sheriff' | 'don' | 'civilian' | 'mafia', number>;
    tournaments: { type: string; label: string; podiums: number; places: number[] }[];
  };
  timeline: { seasonId: number; title: string; games: number; league: 'main' | 'small' | 'below' | 'none' }[];
  roles: { role: RoleKey; label: string; games: number; wins: number; share: number; top: string | null }[];
  firstKill: { total: number; cityLost: number; civSherGames: number };
  bestMoves: { firstKilled: number; zero: number; one: number; two: number; three: number };
}

export type FilterName = 'role' | 'scope' | 'period';
export interface RecordCategory { slug: string; label: string; filters: FilterName[] }
export interface RecordsData {
  categories: RecordCategory[];
  roles: { key: string; label: string }[];
  scopes: { key: string; label: string }[];
  periods: { key: string; label: string }[];
  defaults: Record<FilterName, string>;
  tables: Record<string, { scope: string; table: SiteTable }>;
}
```

`site/src/lib/data.ts`:
```ts
import fs from 'node:fs';
import path from 'node:path';
import type { IndexData, PlayerData, PlayersData, RecordsData, SeasonData } from './types';

// Written by `flutter test tool/export_site_data_test.dart` (repo root).
const dir = process.env.SITE_DATA_DIR ?? path.resolve(process.cwd(), 'data');

function read<T>(rel: string): T {
  const file = path.join(dir, rel);
  if (!fs.existsSync(file)) {
    throw new Error(`Missing ${file}. Run the export first: flutter test tool/export_site_data_test.dart`);
  }
  return JSON.parse(fs.readFileSync(file, 'utf8')) as T;
}

export const loadIndex = () => read<IndexData>('index.json');
export const loadSeason = (id: number) => read<SeasonData>(`season/${id}.json`);
export const loadPlayers = () => read<PlayersData>('players.json');
export const loadPlayer = (slug: string) => read<PlayerData>(`player/${slug}.json`);
export const loadRecords = () => read<RecordsData>('records.json');
```

`site/src/lib/url.ts`:
```ts
const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** Site-internal URL under the base path; `href('players/')` → `/FamilyMafiaApp/players/`. */
export const href = (p: string) => `${base}/${p.replace(/^\//, '')}`;
export const playerHref = (slug: string) => href(`players/${slug}/`);
export const seasonHref = (id: number, small = false) => href(`season/${id}/${small ? 'small/' : ''}`);
export const absolute = (p: string) => new URL(href(p), 'https://seezov.github.io').toString();
```

`site/src/lib/format.ts`:
```ts
export const pct = (v: number, digits = 0) => `${(v * 100).toFixed(digits)}%`;

/** WR colour band; the percentage is rounded to one decimal first, as the app does. */
export function wrTone(v: number | undefined): 'good' | 'mid' | 'low' | undefined {
  if (v === undefined) return undefined;
  const p = Math.round(v * 1000) / 10;
  return p >= 50 ? 'good' : p >= 35 ? 'mid' : 'low';
}
```

`site/src/lib/sort.ts`:
```ts
import type { SiteCell } from './types';

export type Dir = 'asc' | 'desc';

const collator = new Intl.Collator('uk');

export function compareCells(a: SiteCell, b: SiteCell): number {
  if (a.s !== undefined && b.s !== undefined) return a.s - b.s;
  return collator.compare(a.t, b.t);
}

/** Row order for sorting by [col]; rows without a sort key always go last; stable. */
export function sortedIndices(rows: SiteCell[][], col: number, dir: Dir): number[] {
  return rows
    .map((_, i) => i)
    .sort((i, j) => {
      const a = rows[i][col], b = rows[j][col];
      const am = a.s === undefined, bm = b.s === undefined;
      const anyKeyed = rows.some((r) => r[col].s !== undefined);
      if (anyKeyed && am !== bm) return am ? 1 : -1;
      const c = compareCells(a, b);
      return (dir === 'desc' ? -c : c) || i - j;
    });
}
```

- [ ] **Step 5: Run lib tests — pass**

Run: `cd site && npx vitest run; cd ..`
Expected: PASS (5 tests).

- [ ] **Step 6: Theme and layout**

`site/src/styles/global.css`:
```css
:root {
  color-scheme: dark;
  --bg: #0B0D10; --panel: #12161B; --panel-2: #171C22; --border: #1F252D;
  --text: #E6E8EB; --muted: #8B95A1;
  --city: #E5484D; --mafia: #A3ADBA; --accent: #E5484D;
  --civilian: #E5484D; --sheriff: #22C3DC; --don: #A78BFA;
  --good: #3FB950; --mid: #D29922; --low: var(--muted);
  --gold: #E3B341; --silver: #B4BCC8; --bronze: #C2410C;
  --radius: 8px; --gutter: 24px; --max: 1280px;
  --font-display: 'Unbounded', system-ui, sans-serif;
  --font-body: 'Inter', system-ui, sans-serif;
}
@media (max-width: 899px) { :root { --gutter: 16px; } }

* { box-sizing: border-box; }
html, body { margin: 0; }
body {
  background: var(--bg); color: var(--text);
  font: 14px/1.5 var(--font-body); font-feature-settings: 'tnum' 1;
  overflow-x: hidden;
}
a { color: inherit; text-decoration: none; }
a:hover { color: var(--accent); }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

.wrap { max-width: var(--max); margin: 0 auto; padding: 0 var(--gutter); }
main.wrap { padding-top: 24px; padding-bottom: 64px; }
.grid { display: grid; gap: 16px; grid-template-columns: repeat(12, minmax(0, 1fr)); }
.span-12 { grid-column: span 12; } .span-8 { grid-column: span 8; }
.span-6 { grid-column: span 6; } .span-4 { grid-column: span 4; } .span-3 { grid-column: span 3; }
@media (max-width: 899px) { .grid > * { grid-column: span 12; } }

.label { font-size: 11px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); }
.display { font-family: var(--font-display); font-weight: 700; letter-spacing: -.01em; }
h1.display { font-size: clamp(22px, 3vw, 32px); margin: 0; }
.num { font-variant-numeric: tabular-nums; }

.tone-good { color: var(--good); } .tone-mid { color: var(--mid); } .tone-low { color: var(--low); }
.tone-pos { color: var(--good); } .tone-neg { color: var(--city); }
.role-civilian { color: var(--civilian); } .role-sheriff { color: var(--sheriff); }
.role-mafia { color: var(--mafia); } .role-don { color: var(--don); }

.pills { display: flex; gap: 6px; overflow-x: auto; scrollbar-width: none; padding-bottom: 2px; }
.pill {
  white-space: nowrap; padding: 5px 12px; border: 1px solid var(--border);
  border-radius: 999px; color: var(--muted); font-size: 13px;
}
.pill[aria-current='true'] { color: var(--text); border-color: var(--accent); background: rgba(229, 72, 77, .12); }
.pagehead { display: flex; flex-wrap: wrap; align-items: center; gap: 12px 20px; margin-bottom: 20px; }
```

`site/src/layouts/Base.astro`:
```astro
---
import '../styles/global.css';
import { absolute, href } from '../lib/url';
import { loadIndex } from '../lib/data';

interface Props {
  title: string;
  description?: string;
  active?: 'season' | 'players' | 'overview' | 'records';
}
const { title, description = 'Family Mafia club statistics: seasons, players, records.', active } = Astro.props;
const { latestSeasonId } = loadIndex();
const nav = [
  { key: 'season', label: 'Season', url: href(`season/${latestSeasonId}/`) },
  { key: 'players', label: 'Players', url: href('players/') },
  { key: 'overview', label: 'Overview', url: href('overview/') },
  { key: 'records', label: 'Records', url: href('records/mvp/') },
];
const fullTitle = title === 'Family Mafia' ? title : `${title} · Family Mafia`;
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{fullTitle}</title>
    <meta name="description" content={description} />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="Family Mafia" />
    <meta property="og:title" content={fullTitle} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={absolute('og.png')} />
    <meta property="og:url" content={new URL(Astro.url.pathname, 'https://seezov.github.io').toString()} />
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="theme-color" content="#0B0D10" />
    <link rel="icon" href={href('favicon.svg')} type="image/svg+xml" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      rel="stylesheet"
      href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Unbounded:wght@600;700&display=swap&subset=cyrillic"
    />
  </head>
  <body>
    <header class="top">
      <div class="wrap bar">
        <a class="logo display" href={href(`season/${latestSeasonId}/`)}>FAMILY<span>MAFIA</span></a>
        <nav class="tabs" aria-label="Sections">
          {nav.map((n) => (
            <a href={n.url} aria-current={n.key === active ? 'page' : undefined}>{n.label}</a>
          ))}
        </nav>
        <form class="search" action={href('players/')} method="get" role="search">
          <input name="q" type="search" placeholder="Find a player…" aria-label="Find a player" />
        </form>
      </div>
    </header>
    <main class="wrap"><slot /></main>
    <footer class="wrap foot label">Family Mafia · club statistics · updated nightly</footer>
  </body>
</html>

<style>
  .top { position: sticky; top: 0; z-index: 10; background: rgba(11, 13, 16, .92);
    backdrop-filter: blur(8px); border-bottom: 1px solid var(--border); }
  .bar { display: flex; align-items: center; gap: 28px; height: 56px; }
  .logo { font-size: 15px; letter-spacing: .04em; white-space: nowrap; }
  .logo span { color: var(--accent); margin-left: 4px; }
  .tabs { display: flex; gap: 4px; height: 100%; }
  .tabs a { display: flex; align-items: center; padding: 0 12px; color: var(--muted);
    border-bottom: 2px solid transparent; font-weight: 500; white-space: nowrap; }
  .tabs a[aria-current='page'] { color: var(--text); border-bottom-color: var(--accent); }
  .search { margin-left: auto; }
  .search input { width: 220px; background: var(--panel); border: 1px solid var(--border);
    border-radius: var(--radius); color: var(--text); padding: 7px 10px; font: inherit; }
  .foot { padding-top: 24px; padding-bottom: 32px; border-top: 1px solid var(--border); }
  @media (max-width: 899px) {
    .bar { flex-wrap: wrap; height: auto; gap: 0 12px; padding-top: 10px; }
    .search { margin-left: auto; }
    .search input { width: 140px; }
    .tabs { order: 3; width: 100%; overflow-x: auto; scrollbar-width: none; height: 44px; }
  }
</style>
```

`site/src/components/Panel.astro`:
```astro
---
interface Props { title?: string; note?: string; class?: string }
const { title, note, class: cls } = Astro.props;
---
<section class:list={['panel', cls]}>
  {(title || Astro.slots.has('actions')) && (
    <header>
      {title && <h2 class="label">{title}</h2>}
      {note && <span class="note">{note}</span>}
      <div class="actions"><slot name="actions" /></div>
    </header>
  )}
  <slot />
</section>

<style>
  .panel { background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius);
    padding: 16px; min-width: 0; }
  header { display: flex; align-items: baseline; gap: 10px; margin-bottom: 12px; flex-wrap: wrap; }
  h2 { margin: 0; font-weight: 600; color: var(--text); }
  .note { color: var(--muted); font-size: 12px; }
  .actions { margin-left: auto; }
</style>
```

`site/src/components/Kpi.astro`:
```astro
---
interface Props { label: string; value: string; tone?: 'city' | 'mafia' }
const { label, value, tone } = Astro.props;
---
<div class="kpi">
  <div class="label">{label}</div>
  <div class:list={['display', 'value', tone && `t-${tone}`]}>{value}</div>
</div>

<style>
  .kpi { background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius);
    padding: 14px 16px; min-width: 0; }
  .value { font-size: 28px; line-height: 1.15; margin-top: 4px; font-variant-numeric: tabular-nums; }
  .t-city { color: var(--city); } .t-mafia { color: var(--mafia); }
</style>
```

`site/src/pages/index.astro`:
```astro
---
import { loadIndex } from '../lib/data';
import { seasonHref } from '../lib/url';
const target = seasonHref(loadIndex().latestSeasonId);
---
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="refresh" content={`0; url=${target}`} />
    <link rel="canonical" href={target} />
    <title>Family Mafia</title>
    <meta property="og:title" content="Family Mafia" />
    <meta property="og:description" content="Family Mafia club statistics: seasons, players, records." />
    <meta property="og:image" content="https://seezov.github.io/FamilyMafiaApp/og.png" />
  </head>
  <body style="background:#0B0D10;color:#E6E8EB;font-family:system-ui">
    <a href={target} style="color:#E5484D">Go to the latest season</a>
  </body>
</html>
```

`site/src/pages/404.astro`:
```astro
---
import Base from '../layouts/Base.astro';
import { href } from '../lib/url';
---
<Base title="Not found">
  <h1 class="display">Not found</h1>
  <p>This page doesn't exist — maybe the player was renamed. <a href={href('players/')} style="color:var(--accent)">All players</a></p>
</Base>
```

`site/public/favicon.svg`:
```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect width="32" height="32" rx="7" fill="#0B0D10"/><path d="M8 23V9h3.2l4.8 7 4.8-7H24v14h-3.2v-8.6L16 21.2l-4.8-6.8V23z" fill="#E5484D"/></svg>
```

- [ ] **Step 7: The dist check script**

`site/scripts/check-dist.mjs`:
```js
// Post-build guards: no API keys, every internal link resolves, every player has a page.
import fs from 'node:fs';
import path from 'node:path';

const dist = path.resolve('dist');
const dataDir = process.env.SITE_DATA_DIR ?? path.resolve('data');
const base = '/FamilyMafiaApp/';
const errors = [];

const walk = (dir) =>
  fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(dir, e.name)) : [path.join(dir, e.name)]);
const files = walk(dist);

for (const file of files) {
  const text = fs.readFileSync(file, 'latin1');
  if (text.includes('AIza')) errors.push(`API key pattern in ${path.relative(dist, file)}`);
  if (!file.endsWith('.html')) continue;
  for (const [, url] of text.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (!url.startsWith(base)) continue;
    const rel = decodeURI(url.slice(base.length).split(/[?#]/)[0]);
    let target = path.join(dist, rel);
    if (rel === '' || rel.endsWith('/')) target = path.join(target, 'index.html');
    if (!fs.existsSync(target)) errors.push(`${path.relative(dist, file)} → ${url}`);
  }
}

if (!fs.existsSync(path.join(dist, 'index.html'))) errors.push('dist/index.html is missing');

const { players } = JSON.parse(fs.readFileSync(path.join(dataDir, 'players.json'), 'utf8'));
for (const p of players) {
  if (!fs.existsSync(path.join(dist, 'players', p.slug, 'index.html'))) errors.push(`No page for player ${p.slug}`);
}

if (errors.length) {
  console.error(`check-dist: ${errors.length} problem(s)\n` + errors.slice(0, 50).join('\n'));
  process.exit(1);
}
console.log(`check-dist: ${files.length} files, ${players.length} players, all links resolve`);
```

- [ ] **Step 8: Build — it fails only on missing player pages**

Run: `cd site && npm run check && npm run build; cd ..`
Expected: `astro check` passes; `astro build` succeeds; `check-dist` FAILS with `No page for player …` (and links to `players/`, `overview/`, `records/mvp/`, `season/N/` missing) — those pages come in later tasks. This confirms the guard works.

- [ ] **Step 9: Commit**
```bash
git add site/package.json site/package-lock.json site/astro.config.mjs site/tsconfig.json site/src site/scripts site/public
git commit -m "feat(site): Astro scaffold, dark theme, layout, data libs and dist guards"
```

---

### Task 10: DataTable component and its island

**Files:**
- Create: `site/src/components/DataTable.astro`, `site/src/components/table.ts`

**Interfaces:**
- Consumes: `SiteTable`, `sortedIndices`, `wrTone`, `playerHref`.
- Produces: `<DataTable table={SiteTable} compact?={boolean} />`. Behaviour: sortable headers (click toggles; first click on a numeric column sorts descending), rank column renumbers after sorting with gold/silver/bronze for 1–3, rows beyond `collapsed` hidden behind "Show all N", columns with `phone: false` hidden below 900 px and shown as a details list when the row is tapped, `empty` text when there are no rows.

- [ ] **Step 1: Write the component**

`site/src/components/DataTable.astro`:
```astro
---
import type { SiteCell, SiteTable } from '../lib/types';
import { sortedIndices } from '../lib/sort';
import { wrTone } from '../lib/format';
import { playerHref } from '../lib/url';

interface Props { table: SiteTable; compact?: boolean }
const { table, compact = false } = Astro.props;
const { columns, showRank } = table;
const order = table.sortColumn === undefined
  ? table.rows.map((_, i) => i)
  : sortedIndices(table.rows, table.sortColumn, table.desc ? 'desc' : 'asc');
const hasHidden = columns.some((c) => c.phone === false);
const hasGroups = columns.some((c) => c.group);
const groups: { label: string; span: number }[] = [];
for (const c of columns) {
  const last = groups.at(-1);
  if (last && last.label === (c.group ?? '') && c.group) last.span++;
  else groups.push({ label: c.group ?? '', span: 1 });
}
const toneClass = (c: SiteCell) =>
  c.tone === 'wr' ? `tone-${wrTone(c.s) ?? 'low'}` : c.tone ? `tone-${c.tone}` : undefined;
const collapsed = table.collapsed && table.rows.length > table.collapsed ? table.collapsed : undefined;
const colCount = columns.length + (showRank ? 1 : 0);
---
{table.rows.length === 0 ? (
  <p class="empty">{table.empty ?? 'No data.'}</p>
) : (
  <div class:list={['dt', { compact }]} data-table data-collapsed={collapsed}>
    <div class="scroll">
      <table>
        <thead>
          {hasGroups && (
            <tr class="groups">
              {showRank && <th />}
              {groups.map((g) => (
                <th colspan={g.span} class:list={[{ grp: g.label }, `role-${g.label.toLowerCase()}`]}>{g.label}</th>
              ))}
            </tr>
          )}
          <tr>
            {showRank && <th class="rank num">#</th>}
            {columns.map((c, i) => (
              <th
                class:list={[{ num: c.numeric, ph: c.phone === false, sorted: i === table.sortColumn }]}
                title={c.tip}
                data-col={i}
                data-numeric={c.numeric ? '1' : undefined}
                aria-sort={i === table.sortColumn ? (table.desc ? 'descending' : 'ascending') : undefined}
              ><button type="button">{c.label}</button></th>
            ))}
          </tr>
        </thead>
        {order.map((r, pos) => (
          <tbody class:list={{ extra: collapsed !== undefined && pos >= collapsed }}>
            <tr class:list={['row', { tappable: hasHidden }]}>
              {showRank && <td class="rank num" data-rank>{pos + 1}</td>}
              {table.rows[r].map((cell, i) => (
                <td
                  class:list={[toneClass(cell), { num: columns[i].numeric, ph: columns[i].phone === false, sorted: i === table.sortColumn }]}
                  data-s={cell.s}
                >
                  {cell.tone === 'wr' && cell.s !== undefined && <span class="bar" style={`--w:${Math.round(cell.s * 100)}%`} />}
                  {cell.link ? <a href={playerHref(cell.link)}>{cell.t}</a> : cell.t}
                </td>
              ))}
            </tr>
            {hasHidden && (
              <tr class="detail"><td colspan={colCount}>
                <dl>
                  {columns.map((c, i) => c.phone === false && (
                    <div><dt>{c.group ? `${c.group} ${c.label}` : c.label}</dt><dd class={toneClass(table.rows[r][i])}>{table.rows[r][i].t}</dd></div>
                  ))}
                </dl>
              </td></tr>
            )}
          </tbody>
        ))}
      </table>
    </div>
    {collapsed !== undefined && <button type="button" class="more" data-more>Show all {table.rows.length}</button>}
  </div>
)}

<script>
  import { enhanceTables } from './table';
  enhanceTables();
</script>

<style>
  .empty { color: var(--muted); margin: 8px 0; }
  .scroll { overflow-x: auto; }
  table { width: 100%; border-collapse: collapse; font-variant-numeric: tabular-nums; }
  th, td { padding: 0 10px; height: 32px; white-space: nowrap; text-align: left; border-bottom: 1px solid var(--border); }
  .compact th, .compact td { height: 28px; padding: 0 8px; }
  th { position: sticky; top: 0; background: var(--panel); font-weight: 500; color: var(--muted); font-size: 12px; }
  th button { all: unset; cursor: pointer; }
  th.sorted { color: var(--text); }
  th[aria-sort='descending'] button::after { content: ' ↓'; }
  th[aria-sort='ascending'] button::after { content: ' ↑'; }
  tr.groups th { height: 22px; border-bottom: 0; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; }
  tr.groups th.grp { border-bottom: 1px solid currentColor; text-align: center; }
  .num { text-align: right; }
  td.sorted { background: rgba(255, 255, 255, .025); }
  tbody:hover td { background: var(--panel-2); }
  td:first-child, th:first-child { position: sticky; left: 0; background: var(--panel); z-index: 1; }
  .rank + td { position: sticky; left: 36px; background: var(--panel); z-index: 1; }
  .rank { width: 36px; color: var(--muted); }
  .rank.r1 { color: var(--gold); } .rank.r2 { color: var(--silver); } .rank.r3 { color: var(--bronze); }
  td a { font-weight: 500; }
  td { position: relative; }
  .bar { position: absolute; left: 10px; right: 10px; bottom: 4px; height: 2px; background: var(--border); }
  .bar::after { content: ''; position: absolute; inset: 0 auto 0 0; width: var(--w); background: currentColor; opacity: .6; }
  tbody.extra { display: none; }
  .dt.open tbody.extra { display: table-row-group; }
  .more { margin-top: 8px; background: none; border: 1px solid var(--border); border-radius: var(--radius);
    color: var(--muted); padding: 6px 12px; font: inherit; cursor: pointer; }
  .dt.open .more { display: none; }
  tr.detail { display: none; }
  dl { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 6px 16px; margin: 8px 0; }
  dl div { display: flex; justify-content: space-between; gap: 8px; }
  dt { color: var(--muted); } dd { margin: 0; }
  @media (max-width: 899px) {
    th, td { height: 40px; }
    .ph { display: none; }
    tr.tappable { cursor: pointer; }
    tbody.expanded tr.detail { display: table-row; }
    tr.detail td { white-space: normal; height: auto; }
  }
</style>
```

- [ ] **Step 2: Write the island**

`site/src/components/table.ts`:
```ts
import { sortedIndices, type Dir } from '../lib/sort';
import type { SiteCell } from '../lib/types';

function cellOf(td: HTMLTableCellElement): SiteCell {
  const s = td.dataset.s;
  return { t: td.textContent?.trim() ?? '', s: s === undefined || s === '' ? undefined : Number(s) };
}

function renumber(root: HTMLElement) {
  root.querySelectorAll<HTMLTableSectionElement>('tbody').forEach((tb, i) => {
    const rank = tb.querySelector<HTMLElement>('[data-rank]');
    if (!rank) return;
    rank.textContent = String(i + 1);
    rank.classList.remove('r1', 'r2', 'r3');
    if (i < 3) rank.classList.add(`r${i + 1}`);
  });
}

function sortBy(root: HTMLElement, th: HTMLTableCellElement) {
  const table = root.querySelector('table')!;
  const col = Number(th.dataset.col);
  const current = th.getAttribute('aria-sort');
  const dir: Dir = current === 'descending' ? 'asc' : current === 'ascending' ? 'desc' : th.dataset.numeric ? 'desc' : 'asc';
  const bodies = [...table.tBodies];
  const rows = bodies.map((tb) => [...tb.rows[0].cells].filter((c) => !c.hasAttribute('data-rank')).map(cellOf));
  const order = sortedIndices(rows, col, dir);
  const collapsed = Number(root.dataset.collapsed) || undefined;
  order.forEach((i, pos) => {
    const tb = bodies[i];
    tb.classList.toggle('extra', collapsed !== undefined && pos >= collapsed);
    table.appendChild(tb);
  });
  root.querySelectorAll('th[data-col]').forEach((h) => h.removeAttribute('aria-sort'));
  root.querySelectorAll('.sorted').forEach((el) => el.classList.remove('sorted'));
  th.setAttribute('aria-sort', dir === 'desc' ? 'descending' : 'ascending');
  th.classList.add('sorted');
  table.querySelectorAll('tbody tr.row').forEach((tr) => {
    const cells = [...(tr as HTMLTableRowElement).cells].filter((c) => !c.hasAttribute('data-rank'));
    cells[col]?.classList.add('sorted');
  });
  renumber(root);
}

export function enhanceTables() {
  document.querySelectorAll<HTMLElement>('[data-table]').forEach((root) => {
    if (root.dataset.ready) return;
    root.dataset.ready = '1';
    renumber(root);
    root.querySelectorAll<HTMLTableCellElement>('th[data-col]').forEach((th) =>
      th.querySelector('button')?.addEventListener('click', () => sortBy(root, th)));
    root.querySelector('[data-more]')?.addEventListener('click', () => root.classList.add('open'));
    root.querySelectorAll<HTMLTableRowElement>('tr.tappable').forEach((tr) =>
      tr.addEventListener('click', (e) => {
        if ((e.target as HTMLElement).closest('a')) return;
        tr.parentElement?.classList.toggle('expanded');
      }));
  });
}
```

- [ ] **Step 3: Type-check and unit tests**

Run: `cd site && npm run check && npm test; cd ..`
Expected: `0 errors`, tests pass.

- [ ] **Step 4: Commit**
```bash
git add site/src/components/DataTable.astro site/src/components/table.ts
git commit -m "feat(site): sortable, collapsible, phone-friendly data table"
```

---

### Task 11: Season pages

**Files:**
- Create: `site/src/components/SeasonPage.astro`, `site/src/components/RankedList.astro`
- Create: `site/src/pages/season/[id]/index.astro`, `site/src/pages/season/[id]/small/index.astro`

**Interfaces:**
- Consumes: `loadIndex`, `loadSeason`, `DataTable`, `Panel`, `Kpi`, `Base`, `pct`, `seasonHref`, `playerHref`.
- Produces: `<SeasonPage id={number} small={boolean} />`; `<RankedList title={string} winner={string} winnerLink?={string} table?={SiteTable} />` (a winner line plus a compact top-5 table, "Show all" for the rest).

- [ ] **Step 1: RankedList**

`site/src/components/RankedList.astro`:
```astro
---
import DataTable from './DataTable.astro';
import type { SiteTable } from '../lib/types';
import { playerHref } from '../lib/url';

interface Props { title: string; winner: string; winnerLink?: string; table?: SiteTable }
const { title, winner, winnerLink, table } = Astro.props;
---
<div class="rl">
  <div class="head">
    <span class="label">{title}</span>
    <span class="winner">{winnerLink ? <a href={playerHref(winnerLink)}>{winner}</a> : winner}</span>
  </div>
  {table && <DataTable table={{ ...table, collapsed: table.collapsed ?? 5 }} compact />}
</div>

<style>
  .rl + .rl { margin-top: 18px; padding-top: 14px; border-top: 1px solid var(--border); }
  .head { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; margin-bottom: 6px; }
  .winner { font-weight: 600; text-align: right; }
</style>
```

- [ ] **Step 2: SeasonPage**

`site/src/components/SeasonPage.astro`:
```astro
---
import Base from '../layouts/Base.astro';
import DataTable from './DataTable.astro';
import Kpi from './Kpi.astro';
import Panel from './Panel.astro';
import RankedList from './RankedList.astro';
import { loadIndex, loadSeason } from '../lib/data';
import { pct } from '../lib/format';
import { seasonHref } from '../lib/url';

interface Props { id: number; small: boolean }
const { id, small } = Astro.props;
const index = loadIndex();
const season = loadSeason(id);
const league = small ? season.leagues.small : season.leagues.main;
const s = season.summary;
const dash = '—';
const description = s
  ? `${season.title}: ${s.games} games, ${s.players} players, city won ${pct(s.cityWR)}.`
  : season.title;
const seasons = [...index.seasons].reverse();
---
<Base title={`${season.title}${small ? ' · Small league' : ''}`} description={description} active="season">
  <div class="pagehead">
    <details class="picker">
      <summary class="display">{season.title} <span aria-hidden="true">▾</span></summary>
      <ul>
        {seasons.map((x) => (
          <li><a href={seasonHref(x.id, small)} aria-current={x.id === id ? 'page' : undefined}>{x.title}</a></li>
        ))}
      </ul>
    </details>
    <nav class="pills" aria-label="League">
      <a class="pill" href={seasonHref(id)} aria-current={!small ? 'true' : undefined}>Main league</a>
      <a class="pill" href={seasonHref(id, true)} aria-current={small ? 'true' : undefined}>Small league</a>
    </nav>
    {season.tournamentCounts.length > 0 && (
      <div class="pills">
        {season.tournamentCounts.map((t) => <span class="pill">{t.count} {t.label.toLowerCase()}{t.count === 1 ? '' : 's'}</span>)}
      </div>
    )}
  </div>

  <div class="kpis">
    <Kpi label="Games" value={s ? String(s.games) : dash} />
    <Kpi label="Players" value={s ? String(s.players) : dash} />
    <Kpi label="City WR" value={s ? pct(s.cityWR) : dash} tone="city" />
    <Kpi label="Mafia WR" value={s ? pct(s.mafiaWR) : dash} tone="mafia" />
    <Kpi label="Main league" value={season.leagueCounts ? String(season.leagueCounts.main) : dash} />
    <Kpi label="Small league" value={season.leagueCounts ? String(season.leagueCounts.small) : dash} />
  </div>

  <div class="grid">
    <Panel title="Player ratings" note={small
      ? `${season.smallLeagueMinGames}–${season.gameLimit - 1} games`
      : `${season.gameLimit}+ games`} class="span-8">
      <DataTable table={league.ratings} />
    </Panel>
    <div class="span-4 side">
      {league.awards && (
        <Panel title="Awards">
          {league.awards.map((a) => <RankedList title={a.label} winner={a.winner} winnerLink={a.winnerLink} table={a.table} />)}
        </Panel>
      )}
      {league.stats.length > 0 && (
        <Panel title="Season stats">
          {league.stats.map((st) => <RankedList title={st.label} winner={st.winner} table={st.table} />)}
        </Panel>
      )}
    </div>
  </div>
</Base>

<style>
  .picker { position: relative; }
  .picker summary { list-style: none; cursor: pointer; font-size: clamp(22px, 3vw, 32px); }
  .picker summary::-webkit-details-marker { display: none; }
  .picker summary span { color: var(--muted); font-size: .6em; }
  .picker ul { position: absolute; z-index: 20; margin: 6px 0 0; padding: 6px; list-style: none;
    background: var(--panel-2); border: 1px solid var(--border); border-radius: var(--radius);
    max-height: 60vh; overflow-y: auto; min-width: 180px; }
  .picker li a { display: block; padding: 6px 10px; border-radius: 6px; }
  .picker li a[aria-current='page'] { color: var(--accent); }
  .kpis { display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 12px; margin-bottom: 16px; }
  @media (max-width: 899px) { .kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  .side { display: flex; flex-direction: column; gap: 16px; min-width: 0; }
</style>
```

- [ ] **Step 3: The two routes**

`site/src/pages/season/[id]/index.astro`:
```astro
---
import SeasonPage from '../../../components/SeasonPage.astro';
import { loadIndex } from '../../../lib/data';

export function getStaticPaths() {
  return loadIndex().seasons.map((s) => ({ params: { id: String(s.id) } }));
}
const id = Number(Astro.params.id);
---
<SeasonPage id={id} small={false} />
```

`site/src/pages/season/[id]/small/index.astro`:
```astro
---
import SeasonPage from '../../../../components/SeasonPage.astro';
import { loadIndex } from '../../../../lib/data';

export function getStaticPaths() {
  return loadIndex().seasons.map((s) => ({ params: { id: String(s.id) } }));
}
const id = Number(Astro.params.id);
---
<SeasonPage id={id} small={true} />
```

- [ ] **Step 4: Build and look**

Run: `cd site && npm run check && npx astro build && npx astro preview; cd ..` and open `http://localhost:4321/FamilyMafiaApp/season/<latest>/` and `/small/`.
Expected: KPI strip, ratings table with grouped role headers, awards and season stats on the right; the small league of an early season shows the empty message. (`npm run build` will still fail `check-dist` until Tasks 12–14 add the other pages.)

- [ ] **Step 5: Commit**
```bash
git add site/src/components/SeasonPage.astro site/src/components/RankedList.astro site/src/pages/season
git commit -m "feat(site): season pages for both leagues"
```

---

### Task 12: Players directory and profile

**Files:**
- Create: `site/src/components/GamesBySeasonChart.astro`, `site/src/components/Bars.astro`
- Create: `site/src/pages/players/index.astro`, `site/src/pages/players/[slug].astro`

**Interfaces:**
- Consumes: `loadPlayers`, `loadPlayer`, `DataTable`, `Panel`, `Kpi`, `Base`, `pct`, `seasonHref`.
- Produces:
  - `<GamesBySeasonChart timeline={PlayerData['timeline']} />` — SVG line of games per season over a league colour band (main = city red, small = amber, below = border grey, none = empty), `<title>` tooltips per point, season ticks every 5.
  - `<Bars items={{ label: string; value: number; text: string; color?: string; badge?: string | null }[]} />` — horizontal bars, `value` 0–1.

- [ ] **Step 1: Chart and bars**

`site/src/components/GamesBySeasonChart.astro`:
```astro
---
import type { PlayerData } from '../lib/types';
interface Props { timeline: PlayerData['timeline'] }
const { timeline } = Astro.props;
const W = 760, H = 220, padL = 32, padR = 12, padT = 12, band = 10, padB = 30;
const max = Math.max(1, ...timeline.map((t) => t.games));
const n = timeline.length;
const x = (i: number) => padL + (n === 1 ? (W - padL - padR) / 2 : (i * (W - padL - padR)) / (n - 1));
const y = (g: number) => padT + (1 - g / max) * (H - padT - padB - band - 6);
const played = timeline.map((t, i) => ({ ...t, i })).filter((t) => t.games > 0);
const path = played.map((t, k) => `${k ? 'L' : 'M'}${x(t.i).toFixed(1)},${y(t.games).toFixed(1)}`).join(' ');
const step = n > 1 ? (W - padL - padR) / (n - 1) : W;
const leagueColor = { main: 'var(--city)', small: 'var(--mid)', below: 'var(--border)', none: 'transparent' } as const;
const ticks = [0, Math.round(max / 2), max];
---
<svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Games per season">
  {ticks.map((t) => (
    <g>
      <line x1={padL} x2={W - padR} y1={y(t)} y2={y(t)} stroke="var(--border)" />
      <text x={padL - 6} y={y(t) + 4} text-anchor="end">{t}</text>
    </g>
  ))}
  {timeline.map((t, i) => (
    <rect x={x(i) - step / 2 + 1} y={H - padB - band} width={Math.max(2, step - 2)} height={band} rx="2" fill={leagueColor[t.league]}>
      <title>{`${t.title}: ${t.league === 'none' ? 'did not play' : t.league + ' league'}`}</title>
    </rect>
  ))}
  <path d={path} fill="none" stroke="var(--text)" stroke-width="2" />
  {played.map((t) => (
    <circle cx={x(t.i)} cy={y(t.games)} r="3.5" fill="var(--bg)" stroke="var(--text)" stroke-width="2">
      <title>{`${t.title}: ${t.games} games`}</title>
    </circle>
  ))}
  {timeline.map((t, i) => (t.seasonId % 5 === 0 || i === n - 1) && (
    <text x={x(i)} y={H - 8} text-anchor="middle">S{t.seasonId}</text>
  ))}
</svg>
<div class="legend label">
  <span><i style="background:var(--city)" />Main league</span>
  <span><i style="background:var(--mid)" />Small league</span>
  <span><i style="background:var(--border)" />Below threshold</span>
</div>

<style>
  svg { width: 100%; height: auto; display: block; }
  text { fill: var(--muted); font-size: 11px; font-family: var(--font-body); }
  .legend { display: flex; gap: 16px; flex-wrap: wrap; margin-top: 8px; }
  .legend i { display: inline-block; width: 10px; height: 10px; border-radius: 2px; margin-right: 6px; vertical-align: -1px; }
</style>
```

`site/src/components/Bars.astro`:
```astro
---
interface Item { label: string; value: number; text: string; color?: string; badge?: string | null }
interface Props { items: Item[] }
const { items } = Astro.props;
---
<ul class="bars">
  {items.map((it) => (
    <li>
      <div class="row">
        <span class="name" style={it.color ? `color:${it.color}` : undefined}>{it.label}</span>
        {it.badge && <span class="badge">{it.badge}</span>}
        <span class="text num">{it.text}</span>
      </div>
      <div class="track"><div class="fill" style={`width:${Math.max(0, Math.min(1, it.value)) * 100}%;${it.color ? `background:${it.color}` : ''}`} /></div>
    </li>
  ))}
</ul>

<style>
  .bars { list-style: none; margin: 0; padding: 0; display: grid; gap: 12px; }
  .row { display: flex; align-items: baseline; gap: 8px; margin-bottom: 4px; }
  .name { font-weight: 600; }
  .text { margin-left: auto; color: var(--muted); }
  .badge { font-size: 11px; padding: 1px 6px; border-radius: 999px; border: 1px solid var(--good); color: var(--good); }
  .track { height: 6px; background: var(--panel-2); border-radius: 3px; overflow: hidden; }
  .fill { height: 100%; background: var(--text); border-radius: 3px; }
</style>
```

- [ ] **Step 2: Directory page with search**

`site/src/pages/players/index.astro`:
```astro
---
import Base from '../../layouts/Base.astro';
import DataTable from '../../components/DataTable.astro';
import Panel from '../../components/Panel.astro';
import { loadPlayers } from '../../lib/data';
const { players, table } = loadPlayers();
---
<Base title="Players" description={`${players.length} Family Mafia players: games, win rate, seasons.`} active="players">
  <div class="pagehead">
    <h1 class="display">Players</h1>
    <input id="filter" type="search" placeholder="Filter by name…" aria-label="Filter players" />
  </div>
  <Panel>
    <DataTable table={table} />
    <p id="none" class="label" hidden>No player matches.</p>
  </Panel>
</Base>

<script>
  const input = document.getElementById('filter') as HTMLInputElement;
  const none = document.getElementById('none')!;
  const q = new URLSearchParams(location.search).get('q') ?? '';
  input.value = q;
  const apply = () => {
    const needle = input.value.trim().toLowerCase();
    let shown = 0;
    document.querySelectorAll<HTMLTableSectionElement>('[data-table] tbody').forEach((tb) => {
      const name = tb.querySelector('td:not([data-rank])')?.textContent?.toLowerCase() ?? '';
      const match = !needle || name.includes(needle);
      tb.style.display = match ? '' : 'none';
      if (match) shown++;
    });
    document.querySelector('[data-table]')?.classList.toggle('open', needle !== '');
    none.hidden = shown > 0;
  };
  input.addEventListener('input', apply);
  apply();
</script>

<style>
  #filter { background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius);
    color: var(--text); padding: 8px 12px; font: inherit; width: min(320px, 100%); }
</style>
```

- [ ] **Step 3: Profile page**

`site/src/pages/players/[slug].astro`:
```astro
---
import Base from '../../layouts/Base.astro';
import Bars from '../../components/Bars.astro';
import GamesBySeasonChart from '../../components/GamesBySeasonChart.astro';
import Kpi from '../../components/Kpi.astro';
import Panel from '../../components/Panel.astro';
import { loadPlayer, loadPlayers } from '../../lib/data';
import { pct } from '../../lib/format';

export function getStaticPaths() {
  return loadPlayers().players.map((p) => ({ params: { slug: p.slug } }));
}
const p = loadPlayer(Astro.params.slug!);
const a = p.accomplishments;
const roleColor = { civilian: 'var(--civilian)', sheriff: 'var(--sheriff)', mafia: 'var(--mafia)', don: 'var(--don)' } as const;
const badges = [
  ...['1st', '2nd', '3rd'].map((l, i) => ({ label: `Main ${l}`, n: a.main[i] })),
  ...['1st', '2nd', '3rd'].map((l, i) => ({ label: `Small ${l}`, n: a.small[i] })),
  { label: 'MVP', n: a.awards.mvp }, { label: 'Best Sheriff', n: a.awards.sheriff },
  { label: 'Best Civilian', n: a.awards.civilian }, { label: 'Best Mafia', n: a.awards.mafia },
  { label: 'Best Don', n: a.awards.don },
  ...a.tournaments.map((t) => ({ label: `${t.label} podium`, n: t.podiums })),
].filter((b) => b.n > 0);
const bm = p.bestMoves;
const fk = p.firstKill;
---
<Base title={p.name} description={`${p.name}: ${pct(p.winRate)} WR · ${p.games} games · ${p.seasons} seasons`} active="players">
  <div class="hero">
    <div class="avatar display">{p.initials}</div>
    <div class="who">
      <h1 class="display">{p.name}</h1>
      <div class="label">{p.games} games played</div>
    </div>
  </div>

  <div class="kpis">
    <Kpi label="Win rate" value={pct(p.winRate, 1)} />
    <Kpi label="Rating" value={p.latestRating === null ? '—' : p.latestRating.toFixed(2)} />
    <Kpi label="Seasons" value={String(p.seasons)} />
    <Kpi label="Accomplishments" value={String(a.total)} />
  </div>

  {badges.length > 0 && (
    <div class="pills badges">{badges.map((b) => <span class="pill">{b.label} <b>×{b.n}</b></span>)}</div>
  )}

  <div class="grid">
    <Panel title="Games by season" class="span-8"><GamesBySeasonChart timeline={p.timeline} /></Panel>
    <Panel title="Roles" class="span-4">
      <Bars items={p.roles.map((r) => ({
        label: r.label, value: r.share, color: roleColor[r.role], badge: r.top,
        text: `${r.games} · ${pct(r.share)} · ${r.wins}/${r.games} won`,
      }))} />
    </Panel>
    <Panel title="Killed first" note="Civilian and sheriff games" class="span-6">
      <div class="duo">
        <Kpi label="First killed" value={String(fk.total)} />
        <Kpi label="City lost after" value={String(fk.cityLost)} />
      </div>
      <p class="label">{fk.civSherGames > 0 ? `${pct(fk.total / fk.civSherGames, 1)} of ${fk.civSherGames} red games` : 'No red games yet'}</p>
    </Panel>
    <Panel title="Best move" note="Black cards found when killed first" class="span-6">
      {bm.firstKilled === 0 ? <p class="label">No best moves recorded.</p> : (
        <Bars items={[
          { label: '3 black', value: bm.three / bm.firstKilled, text: `${bm.three}`, color: 'var(--good)' },
          { label: '2 black', value: bm.two / bm.firstKilled, text: `${bm.two}` },
          { label: '1 black', value: bm.one / bm.firstKilled, text: `${bm.one}` },
          { label: '0 black', value: bm.zero / bm.firstKilled, text: `${bm.zero}`, color: 'var(--muted)' },
        ]} />
      )}
    </Panel>
  </div>
</Base>

<style>
  .hero { display: flex; align-items: center; gap: 16px; margin-bottom: 20px; }
  .avatar { width: 64px; height: 64px; border-radius: 12px; display: grid; place-items: center;
    background: var(--panel-2); border: 1px solid var(--border); color: var(--accent); font-size: 22px; flex: none; }
  .who { min-width: 0; }
  .who h1 { overflow-wrap: anywhere; }
  .kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 14px; }
  @media (max-width: 899px) { .kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
  .badges { margin-bottom: 16px; flex-wrap: wrap; }
  .badges b { color: var(--text); }
  .duo { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 8px; }
</style>
```

- [ ] **Step 4: Check and look**

Run: `cd site && npm run check && npx astro build && npx astro preview; cd ..`, open `/FamilyMafiaApp/players/`, type a name, open a profile; also `/FamilyMafiaApp/players/?q=са`.
Expected: the filter narrows rows; the profile shows hero, KPIs, badges, chart, roles, first kill, best move.

- [ ] **Step 5: Commit**
```bash
git add site/src/components/GamesBySeasonChart.astro site/src/components/Bars.astro site/src/pages/players
git commit -m "feat(site): player directory with search and player profiles"
```

---

### Task 13: Overview page

**Files:**
- Create: `site/src/components/RoleRings.astro`
- Create: `site/src/pages/overview.astro`

**Interfaces:**
- Consumes: `loadIndex`, `DataTable`, `Panel`, `Kpi`, `Base`, `pct`.
- Produces: `<RoleRings roleWR={IndexData['roleWR']} />` — four SVG rings, one per role, coloured by role.

- [ ] **Step 1: Rings**

`site/src/components/RoleRings.astro`:
```astro
---
import type { IndexData, RoleKey } from '../lib/types';
import { pct } from '../lib/format';
interface Props { roleWR: IndexData['roleWR'] }
const { roleWR } = Astro.props;
const roles: { key: RoleKey; label: string }[] = [
  { key: 'civilian', label: 'Civilian' }, { key: 'sheriff', label: 'Sheriff' },
  { key: 'mafia', label: 'Mafia' }, { key: 'don', label: 'Don' },
];
const r = 34, c = 2 * Math.PI * r;
---
<div class="rings">
  {roles.map(({ key, label }) => (
    <figure>
      <svg viewBox="0 0 80 80" role="img" aria-label={`${label} win rate ${pct(roleWR[key])}`}>
        <circle cx="40" cy="40" r={r} fill="none" stroke="var(--panel-2)" stroke-width="8" />
        <circle cx="40" cy="40" r={r} fill="none" stroke={`var(--${key})`} stroke-width="8" stroke-linecap="round"
          stroke-dasharray={`${(roleWR[key] * c).toFixed(1)} ${c.toFixed(1)}`} transform="rotate(-90 40 40)" />
        <text x="40" y="45" text-anchor="middle">{pct(roleWR[key])}</text>
      </svg>
      <figcaption class={`label role-${key}`}>{label}</figcaption>
    </figure>
  ))}
</div>

<style>
  .rings { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
  figure { margin: 0; text-align: center; }
  svg { width: 100%; max-width: 120px; }
  text { fill: var(--text); font: 700 15px var(--font-display); }
</style>
```

- [ ] **Step 2: Page**

`site/src/pages/overview.astro`:
```astro
---
import Base from '../layouts/Base.astro';
import DataTable from '../components/DataTable.astro';
import Kpi from '../components/Kpi.astro';
import Panel from '../components/Panel.astro';
import RoleRings from '../components/RoleRings.astro';
import { loadIndex } from '../lib/data';
import { pct } from '../lib/format';
const d = loadIndex();
---
<Base title="Overview" description={`All time: ${d.club.seasons} seasons, ${d.club.games} games, ${d.club.players} players.`} active="overview">
  <div class="pagehead"><h1 class="display">All time</h1></div>
  <div class="kpis">
    <Kpi label="Seasons" value={String(d.club.seasons)} />
    <Kpi label="Games" value={String(d.club.games)} />
    <Kpi label="Players" value={String(d.club.players)} />
    <Kpi label="City WR" value={pct(d.club.cityWR)} tone="city" />
  </div>
  <div class="grid">
    <Panel title="Win rate by role" class="span-12"><RoleRings roleWR={d.roleWR} /></Panel>
    {d.leaderboards.map((l) => (
      <Panel title={`Best ${l.label}`} note={l === d.leaderboards[0] ? d.leaderboardNote : undefined} class="span-3">
        <DataTable table={l.table} compact />
      </Panel>
    ))}
    <Panel title="Protocol guesses" class="span-4"><DataTable table={d.protocol} compact /></Panel>
    <Panel title="Seasons" class="span-8"><DataTable table={d.seasonsTable} compact /></Panel>
  </div>
</Base>

<style>
  .kpis { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-bottom: 16px; }
  @media (max-width: 899px) { .kpis { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
</style>
```
If four leaderboards at `span-3` are too narrow at 1280 px (names truncated), switch them to `span-6` — judge in Task 17.

- [ ] **Step 3: Check and look**

Run: `cd site && npm run check && npx astro build && npx astro preview; cd ..`, open `/FamilyMafiaApp/overview/`.
Expected: KPIs, rings, four leaderboards, protocol, seasons table sorted newest first.

- [ ] **Step 4: Commit**
```bash
git add site/src/components/RoleRings.astro site/src/pages/overview.astro
git commit -m "feat(site): all-time overview page"
```

---

### Task 14: Records pages

**Files:**
- Create: `site/src/pages/records/index.astro`, `site/src/pages/records/[category].astro`

**Interfaces:**
- Consumes: `loadRecords`, `DataTable`, `Panel`, `Base`, `href`.
- Produces: `/records/` (redirect to `/records/mvp/`) and `/records/<slug>/` with `?role=&scope=&period=`; filter pills are links; JS shows the matching table and updates the URL with `history.replaceState`; without JS the default table is visible.

- [ ] **Step 1: Redirect**

`site/src/pages/records/index.astro`:
```astro
---
import { href } from '../../lib/url';
const target = href('records/mvp/');
---
<!doctype html>
<html lang="en"><head><meta charset="utf-8" /><meta http-equiv="refresh" content={`0; url=${target}`} /><link rel="canonical" href={target} /><title>Records · Family Mafia</title></head>
<body style="background:#0B0D10"><a href={target} style="color:#E5484D">Records</a></body></html>
```

- [ ] **Step 2: Category page**

`site/src/pages/records/[category].astro`:
```astro
---
import Base from '../../layouts/Base.astro';
import DataTable from '../../components/DataTable.astro';
import Panel from '../../components/Panel.astro';
import { loadRecords } from '../../lib/data';
import { href } from '../../lib/url';
import type { FilterName } from '../../lib/types';

export function getStaticPaths() {
  return loadRecords().categories.map((c) => ({ params: { category: c.slug } }));
}
const data = loadRecords();
const cat = data.categories.find((c) => c.slug === Astro.params.category)!;
const options: Record<FilterName, { key: string; label: string }[]> = {
  role: data.roles, scope: data.scopes, period: data.periods,
};
const order: FilterName[] = ['role', 'scope', 'period'];
const filters = order.filter((f) => cat.filters.includes(f));

// Every combination of this category's filters → its table.
const combos: Record<FilterName, string>[] = filters.reduce<Record<FilterName, string>[]>(
  (acc, f) => acc.flatMap((c) => options[f].map((o) => ({ ...c, [f]: o.key }))),
  [{ ...data.defaults }],
);
const keyOf = (c: Record<FilterName, string>) => [cat.slug, ...filters.map((f) => c[f])].join('/');
const isDefault = (c: Record<FilterName, string>) => filters.every((f) => c[f] === data.defaults[f]);
const pillHref = (f: FilterName, key: string) => {
  const params = new URLSearchParams(filters.map((g) => [g, g === f ? key : data.defaults[g]]));
  return `?${params}`;
};
---
<Base title={`${cat.label} records`} description={`Family Mafia all-time ${cat.label} records.`} active="records">
  <div class="pagehead"><h1 class="display">Records</h1></div>
  <nav class="pills cats" aria-label="Category">
    {data.categories.map((c) => (
      <a class="pill" href={href(`records/${c.slug}/`)} aria-current={c.slug === cat.slug ? 'true' : undefined}>{c.label}</a>
    ))}
  </nav>
  {filters.map((f) => (
    <nav class="pills filter" data-filter={f} aria-label={f}>
      {options[f].map((o) => (
        <a class="pill" href={pillHref(f, o.key)} data-key={o.key} aria-current={o.key === data.defaults[f] ? 'true' : undefined}>{o.label}</a>
      ))}
    </nav>
  ))}
  {combos.map((c) => {
    const entry = data.tables[keyOf(c)];
    return (
      <section data-combo={JSON.stringify(c)} hidden={!isDefault(c)}>
        <Panel title={cat.label} note={entry.scope}><DataTable table={entry.table} /></Panel>
      </section>
    );
  })}
</Base>

<script>
  const filters = [...document.querySelectorAll<HTMLElement>('[data-filter]')];
  const sections = [...document.querySelectorAll<HTMLElement>('[data-combo]')];
  const defaults: Record<string, string> = {};
  filters.forEach((nav) => {
    defaults[nav.dataset.filter!] = nav.querySelector('[aria-current="true"]')?.getAttribute('data-key') ?? '';
  });
  const state: Record<string, string> = { ...defaults };
  const params = new URLSearchParams(location.search);
  filters.forEach((nav) => {
    const f = nav.dataset.filter!;
    const v = params.get(f);
    if (v && nav.querySelector(`[data-key="${CSS.escape(v)}"]`)) state[f] = v;
  });

  function render() {
    filters.forEach((nav) => nav.querySelectorAll('[data-key]').forEach((a) =>
      a.setAttribute('aria-current', a.getAttribute('data-key') === state[nav.dataset.filter!] ? 'true' : 'false')));
    sections.forEach((s) => {
      const combo = JSON.parse(s.dataset.combo!) as Record<string, string>;
      s.hidden = !Object.keys(state).every((f) => combo[f] === state[f]);
    });
    const qs = new URLSearchParams(state).toString();
    history.replaceState(null, '', qs ? `?${qs}` : location.pathname);
  }

  filters.forEach((nav) => nav.addEventListener('click', (e) => {
    const a = (e.target as HTMLElement).closest('[data-key]');
    if (!a) return;
    e.preventDefault();
    state[nav.dataset.filter!] = a.getAttribute('data-key')!;
    render();
  }));
  render();
</script>

<style>
  .cats, .filter { margin-bottom: 10px; }
  .filter .pill { font-size: 12px; padding: 3px 10px; }
</style>
```

- [ ] **Step 3: Full build including dist checks**

Run: `cd site && npm run check && npm test && npm run build; cd ..`
Expected: `check-dist: N files, M players, all links resolve`. Then `npx astro preview` and open `/FamilyMafiaApp/records/roles/?role=sheriff&period=li` — the Sheriff · Seasons 2–3 table is shown, and switching pills changes the URL without reloading.

- [ ] **Step 4: Commit**
```bash
git add site/src/pages/records
git commit -m "feat(site): records pages with shareable filters"
```

---

### Task 15: Telegram preview image

**Files:**
- Create: `site/scripts/make-og.mjs`, `site/public/og.png`

- [ ] **Step 1: Script**

`site/scripts/make-og.mjs`:
```js
// Renders public/og.png (1200×630) for link previews. Run manually: node scripts/make-og.mjs
import fs from 'node:fs';
import { Resvg } from '@resvg/resvg-js';

const icon = fs.readFileSync(new URL('../../assets/app_icon.png', import.meta.url)).toString('base64');
const svg = `
<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
  <rect width="1200" height="630" fill="#0B0D10"/>
  <rect x="0" y="0" width="1200" height="8" fill="#E5484D"/>
  <image href="data:image/png;base64,${icon}" x="96" y="171" width="288" height="288"/>
  <text x="440" y="300" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="92" fill="#E6E8EB">FAMILY</text>
  <text x="440" y="400" font-family="Arial Black, Arial, sans-serif" font-weight="900" font-size="92" fill="#E5484D">MAFIA</text>
  <text x="444" y="460" font-family="Arial, sans-serif" font-size="32" fill="#8B95A1">Club statistics · seasons · players · records</text>
</svg>`;
const png = new Resvg(svg, { font: { loadSystemFonts: true } }).render().asPng();
fs.writeFileSync(new URL('../public/og.png', import.meta.url), png);
console.log(`og.png: ${png.length} bytes`);
```

- [ ] **Step 2: Render and look**

Run: `cd site && node scripts/make-og.mjs; cd ..`, then open `site/public/og.png` (Read tool or an image viewer).
Expected: dark card, app icon left, "FAMILY / MAFIA" right, readable text. Tweak sizes if anything clips.

- [ ] **Step 3: Commit**
```bash
git add site/scripts/make-og.mjs site/public/og.png
git commit -m "feat(site): dark link-preview image"
```

---

### Task 16: CI and docs

**Files:**
- Modify: `.github/workflows/web.yml` (the build job's steps after the prefetch)
- Modify: `CLAUDE.md` (Build Commands, "Web site" section)

- [ ] **Step 1: Replace the build steps**

In `.github/workflows/web.yml`, replace everything from `- run: flutter test` to the end of the `upload-pages-artifact` step with:
```yaml
      - run: flutter test

      - name: Export site data
        run: flutter test tool/export_site_data_test.dart

      - uses: actions/setup-node@v4
        with:
          node-version: '24'
          cache: npm
          cache-dependency-path: site/package-lock.json

      - name: Build site
        working-directory: site
        run: |
          npm ci
          npm run check
          npm test
          npm run build

      - uses: actions/upload-pages-artifact@v3
        with:
          path: site/dist
```
(`npm run build` runs `check-dist.mjs`: the `AIza` guard, the link check and the per-player page check replace the two old grep guards.)

- [ ] **Step 2: Update CLAUDE.md**

In "Build Commands", replace the two web lines (`flutter run -d chrome …` and `flutter build web …`) with:
```bash
flutter test tool/export_site_data_test.dart   # Export site JSON into site/data/ (needs assets/prefetched/ for remote seasons)
cd site && npm ci && npm run dev               # Stats site dev server (reads site/data/)
cd site && npm run build                       # What CI deploys: site/dist, plus link / key / player-page checks
```
Replace the bullets of the "## Web site" section with:
```markdown
- The site is a static Astro project in `site/`, **not** the Flutter web build. Its data is
  JSON computed by the app's own providers: `tool/export_site_data_test.dart` loads every
  season through `loadSiteContainer()` (`lib/site_export/`) and `writeSiteData` writes
  `site/data/` (gitignored). Every table is exported display-ready (`SiteTable`), formatted
  in Dart like the app's widgets; the site only lays out and sorts.
- Adding a stat to the site = add it to the matching `lib/site_export/*_export.dart` and
  render it in `site/src/`. The app UI is unaffected.
- The build has **no API keys**: the export overrides `envJsonProvider` to `{}` and reads
  remote seasons + config from the `assets/prefetched/` snapshot; `site/scripts/check-dist.mjs`
  fails the build if `AIza` appears, an internal link is broken, or a player has no page.
- Player URLs are `/players/<slug>/`, transliterated from the display name (`slugs.dart`);
  renaming a player changes the URL.
- `web/`, `WebFrame` and the `kIsWeb` branches still exist in the app but are no longer deployed.
- GitHub disables `schedule` workflows in public repos after 60 days without
  repo activity; if the nightly build stops, re-enable it in the Actions tab.
- Running the prefetch locally leaves a ~650 KB snapshot in `assets/prefetched/`
  that also goes into local release APKs (no secrets, just data). Before a
  release APK: `rm assets/prefetched/season*.json assets/prefetched/remote_config.json`.
```
and delete the "Note on Windows" paragraph about `--base-href` (no longer used).

- [ ] **Step 3: Validate the workflow locally**

Run the same sequence CI runs:
```bash
flutter test && flutter test tool/export_site_data_test.dart && (cd site && npm ci && npm run check && npm test && npm run build)
```
Expected: everything passes, ending with `check-dist: … all links resolve`.

- [ ] **Step 4: Commit**
```bash
git add .github/workflows/web.yml CLAUDE.md
git commit -m "ci: deploy the Astro stats site instead of the Flutter web build"
```

---

### Task 17: Visual verification in Chrome, then ship

**Files:** none new (fixes go back into the owning task's files).

- [ ] **Step 1: Serve the production build**

Run (background): `cd site && npx astro preview --port 4321`

- [ ] **Step 2: Walk every page at 1440 px and 390 px**

Use the claude-in-chrome tools. Pages: `/FamilyMafiaApp/` (redirects), `season/<latest>/`, `season/<latest>/small/`, `season/0/small/` (empty league), a season ≥ 29 (protocol columns), `players/`, `players/?q=<part of a name>`, the profile of the top player and of a 1-season player, `overview/`, `records/mvp/`, `records/roles/?role=sheriff&period=li`, `records/hosts/?scope=alltime`, a missing URL (404).

At each, check: dark theme and fonts load; numbers right-aligned; sorting a column works and the rank renumbers; "Show all" works; at 390 px the hidden columns appear when a row is tapped; and run in the page:
```js
document.documentElement.scrollWidth <= window.innerWidth
```
Expected: `true` on every page (Review Focus 5). Any `false` → find the overflowing element, fix its CSS (`min-width: 0`, `overflow-wrap: anywhere`, or wrapping it in `.scroll`), rebuild, recheck.

- [ ] **Step 3: Spot-check numbers against the app**

Compare at least: latest season Games / City WR / top-3 ratings; one player's games and WR; the Don records #1. They must match the Android app exactly.

- [ ] **Step 4: Commit any fixes**
```bash
git add -A site/src
git commit -m "fix(site): layout fixes from the browser walkthrough"
```

- [ ] **Step 5: Ship (after the user approves)**

```bash
git push origin feature/flutter_migration
git push origin feature/flutter_migration:master
```
Then watch the "Web site" workflow run to green, open https://seezov.github.io/FamilyMafiaApp/ and repeat a short version of Step 2 on the live URL.
