# Annual Rating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The site shows the club's annual rating per year (2024+) and admins enter external
tournaments, series and marathons on `/annual/edit/` instead of the sheet.

**Architecture:** Events live in Firestore `events/{id}` (public read, admin write). CI's
prefetch snapshots them into `assets/prefetched/annual_events.json`; the site export adds
derived club-season events (S28+), computes points and standings in pure Dart and writes
`site/data/annual.json`. Astro renders `/annual/` + `/annual/<year>/`; `/annual/edit/` is a
client page that reads/writes Firestore directly, with a TS port of the points formula checked
against the same fixture as Dart.

**Tech Stack:** Dart/Flutter test runner, Riverpod (export only), Firestore REST, Astro 7,
TypeScript, Firebase JS SDK 12, vitest, `@firebase/rules-unit-testing`.

**Spec:** `docs/superpowers/specs/2026-10-05-annual-rating-design.md`

## Global Constraints

- Site only; the Flutter app's screens are unchanged.
- Years 2024, 2025, 2026 and later; 2023 is not migrated.
- Points: Сезон 1→18, 2→15, 3→12, 4→9, 5→6, 6–10→4, 11+→2, 101→5, 102→4, 103→3, 104→2, 105→1 (101–105 checked before 11+); Серія 1→10, 2→8, 3→6, 4→4, 5→3, 6→2, 7→2, 8+→1; Марафон 1→6, 2→4, 3→3, 4→2, 5→2, 6+→1; Турнір `b = 1 + stars/3`; place < 1 → 0; place < 11 → `b + (N − place)·b/4`; place < N/2 → `b + (N − place)·b/5`; else `b + (N − place)·b/10`.
- Annual score = sum of the 12 best event points, rounded to 2 decimals; wins = place 1, top-3 = place < 4, top-10 = place < 11, participations = place > 0.
- Derived season events: club seasons with id ≥ 28 that are not in progress; main league ranks 1…N, small league top 5 as 101–105; year = year of the season's last month (median-game quarter; December → next year).
- Event document keys exactly: `year, kind, name, date, stars, participants, results, updatedAt, updatedBy, updatedByEmail`; kind ∈ `tournament | series | marathon | season`.
- Every save/delete/import also sets `meta/state.updatedAt`.
- `tool/prefetch_seasons.dart` and everything it imports stay pure Dart (no Flutter).
- Site copy is English. No browser dialogs (`alert`/`confirm`) on the edit page.
- `lib/models/annual_event.dart` and `lib/services/stats/annual_rating.dart` import no Flutter.

## Review Focus

1. A tournament saved with participants smaller than a place (or 0) → negative or nonsense points; the edit page must refuse it before saving (Task 7 validation test).
2. A player entered under an old nickname (Скай, Luna, RedFox) must count toward the same person as their club games — the export groups by `personKey(resolver.resolve(name))` (Task 5 test).
3. A season still being played (S31 today) must not appear as an event until it ends (Task 5 test with an injected clock).
4. An empty `events` collection (before the import) must still build: prefetch writes `[]`, the page shows the derived season events only (Task 3 + Task 5 tests).
5. A malformed event document (string place, missing kind) must fail the build naming the document id, not silently drop rows (Task 3 test).

---

### Task 1: One-time import snapshot and fixtures

**Files:**
- Create: `tool/import/make_annual_import.py`
- Create (generated): `tool/import/annual_events.json`, `test/fixtures/annual_totals.json`, `test/fixtures/annual_2026_seasons.json`, `test/fixtures/annual_points_cases.json`

**Interfaces:**
- Produces: `tool/import/annual_events.json` = JSON list of `{year:int, kind:string, name:string, date:string|null, stars:int|null, participants:int|null, results:[{player:string, place:int}]}` (no 2026 season blocks); `test/fixtures/annual_totals.json` = `{"2024": {"<raw name>": total}, "2025": {...}, "2026": {...}}` (only players with total > 0); `test/fixtures/annual_2026_seasons.json` = the three 2026 season blocks in the event shape above; `test/fixtures/annual_points_cases.json` = list of `{kind, place, stars, participants, points}` (every distinct (kind, place, stars, participants) combination from the three years, points from the sheet).

- [ ] **Step 1: Write the generator**

```python
# One-time: snapshot the sheets' «Турніри» blocks (2024–2026) for the annual-rating import.
# Usage: SHEETS_API_KEY=... python tool/import/make_annual_import.py
import datetime, json, os, urllib.parse, urllib.request

KEY = os.environ['SHEETS_API_KEY']
YEARS = {2024: '1Vhw0fURnqQyluJYJEuwJeq5amicGWk3jXsId3gxYoys',   # S23 sheet
         2025: '1J1PwfQvCai21fa_rDRkC10bXIeaVCBiHsC0onXXYXBU',   # S27 sheet
         2026: '1vSyEfRhBowqfzpsPkcQYmlFFnjO819kL1fhC8jo7D5k'}   # S31 sheet
KINDS = {'Турнір': 'tournament', 'Серія': 'series', 'Марафон': 'marathon', 'Сезон': 'season'}


def grid(sheet, tab, rng):
    url = (f'https://sheets.googleapis.com/v4/spreadsheets/{sheet}?ranges='
           f'{urllib.parse.quote(tab)}!{rng}&includeGridData=true'
           f'&fields=sheets.data.rowData.values(formattedValue,effectiveValue)&key={KEY}')
    data = json.load(urllib.request.urlopen(url))
    out = []
    for r in data['sheets'][0]['data'][0].get('rowData', []):
        row = []
        for v in r.get('values', []):
            ev = v.get('effectiveValue', {})
            row.append(ev.get('numberValue', ev.get('stringValue', v.get('formattedValue', ''))))
        out.append(row)
    return out


def cell(r, j):
    return r[j] if j < len(r) else ''


def as_int(v):
    if v in ('', None):
        return None
    return int(float(v))


def as_date(v):
    if v in ('', None):
        return None
    if isinstance(v, (int, float)):  # sheet serial day
        return (datetime.date(1899, 12, 30) + datetime.timedelta(days=int(v))).isoformat()
    s = str(v).strip()
    for fmt in ('%Y-%m-%d', '%m/%d/%Y', '%d.%m.%Y'):
        try:
            return datetime.datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            pass
    raise ValueError(f'unknown date {s!r}')


events, seasons2026, totals, cases = [], [], {}, {}
for year, sheet in YEARS.items():
    g = grid(sheet, 'Турніри', 'A1:J1600')
    i = 0
    while i < len(g):
        r = g[i]
        if cell(r, 2) != 'Дата' or cell(r, 0) not in KINDS:
            i += 1
            continue
        kind = KINDS[cell(r, 0)]
        meta = g[i + 1] if i + 1 < len(g) else []
        stars, n = as_int(cell(meta, 1)), as_int(cell(meta, 3))
        results, j = [], i + 3
        while j < len(g) and cell(g[j], 2) != 'Дата':
            name, place, pts = cell(g[j], 0), cell(g[j], 1), cell(g[j], 3)
            if isinstance(name, str) and name.strip() and place != '':
                results.append({'player': name.strip(), 'place': int(place)})
                key = (kind, int(place), stars if kind == 'tournament' else None,
                       n if kind == 'tournament' else None)
                cases[key] = pts
            j += 1
        if results:
            if kind == 'tournament':
                assert stars is not None and n, f'{year} {cell(r, 1)}: tournament without stars/participants'
            ev = {'year': year, 'kind': kind, 'name': str(cell(r, 1)).strip() or f'{cell(r, 0)} {year}',
                  'date': as_date(cell(r, 3)),
                  'stars': stars if kind == 'tournament' else None,
                  'participants': n if kind == 'tournament' else None,
                  'results': results}
            (seasons2026 if year == 2026 and kind == 'season' else events).append(ev)
        i = j
    a = grid(sheet, 'Річний рейтинг', 'B6:C200')
    totals[str(year)] = {str(r[0]).strip(): r[1] for r in a
                         if len(r) > 1 and str(r[0]).strip() and isinstance(r[1], (int, float)) and r[1] > 0}

os.makedirs('tool/import', exist_ok=True)


def dump(path, obj):
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(obj, f, ensure_ascii=False, indent=1)
        f.write('\n')


dump('tool/import/annual_events.json', events)
dump('test/fixtures/annual_2026_seasons.json', seasons2026)
dump('test/fixtures/annual_totals.json', totals)
dump('test/fixtures/annual_points_cases.json',
     [{'kind': k, 'place': p, 'stars': s, 'participants': n, 'points': v}
      for (k, p, s, n), v in sorted(cases.items(), key=lambda x: (x[0][0], x[0][1], x[0][2] or 0, x[0][3] or 0))])
print(len(events), 'events,', len(seasons2026), '2026 season blocks,', len(cases), 'point cases')
```

- [ ] **Step 2: Run it**

Run: `SHEETS_API_KEY=$(python -c "import json;print(json.load(open('assets/.env.json'))['SHEETS_API_KEY'])") python tool/import/make_annual_import.py`
Expected: prints about `125 events, 3 2026 season blocks, … point cases`; no assertion error. If a tournament block lacks stars/participants, ledger a ruling (that block's sheet points were computed with 0) and store `stars: 0` / the place count as participants only if that reproduces the sheet's points.

- [ ] **Step 3: Sanity-check the outputs**

Run: `python -c "import json;e=json.load(open('tool/import/annual_events.json',encoding='utf-8'));print({y:sum(1 for x in e if x['year']==y) for y in (2024,2025,2026)}, sum(len(x['results']) for x in e))"`
Expected: three non-zero counts; 2026 has no `season` events; `annual_totals.json` has Seezov 132.13 under 2026 and Залізний 317.82 under 2024.

- [ ] **Step 4: Commit**

```bash
git add tool/import test/fixtures/annual_totals.json test/fixtures/annual_2026_seasons.json test/fixtures/annual_points_cases.json
git commit -m "chore: snapshot the sheets' annual-rating events for the one-time import"
```

---

### Task 2: Pure-Dart event model and annual standings

**Files:**
- Create: `lib/models/annual_event.dart`
- Create: `lib/services/stats/annual_rating.dart`
- Test: `test/services/stats/annual_rating_test.dart`

**Interfaces:**
- Consumes: Task 1 fixtures.
- Produces:
  - `enum AnnualKind { tournament, series, marathon, season }` with `static AnnualKind parse(String)` (throws `FormatException`) and `String get label` (`Tournament`, `Series`, `Marathon`, `Season`).
  - `class AnnualResult { final String player; final int place; }`
  - `class AnnualEvent { final String id; final int year; final AnnualKind kind; final String name; final String? date; final int? stars; final int? participants; final List<AnnualResult> results; factory AnnualEvent.fromJson(Map<String, dynamic> json, {required String id}); Map<String, Object?> toJson(); }` — `fromJson` throws `FormatException('event <id>: <what>')` on any bad field.
  - `List<AnnualEvent> parseAnnualEvents(String json)` — top-level list of objects each with an `id` string.
  - `double eventPoints(AnnualKind kind, int place, {int? stars, int? participants})`
  - `class AnnualEntry { final AnnualEvent event; final int place; final double points; bool counted; }`
  - `class AnnualStanding { final String key; final String name; final List<AnnualEntry> entries; final double score; final int wins, top3, top10, participations; int rank; }`
  - `List<AnnualStanding> annualStandings(Iterable<AnnualEvent> events, {required String Function(String player) keyOf, String Function(String player)? nameOf})` — sorted by score desc, then name; competition ranks (equal score → equal rank).
  - `int seasonYear(List<DateTime> gameDates)` — year of the season's last month.

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/annual_event.dart';
import 'package:family_mafia_app/services/stats/annual_rating.dart';
import 'package:flutter_test/flutter_test.dart';

List<AnnualEvent> _load(String path) => [
      for (final (i, e) in (jsonDecode(File(path).readAsStringSync()) as List).indexed)
        AnnualEvent.fromJson(e as Map<String, dynamic>, id: '$path#$i')
    ];

void main() {
  test('every sheet case gets the sheet points', () {
    final cases = jsonDecode(File('test/fixtures/annual_points_cases.json').readAsStringSync()) as List;
    expect(cases, isNotEmpty);
    for (final c in cases.cast<Map<String, dynamic>>()) {
      expect(
        eventPoints(AnnualKind.parse(c['kind'] as String), c['place'] as int,
            stars: c['stars'] as int?, participants: c['participants'] as int?),
        closeTo((c['points'] as num).toDouble(), 1e-9),
        reason: '$c',
      );
    }
  });

  test('formula edges', () {
    expect(eventPoints(AnnualKind.season, 101), 5);
    expect(eventPoints(AnnualKind.season, 11), 2);
    expect(eventPoints(AnnualKind.season, 7), 4);
    expect(eventPoints(AnnualKind.series, 12), 1);
    expect(eventPoints(AnnualKind.marathon, 6), 1);
    expect(eventPoints(AnnualKind.tournament, 0, stars: 3, participants: 30), 0);
    // place 9 of 30, 2 stars: b = 5/3; b + 21·b/4
    expect(eventPoints(AnnualKind.tournament, 9, stars: 2, participants: 30), closeTo(10.4166666667, 1e-9));
  });

  test('2024 and 2025 standings equal the sheet totals (names as written)', () {
    final all = _load('tool/import/annual_events.json');
    final totals = jsonDecode(File('test/fixtures/annual_totals.json').readAsStringSync()) as Map<String, dynamic>;
    for (final year in [2024, 2025]) {
      final got = {
        for (final s in annualStandings(all.where((e) => e.year == year), keyOf: (n) => n))
          if (s.score > 0) s.key: s.score
      };
      final want = (totals['$year'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
      expect(got, want, reason: '$year');
    }
  });

  test('2026 with the sheet season blocks equals the sheet totals', () {
    final events = [
      ..._load('tool/import/annual_events.json').where((e) => e.year == 2026),
      ..._load('test/fixtures/annual_2026_seasons.json'),
    ];
    final totals = jsonDecode(File('test/fixtures/annual_totals.json').readAsStringSync()) as Map<String, dynamic>;
    final got = {
      for (final s in annualStandings(events, keyOf: (n) => n))
        if (s.score > 0) s.key: s.score
    };
    expect(got, (totals['2026'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())));
  });

  test('best 12 count, the rest are marked not counted; ranks share ties', () {
    AnnualEvent ev(int i, String who, int place) => AnnualEvent(
        id: 'e$i', year: 2026, kind: AnnualKind.series, name: 'S$i',
        results: [AnnualResult(who, place)]);
    final events = [
      for (var i = 0; i < 13; i++) ev(i, 'A', i == 0 ? 1 : 8), // one 10, twelve 1s
      ev(100, 'B', 1), ev(101, 'C', 1),
    ];
    final s = annualStandings(events, keyOf: (n) => n);
    final a = s.firstWhere((x) => x.key == 'A');
    expect(a.score, 21); // 10 + 11 × 1
    expect(a.entries.where((e) => e.counted).length, 12);
    expect(a.participations, 13);
    expect(a.wins, 1);
    expect(a.top10, 13);
    expect([for (final x in s) x.rank], [1, 2, 2]);
  });

  test('seasonYear: winter counts in the year it ends', () {
    expect(seasonYear([DateTime.utc(2025, 12, 5), DateTime.utc(2026, 1, 10), DateTime.utc(2026, 2, 1)]), 2026);
    expect(seasonYear([DateTime.utc(2025, 12, 5), DateTime.utc(2025, 12, 20), DateTime.utc(2026, 1, 3)]), 2026);
    expect(seasonYear([DateTime.utc(2026, 9, 5), DateTime.utc(2026, 10, 1), DateTime.utc(2026, 11, 3)]), 2026);
  });

  test('fromJson rejects bad documents with their id', () {
    Map<String, dynamic> ok() => {
          'year': 2026, 'kind': 'tournament', 'name': 'Cup', 'date': '2026-02-28',
          'stars': 2, 'participants': 30, 'results': [{'player': 'A', 'place': 1}],
        };
    expect(AnnualEvent.fromJson(ok(), id: 'x').results.single.place, 1);
    for (final bad in <Map<String, dynamic>>[
      {...ok(), 'kind': 'cup'},
      {...ok(), 'year': '2026'},
      {...ok(), 'name': ''},
      {...ok(), 'results': [{'player': 'A', 'place': '1'}]},
      {...ok(), 'results': [{'player': '', 'place': 1}]},
      {...ok(), 'results': [{'player': 'A', 'place': 0}]},
      {...ok(), 'participants': null},
      {...ok(), 'stars': 9},
      {...ok(), 'date': 5},
    ]) {
      expect(() => AnnualEvent.fromJson(bad, id: 'doc7'),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('doc7'))), reason: '$bad');
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/services/stats/annual_rating_test.dart`
Expected: FAIL — compile errors, `annual_event.dart` / `annual_rating.dart` not found.

- [ ] **Step 3: Implement `lib/models/annual_event.dart`**

```dart
// Pure Dart on purpose: tool/prefetch_seasons.dart validates Firestore events with it.
import 'dart:convert';

/// The kinds of events in the annual rating (the sheet's «Турнір», «Серія»,
/// «Марафон», «Сезон» blocks).
enum AnnualKind {
  tournament('Tournament'),
  series('Series'),
  marathon('Marathon'),
  season('Season');

  const AnnualKind(this.label);

  final String label;

  static AnnualKind parse(String v) => values.firstWhere((k) => k.name == v,
      orElse: () => throw FormatException('unknown event kind "$v"'));
}

class AnnualResult {
  const AnnualResult(this.player, this.place);

  /// The name as entered; the export resolves nicknames.
  final String player;

  /// 1-based; 101–105 are the small league's top 5 in a season event.
  final int place;
}

/// One event of the annual rating: an external tournament, series or
/// marathon entered by an admin, an imported season block, or a club season
/// derived by the export.
class AnnualEvent {
  const AnnualEvent({
    required this.id,
    required this.year,
    required this.kind,
    required this.name,
    this.date,
    this.stars,
    this.participants,
    required this.results,
  });

  final String id;
  final int year;
  final AnnualKind kind;
  final String name;

  /// `YYYY-MM-DD`, or null when unknown.
  final String? date;

  /// Tournament only.
  final int? stars;
  final int? participants;
  final List<AnnualResult> results;

  /// Throws [FormatException] naming [id] on a field the export can't use.
  factory AnnualEvent.fromJson(Map<String, dynamic> json, {required String id}) {
    Never bad(String what) => throw FormatException('event $id: $what');
    final year = json['year'];
    if (year is! int || year < 2000 || year > 2100) bad('year');
    final AnnualKind kind;
    try {
      kind = AnnualKind.parse('${json['kind']}');
    } on FormatException {
      bad('kind');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) bad('name');
    final date = json['date'];
    if (date != null && date is! String) bad('date');
    final stars = json['stars'];
    final participants = json['participants'];
    if (kind == AnnualKind.tournament) {
      if (stars is! int || stars < 0 || stars > 5) bad('stars');
      if (participants is! int || participants < 1) bad('participants');
    }
    final raw = json['results'];
    if (raw is! List) bad('results');
    final results = <AnnualResult>[];
    for (final (i, r) in raw.indexed) {
      if (r is! Map || r['player'] is! String || (r['player'] as String).trim().isEmpty ||
          r['place'] is! int || (r['place'] as int) < 1) {
        bad('result #$i');
      }
      results.add(AnnualResult((r['player'] as String).trim(), r['place'] as int));
    }
    return AnnualEvent(
      id: id,
      year: year,
      kind: kind,
      name: name.trim(),
      date: date as String?,
      stars: kind == AnnualKind.tournament ? stars as int : null,
      participants: kind == AnnualKind.tournament ? participants as int : null,
      results: results,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'year': year,
        'kind': kind.name,
        'name': name,
        'date': date,
        'stars': stars,
        'participants': participants,
        'results': [for (final r in results) {'player': r.player, 'place': r.place}],
      };
}

/// The prefetch snapshot: a JSON list of events, each with its document `id`.
List<AnnualEvent> parseAnnualEvents(String json) {
  final list = jsonDecode(json);
  if (list is! List) throw const FormatException('annual events: not a list');
  return [
    for (final (i, e) in list.indexed)
      if (e is Map<String, dynamic> && e['id'] is String)
        AnnualEvent.fromJson(e, id: e['id'] as String)
      else
        throw FormatException('annual events: entry #$i has no id'),
  ];
}
```

- [ ] **Step 4: Implement `lib/services/stats/annual_rating.dart`**

```dart
// Pure Dart: the annual rating as the sheet's «Річний рейтинг» tab computes it.
import 'package:family_mafia_app/models/annual_event.dart';

export 'package:family_mafia_app/models/annual_event.dart';

/// Points for one result, as the «Турніри» tab's «Бали» column.
double eventPoints(AnnualKind kind, int place, {int? stars, int? participants}) {
  switch (kind) {
    case AnnualKind.season:
      const fixed = {1: 18, 2: 15, 3: 12, 4: 9, 5: 6, 101: 5, 102: 4, 103: 3, 104: 2, 105: 1};
      return (fixed[place] ?? (place > 10 ? 2 : place > 5 ? 4 : 0)).toDouble();
    case AnnualKind.series:
      const fixed = {1: 10, 2: 8, 3: 6, 4: 4, 5: 3, 6: 2, 7: 2};
      return (fixed[place] ?? 1).toDouble();
    case AnnualKind.marathon:
      const fixed = {1: 6, 2: 4, 3: 3, 4: 2, 5: 2};
      return (fixed[place] ?? 1).toDouble();
    case AnnualKind.tournament:
      final b = 1 + (stars ?? 0) / 3;
      final n = participants ?? 0;
      if (place < 1) return 0;
      if (place < 11) return b + (n - place) * b / 4;
      if (place < n / 2) return b + (n - place) * b / 5;
      return b + (n - place) * b / 10;
  }
}

class AnnualEntry {
  AnnualEntry(this.event, this.place, this.points);

  final AnnualEvent event;
  final int place;
  final double points;

  /// One of the player's 12 best results, the ones the score sums.
  bool counted = false;
}

class AnnualStanding {
  AnnualStanding(this.key, this.name, this.entries)
      : score = _score(entries),
        wins = entries.where((e) => e.place == 1).length,
        top3 = entries.where((e) => e.place < 4).length,
        top10 = entries.where((e) => e.place < 11).length,
        participations = entries.where((e) => e.place > 0).length;

  final String key;
  final String name;

  /// Best points first.
  final List<AnnualEntry> entries;
  final double score;
  final int wins, top3, top10, participations;
  int rank = 0;

  static double _score(List<AnnualEntry> entries) {
    var sum = 0.0;
    for (final e in entries.take(kAnnualCountedEvents)) {
      e.counted = true;
      sum += e.points;
    }
    return (sum * 100).round() / 100;
  }
}

/// How many of a player's best results the annual score sums.
const kAnnualCountedEvents = 12;

/// Standings for [events] (one year), grouped by [keyOf] of each result's
/// name; [nameOf] gives the shown name (default: the first name seen).
List<AnnualStanding> annualStandings(Iterable<AnnualEvent> events,
    {required String Function(String player) keyOf, String Function(String player)? nameOf}) {
  final byKey = <String, (String, List<AnnualEntry>)>{};
  for (final e in events) {
    for (final r in e.results) {
      final key = keyOf(r.player);
      final slot = byKey[key] ??= (nameOf?.call(r.player) ?? r.player, []);
      slot.$2.add(AnnualEntry(e, r.place,
          eventPoints(e.kind, r.place, stars: e.stars, participants: e.participants)));
    }
  }
  final out = [
    for (final MapEntry(key: k, value: (name, entries)) in byKey.entries)
      AnnualStanding(k, name, entries..sort((a, b) => b.points.compareTo(a.points)))
  ]..sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  for (var i = 0; i < out.length; i++) {
    out[i].rank = i > 0 && out[i].score == out[i - 1].score ? out[i - 1].rank : i + 1;
  }
  return out;
}

/// The year of a season's last month: the quarter of its median game
/// (as `seasonInProgress`); a December quarter ends in the next year.
int seasonYear(List<DateTime> gameDates) {
  final sorted = [...gameDates]..sort();
  final median = sorted[sorted.length ~/ 2];
  return median.month == 12 ? median.year + 1 : median.year;
}
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/services/stats/annual_rating_test.dart`
Expected: PASS (7 tests). If a totals test fails, print the differing keys; a difference only in names that appear twice in one sheet table is a sheet quirk → ledger a ruling and compare that name's score manually, never loosen the whole comparison.

- [ ] **Step 6: Commit**

```bash
git add lib/models/annual_event.dart lib/services/stats/annual_rating.dart test/services/stats/annual_rating_test.dart
git commit -m "feat: annual rating points and standings in pure Dart"
```

---

### Task 3: Prefetch the `events` collection

**Files:**
- Modify: `lib/services/prefetch_paths.dart`
- Modify: `lib/services/firestore_service.dart`
- Modify: `tool/prefetch_seasons.dart`
- Test: `test/tool/prefetch_seasons_test.dart`, `test/services/firestore_service_annual_test.dart`

**Interfaces:**
- Consumes: `parseAnnualEvents`, `AnnualEvent.toJson` (Task 2).
- Produces: `const String prefetchedAnnualEventsFile = 'annual_events.json';` and `Future<String> FirestoreService.fetchAnnualEvents(String projectId)` — JSON list of events with `id` and only the event fields (no `updatedBy*`), all pages.

- [ ] **Step 1: Write the failing tests**

`test/services/firestore_service_annual_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.respond);
  final ResponseBody Function(Uri uri) respond;
  final seen = <Uri>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o.uri);
    return respond(o.uri);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

Map<String, dynamic> _doc(String id, String name) => {
      'name': 'projects/p/databases/(default)/documents/events/$id',
      'fields': {
        'year': {'integerValue': '2026'},
        'kind': {'stringValue': 'series'},
        'name': {'stringValue': name},
        'date': {'nullValue': null},
        'results': {'arrayValue': {'values': [
          {'mapValue': {'fields': {'player': {'stringValue': 'A'}, 'place': {'integerValue': '1'}}}}
        ]}},
        'updatedByEmail': {'stringValue': 'admin@x.com'},
      },
    };

void main() {
  test('reads every page and keeps only event fields', () async {
    final fake = _Fake((uri) => uri.queryParameters['pageToken'] == null
        ? _json({'documents': [_doc('a1', 'One')], 'nextPageToken': 't2'})
        : _json({'documents': [_doc('b2', 'Two')]}));
    final json = await FirestoreService(dio: Dio()..httpClientAdapter = fake).fetchAnnualEvents('p');
    final list = jsonDecode(json) as List;
    expect(list.map((e) => e['id']), ['a1', 'b2']);
    expect((list.first as Map).containsKey('updatedByEmail'), isFalse);
    expect(list.first['results'], [{'player': 'A', 'place': 1}]);
    expect(fake.seen.length, 2);
  });

  test('an empty collection is an empty list', () async {
    final fake = _Fake((_) => _json({}));
    expect(await FirestoreService(dio: Dio()..httpClientAdapter = fake).fetchAnnualEvents('p'), '[]');
  });
}
```

In `test/tool/prefetch_seasons_test.dart`, change `_dio` to route the events listing, and add two tests:

```dart
Dio _dio({bool failSheetB = false, Object? events}) => Dio()
  ..httpClientAdapter = _FakeAdapter((uri) {
    if (uri.host == 'config.test') return _body(_config);
    if (uri.path.endsWith('/documents/events')) return _body(jsonEncode(events ?? {}));
    // … the existing sheetA / sheetB / 404 branches unchanged …
  });
```

```dart
  test('writes the annual events, [] when the collection is empty', () async {
    await prefetch.prefetchSeasons(dio: _dio(), apiKey: 'k', configUrl: _configUrl, outDir: out);
    expect(File('${out.path}/annual_events.json').readAsStringSync(), '[]');
  });

  test('a malformed event fails the prefetch with its id and writes nothing', () async {
    final bad = {'documents': [{
      'name': 'projects/p/databases/(default)/documents/events/doc7',
      'fields': {'year': {'integerValue': '2026'}, 'kind': {'stringValue': 'cup'},
                 'name': {'stringValue': 'X'}, 'results': {'arrayValue': {}}},
    }]};
    await expectLater(
      prefetch.prefetchSeasons(dio: _dio(events: bad), apiKey: 'k', configUrl: _configUrl, outDir: out),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('doc7'))),
    );
    expect(out.listSync(), isEmpty);
  });
```

(The existing `config/club` route returns 404 → null, and the config has `"tournaments": []`, so those tests keep passing.)

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/services/firestore_service_annual_test.dart test/tool/prefetch_seasons_test.dart`
Expected: FAIL — `fetchAnnualEvents` is not defined; `annual_events.json` missing.

- [ ] **Step 3: Implement**

`lib/services/prefetch_paths.dart` — add:

```dart
/// Firestore `events` (the annual rating's tournaments, series, marathons).
const String prefetchedAnnualEventsFile = 'annual_events.json';
```

`lib/services/firestore_service.dart` — add the import `import 'package:family_mafia_app/models/annual_event.dart';` and the method:

```dart
  /// Every `events` document as a JSON list of `{id, year, kind, …}` — only
  /// the event fields, never who saved it. Throws [FormatException] naming
  /// the document when one is malformed, so the build fails loudly.
  Future<String> fetchAnnualEvents(String projectId) async {
    final events = <Map<String, Object?>>[];
    String? token;
    do {
      final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
              '$projectId/databases/(default)/documents/events')
          .replace(queryParameters: {'pageSize': '300', if (token != null) 'pageToken': token});
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      for (final d in (response.data?['documents'] as List?) ?? const []) {
        final doc = d as Map<String, dynamic>;
        final id = (doc['name'] as String).split('/').last;
        final fields = decodeFirestoreFields(doc['fields'] as Map<String, dynamic>? ?? const {});
        events.add(AnnualEvent.fromJson(fields, id: id).toJson());
      }
      token = response.data?['nextPageToken'] as String?;
    } while (token != null);
    return jsonEncode(events);
  }
```

`tool/prefetch_seasons.dart` — after the club config block, before `await outDir.create(...)`:

```dart
  // Validated per document inside fetchAnnualEvents.
  final annualEvents = await firestore.fetchAnnualEvents(kFirebaseProjectId);
```

and after writing the club config:

```dart
  await File('${outDir.path}/$prefetchedAnnualEventsFile').writeAsString(annualEvents);
```

Also extend the header comment: `// Snapshots the remote config, Firestore config/club and events, and every …`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/services/firestore_service_annual_test.dart test/tool/`
Expected: PASS, including `prefetch_pure_dart_test.dart` (the new imports are pure Dart).

- [ ] **Step 5: Commit**

```bash
git add lib/services/prefetch_paths.dart lib/services/firestore_service.dart tool/prefetch_seasons.dart test/tool/prefetch_seasons_test.dart test/services/firestore_service_annual_test.dart
git commit -m "feat: prefetch snapshots the annual-rating events"
```

---

### Task 4: Firestore rules for `events`

**Files:**
- Modify: `firestore.rules` (before `match /meta/state`)
- Test: `firebase/rules-test/rules.test.ts`

- [ ] **Step 1: Write the failing tests** (append to `rules.test.ts`; add `collection, addDoc` to the `firebase/firestore` import)

```ts
describe('events', () => {
  const body = (who: User, extra: Record<string, unknown> = {}) => ({
    year: 2026, kind: 'tournament', name: 'Cup', date: '2026-02-28', stars: 2, participants: 30,
    results: [{ player: 'A', place: 1 }],
    updatedAt: serverTimestamp(), updatedBy: who.uid, updatedByEmail: who.email, ...extra,
  });
  const ev = (db: ReturnType<typeof as>, id = 'E1') => doc(db, 'events', id);

  it('anyone reads', async () => {
    await assertSucceeds(getDoc(ev(env.unauthenticatedContext().firestore())));
  });
  it('admin creates, updates and deletes', async () => {
    await assertSucceeds(setDoc(ev(as(ADMIN)), body(ADMIN)));
    await assertSucceeds(setDoc(ev(as(ADMIN)), body(ADMIN, { kind: 'series', stars: null, participants: null, date: null })));
    await assertSucceeds(deleteDoc(ev(as(ADMIN))));
  });
  it('a season event without optional fields is fine', async () => {
    const { date, stars, participants, ...rest } = body(ADMIN, { kind: 'season' });
    await assertSucceeds(setDoc(ev(as(ADMIN)), rest));
  });
  it('a host who is not an admin, a stranger and anonymous cannot', async () => {
    await assertFails(setDoc(ev(as(HOST)), body(HOST)));
    await assertFails(setDoc(ev(as(STRANGER)), body(STRANGER)));
    await assertFails(setDoc(ev(env.unauthenticatedContext().firestore()), body(ADMIN)));
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'events', 'E2'), { year: 2026 }));
    await assertFails(deleteDoc(ev(as(HOST), 'E2')));
  });
  it('bad fields or a forged author are denied', async () => {
    for (const extra of [
      { kind: 'cup' }, { year: '2026' }, { name: '' }, { results: 'x' }, { stars: '2' },
      { participants: 1.5 }, { date: 5 }, { extra: 1 }, { updatedBy: HOST.uid }, { updatedByEmail: HOST.email },
    ]) await assertFails(setDoc(ev(as(ADMIN)), body(ADMIN, extra)));
  });
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test`
Expected: FAIL — admin writes to `events` denied (no rule).

- [ ] **Step 3: Add the rule** (before `match /meta/state`)

```
    function optInt(d, k) { return !(k in d) || d[k] == null || d[k] is int; }
    match /events/{id} {
      allow read: if true;
      allow create, update: if isAdmin()
        && request.resource.data.keys().hasOnly(['year', 'kind', 'name', 'date', 'stars', 'participants', 'results', 'updatedAt', 'updatedBy', 'updatedByEmail'])
        && request.resource.data.year is int
        && request.resource.data.kind in ['tournament', 'series', 'marathon', 'season']
        && request.resource.data.name is string && request.resource.data.name.size() > 0 && request.resource.data.name.size() <= 200
        && request.resource.data.results is list && request.resource.data.results.size() <= 300
        && (!('date' in request.resource.data) || request.resource.data.date == null || request.resource.data.date is string)
        && optInt(request.resource.data, 'stars') && optInt(request.resource.data, 'participants')
        && request.resource.data.updatedAt == request.time
        && request.resource.data.updatedBy == request.auth.uid
        && request.resource.data.updatedByEmail == email();
      allow delete: if isAdmin();
    }
```

(`optInt` goes next to the other helper functions at the top of the `documents` block.)

- [ ] **Step 4: Run the rules tests**

Run: same as Step 2.
Expected: PASS, all previous tests still green.

- [ ] **Step 5: Commit**

```bash
git add firestore.rules firebase/rules-test/rules.test.ts
git commit -m "feat(rules): admins write the annual-rating events"
```

---

### Task 5: Site export — derived seasons and `annual.json`

**Files:**
- Create: `lib/site_export/annual_export.dart`
- Modify: `lib/site_export/site_exporter.dart`
- Modify: `tool/export_site_data_test.dart`
- Test: `test/site_export/annual_export_test.dart`

**Interfaces:**
- Consumes: `annualStandings`, `seasonYear`, `AnnualEvent`, `parseAnnualEvents` (Task 2); `prefetchedDir`, `prefetchedAnnualEventsFile` (Task 3).
- Produces:
  - `List<AnnualEvent> derivedSeasonEvents(ExportContext x, {int fromSeasonId = kFirstDerivedSeason})` with `const kFirstDerivedSeason = 28;` — event id `season-<id>`, name = season title, kind season, `date: null`.
  - `Map<String, Object?> annualJson(ExportContext x, List<AnnualEvent> stored)` → `{years: [{year, standings: [...], events: [...]}]}`, newest year first (shape below).
  - `writeSiteData(..., {List<AnnualEvent> annualEvents = const []})`.

`annual.json` shape:

```
{ "years": [ { "year": 2026,
    "standings": [ { "rank": 1, "player": SiteCell, "score": "132.13", "wins": 2, "top3": 4, "top10": 12, "events": 13,
                     "entries": [ { "event": "<id>", "place": 1, "points": "18.00", "counted": true } ] } ],
    "events": [ { "id": "<id>", "kind": "series", "label": "Series", "name": "...", "date": "2026-02-15" | null,
                  "stars": 3 | null, "participants": 10 | null,
                  "results": [ { "player": SiteCell, "place": 1, "points": "10.00" } ] } ] } ] }
```

Events sorted by date descending (undated last, then by name); results by place. Points strings use 2 decimals (`toStringAsFixed(2)`).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:family_mafia_app/models/annual_event.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/site_export/annual_export.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('derived season events: league order, small top 5 as 101+, year from dates', () async {
    final x = ExportContext(await fixtureContainer(seasonIds: [17, 21]));
    final events = derivedSeasonEvents(x, fromSeasonId: 0);
    expect(events.map((e) => e.id), ['season-17', 'season-21']);
    expect(events.map((e) => e.year), [2023, 2024]);
    final s21 = events.last;
    x.select(x.seasons.firstWhere((s) => s.id == 21), League.main);
    final main = x.read(currentSeasonStatsProvider)!.playerStats;
    expect(s21.results.where((r) => r.place < 100).map((r) => r.player),
        main.map((p) => p.player.displayName));
    final small = s21.results.where((r) => r.place > 100).toList();
    expect(small.map((r) => r.place), [101, 102, 103, 104, 105].take(small.length));
    expect(derivedSeasonEvents(x), isEmpty, reason: 'only seasons from 28 by default');
  });

  test('a season still in progress gives no event', () async {
    final c = await fixtureContainer(seasonIds: [21]);
    c.updateOverrides([clockProvider.overrideWithValue(() => DateTime.utc(2024, 4, 1))]);
    expect(derivedSeasonEvents(ExportContext(c), fromSeasonId: 0), isEmpty);
  });

  test('annualJson groups nicknames, links players, newest year first', () async {
    final x = ExportContext(await fixtureContainer(seasonIds: [21]));
    final someone = x.players.first;
    final stored = [
      AnnualEvent(id: 'a', year: 2024, kind: AnnualKind.series, name: 'Cup', date: '2024-03-01',
          results: [AnnualResult(someone.displayName.toUpperCase(), 1), const AnnualResult('Guest', 2)]),
      AnnualEvent(id: 'b', year: 2025, kind: AnnualKind.marathon, name: 'M', results: [AnnualResult(someone.displayName, 1)]),
    ];
    final json = annualJson(x, stored);
    final years = json['years'] as List;
    expect(years.map((y) => (y as Map)['year']), [2025, 2024]);
    final y2024 = years.last as Map;
    final standings = y2024['standings'] as List;
    final top = standings.first as Map;
    expect((top['player'] as Map)['link'], x.slugs[someone.id]);
    expect(top['score'], '10.00');
    final guest = standings.firstWhere((s) => ((s as Map)['player'] as Map)['t'] == 'Guest') as Map;
    expect((guest['player'] as Map).containsKey('link'), isFalse);
    expect((y2024['events'] as List).map((e) => (e as Map)['id']), ['a']);
  });

  test('no stored events still builds', () async {
    final x = ExportContext(await fixtureContainer(seasonIds: [21]));
    expect(annualJson(x, const []), {'years': []});
  });
}
```

Note: `fixtureContainer` overrides no clock; `clockProvider` defaults to `DateTime.now` and S17/S21 are finished. If `updateOverrides` cannot add a provider that was not overridden at creation, add an optional `DateTime Function()? clock` parameter to `fixtureContainer` that overrides `clockProvider` (ledger the ruling).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/site_export/annual_export_test.dart`
Expected: FAIL — `annual_export.dart` not found.

- [ ] **Step 3: Implement `lib/site_export/annual_export.dart`**

```dart
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/stats/annual_rating.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Club seasons from this one on feed the annual rating automatically; the
/// earlier years' season blocks were imported from the sheets.
const kFirstDerivedSeason = 28;

/// A «Сезон» event per finished club season: main league ranks 1…N, the
/// small league's top 5 as places 101–105, in the year the season ends.
List<AnnualEvent> derivedSeasonEvents(ExportContext x,
    {int fromSeasonId = kFirstDerivedSeason}) {
  final live = x.read(seasonsInProgressProvider);
  final dates = <int, List<DateTime>>{};
  for (final g in x.read(gamesRepositoryProvider)) {
    if (g.date != null) (dates[g.seasonId] ??= []).add(g.date!);
  }
  final out = <AnnualEvent>[];
  for (final s in x.seasons) {
    if (s.id < fromSeasonId || live.contains(s.id) || dates[s.id] == null) continue;
    List<Player> ranked(League league) {
      x.select(s, league);
      return [for (final p in x.read(currentSeasonStatsProvider)?.playerStats ?? const []) p.player];
    }

    final main = ranked(League.main);
    final small = ranked(League.small).take(5).toList();
    out.add(AnnualEvent(
      id: 'season-${s.id}',
      year: seasonYear(dates[s.id]!),
      kind: AnnualKind.season,
      name: s.title,
      results: [
        for (final (i, p) in main.indexed) AnnualResult(p.displayName, i + 1),
        for (final (i, p) in small.indexed) AnnualResult(p.displayName, 101 + i),
      ],
    ));
  }
  return out;
}

/// The Annual pages: per year, the standings and the events behind them.
Map<String, Object?> annualJson(ExportContext x, List<AnnualEvent> stored) {
  final resolver = x.read(playerResolverProvider);
  final events = [...stored, ...derivedSeasonEvents(x)];
  final years = {for (final e in events) e.year}.toList()..sort((a, b) => b.compareTo(a));
  String pts(double v) => v.toStringAsFixed(2);
  SiteCell cell(String raw) {
    final p = resolver.resolve(raw);
    return x.slugs[p.id] == null ? SiteCell(raw) : x.name(p);
  }

  return {
    'years': [
      for (final year in years)
        () {
          final ofYear = events.where((e) => e.year == year).toList()
            ..sort((a, b) {
              if (a.date == null || b.date == null) {
                if (a.date != b.date) return a.date == null ? 1 : -1;
                return a.name.compareTo(b.name);
              }
              final c = b.date!.compareTo(a.date!);
              return c != 0 ? c : a.name.compareTo(b.name);
            });
          final standings = annualStandings(ofYear,
              keyOf: (n) => personKey(resolver.resolve(n)),
              nameOf: (n) => resolver.resolve(n).displayName);
          return {
            'year': year,
            'standings': [
              for (final s in standings)
                {
                  'rank': s.rank,
                  'player': cell(s.name).toJson(),
                  'score': pts(s.score),
                  'wins': s.wins,
                  'top3': s.top3,
                  'top10': s.top10,
                  'events': s.participations,
                  'entries': [
                    for (final e in s.entries)
                      {'event': e.event.id, 'place': e.place, 'points': pts(e.points), 'counted': e.counted}
                  ],
                }
            ],
            'events': [
              for (final e in ofYear)
                {
                  'id': e.id,
                  'kind': e.kind.name,
                  'label': e.kind.label,
                  'name': e.name,
                  'date': e.date,
                  'stars': e.stars,
                  'participants': e.participants,
                  'results': [
                    for (final r in [...e.results]..sort((a, b) => a.place.compareTo(b.place)))
                      {
                        'player': cell(r.player).toJson(),
                        'place': r.place,
                        'points': pts(eventPoints(e.kind, r.place, stars: e.stars, participants: e.participants)),
                      }
                  ],
                }
            ],
          };
        }(),
    ],
  };
}
```

- [ ] **Step 4: Wire it into the export**

`lib/site_export/site_exporter.dart`: add imports `package:family_mafia_app/models/annual_event.dart` and `package:family_mafia_app/site_export/annual_export.dart`; change the signature to

```dart
Future<void> writeSiteData(ProviderContainer container, Directory out,
    {Future<String?> Function(SeasonConfig)? seasonJson,
    List<AnnualEvent> annualEvents = const []}) async {
```

and after `write('tournaments.json', tournamentsJson(x));` add `write('annual.json', annualJson(x, annualEvents));`.

`tool/export_site_data_test.dart`: add imports `package:family_mafia_app/models/annual_event.dart` and `package:family_mafia_app/services/prefetch_paths.dart`, and before `writeSiteData`:

```dart
    // CI's prefetch always writes it; a local run without a snapshot shows
    // the derived season events only.
    final annualFile = File('$prefetchedDir/$prefetchedAnnualEventsFile');
    final annualEvents = annualFile.existsSync()
        ? parseAnnualEvents(annualFile.readAsStringSync())
        : <AnnualEvent>[];
    await writeSiteData(container, out, annualEvents: annualEvents);
```

(replacing the old `await writeSiteData(container, out);`).

- [ ] **Step 5: Run the tests**

Run: `flutter test test/site_export/`
Expected: PASS.

- [ ] **Step 6: Run a real export with the import file as the snapshot and check 2026**

Run: `cp tool/import/annual_events.json assets/prefetched/annual_events.json && python -c "import json;e=json.load(open('assets/prefetched/annual_events.json',encoding='utf-8'));[x.__setitem__('id','imp%d'%i) for i,x in enumerate(e)];json.dump(e,open('assets/prefetched/annual_events.json','w',encoding='utf-8'),ensure_ascii=False)" && flutter test tool/export_site_data_test.dart && python -c "import json;d=json.load(open('site/data/annual.json',encoding='utf-8'));y=d['years'][0];print(y['year'],[(s['player']['t'],s['score']) for s in y['standings'][:5]])"`
Expected: `2026 [('Seezov', '132.13'), ('Пустой', '93.08'), ('Залізний', '91.43'), ('Сирник', '81.07'), ('Малишка', '68.00')]` — the sheet's 2026 top 5. Then `rm assets/prefetched/annual_events.json` (CI writes the real one).

- [ ] **Step 7: Commit**

```bash
git add lib/site_export/annual_export.dart lib/site_export/site_exporter.dart tool/export_site_data_test.dart test/site_export/annual_export_test.dart
git commit -m "feat(site): export the annual rating with derived club seasons"
```

---

### Task 6: `/annual/` pages

**Files:**
- Modify: `site/src/lib/types.ts`, `site/src/lib/data.ts`, `site/src/layouts/Base.astro`
- Create: `site/src/components/AnnualPage.astro`, `site/src/pages/annual/index.astro`, `site/src/pages/annual/[year].astro`

**Interfaces:**
- Consumes: `site/data/annual.json` (Task 5 shape).
- Produces: `AnnualData` type, `loadAnnual()`, pages `/annual/` (newest year) and `/annual/<year>/` (every other year).

- [ ] **Step 1: Types and loader**

`site/src/lib/types.ts` — append:

```ts
export interface AnnualStanding {
  rank: number; player: SiteCell; score: string; wins: number; top3: number; top10: number; events: number;
  entries: { event: string; place: number; points: string; counted: boolean }[];
}
export interface AnnualEvent {
  id: string; kind: 'tournament' | 'series' | 'marathon' | 'season'; label: string; name: string;
  date: string | null; stars: number | null; participants: number | null;
  results: { player: SiteCell; place: number; points: string }[];
}
export interface AnnualYear { year: number; standings: AnnualStanding[]; events: AnnualEvent[] }
export interface AnnualData { years: AnnualYear[] }
```

`site/src/lib/data.ts` — add `AnnualData` to the type import and `export const loadAnnual = () => read<AnnualData>('annual.json');`.

`site/src/layouts/Base.astro` — add `'annual'` to the `active` union and the nav entry after Tournaments:
`{ key: 'annual', label: 'Annual', url: href('annual/') },`

- [ ] **Step 2: `site/src/components/AnnualPage.astro`**

```astro
---
// One year of the annual rating: standings (rows expand into the player's
// events) and the year's events with full results.
import Base from '../layouts/Base.astro';
import Panel from './Panel.astro';
import PlayerName from './PlayerName.astro';
import { href } from '../lib/url';
import type { AnnualData, AnnualYear } from '../lib/types';
import type { SiteCell } from '../lib/types';

interface Props { data: AnnualData; y: AnnualYear }
const { data, y } = Astro.props;
const newest = data.years[0]?.year;
const yearHref = (year: number) => href(year === newest ? 'annual/' : `annual/${year}/`);
const byId = new Map(y.events.map((e) => [e.id, e]));
const place = (p: number) => (p > 100 ? `S${p - 100}` : String(p));
const placeTip = (p: number) => (p > 100 ? `Small league #${p - 100}` : undefined);
---
<Base title={`Annual rating ${y.year}`} description={`Family Mafia Club annual rating ${y.year}: tournaments, series, marathons and club seasons.`} active="annual">
  <div class="pagehead">
    <h1 class="display">Annual rating {y.year}</h1>
    <nav class="years" aria-label="Year">
      {data.years.map((o) => <a href={yearHref(o.year)} aria-current={o.year === y.year ? 'page' : undefined}>{o.year}</a>)}
    </nav>
  </div>
  <p class="hint">Sum of each player's 12 best results: club seasons, external tournaments, series and marathons.</p>

  <div class="grid">
    <Panel title="Standings" class="span-12">
      <div class="standings" role="table">
        <div class="row head" role="row">
          <span>#</span><span>Player</span><span class="num">Score</span><span class="num">Wins</span>
          <span class="num">Top-3</span><span class="num">Top-10</span><span class="num">Events</span>
        </div>
        {y.standings.map((s) => (
          <details class="st">
            <summary class="row" role="row">
              <span class="num">{s.rank}</span>
              <span>{s.player.link ? <PlayerName slug={s.player.link} name={s.player.t} /> : s.player.t}</span>
              <span class="num strong">{s.score}</span><span class="num">{s.wins}</span>
              <span class="num">{s.top3}</span><span class="num">{s.top10}</span><span class="num">{s.events}</span>
            </summary>
            <ol class="entries">
              {s.entries.map((e) => {
                const ev = byId.get(e.event);
                return (
                  <li class={e.counted ? 'counted' : 'dropped'}>
                    <span class={`kind k-${ev?.kind}`}>{ev?.label}</span>
                    <span class="name">{ev?.name}</span>
                    <span class="num" title={placeTip(e.place)}>#{place(e.place)}</span>
                    <span class="num">{e.points}</span>
                  </li>
                );
              })}
            </ol>
          </details>
        ))}
      </div>
    </Panel>

    <Panel title="Events" note={`${y.events.length} events`} class="span-12">
      <div class="events">
        {y.events.map((e) => (
          <details class="ev">
            <summary>
              <span class={`kind k-${e.kind}`}>{e.label}</span>
              <span class="name">{e.name}</span>
              <span class="meta num">{e.date ?? 'date unknown'}{e.kind === 'tournament' && ` · ${e.stars}★ · ${e.participants} players`}</span>
            </summary>
            <ol class="results">
              {e.results.map((r) => (
                <li>
                  <span class="num" title={placeTip(r.place)}>#{place(r.place)}</span>
                  <span>{r.player.link ? <PlayerName slug={r.player.link} name={r.player.t} /> : r.player.t}</span>
                  <span class="num">{r.points}</span>
                </li>
              ))}
            </ol>
          </details>
        ))}
      </div>
    </Panel>
  </div>
</Base>

<style>
  .years { display: flex; gap: 8px; flex-wrap: wrap; }
  .years a { padding: 2px 10px; border: 1px solid var(--line); border-radius: 999px; }
  .years a[aria-current='page'] { background: var(--ink); color: var(--bg); }
  .standings .row { display: grid; grid-template-columns: 2.5em 1fr repeat(5, 4.2em); gap: 6px; align-items: center; padding: 6px 4px; }
  .standings .head { color: var(--muted); font-size: 0.85em; }
  .st summary { cursor: pointer; list-style: none; border-top: 1px solid var(--line); }
  .st summary::-webkit-details-marker { display: none; }
  .entries, .results { list-style: none; margin: 0 0 8px; padding: 0 0 0 2.5em; }
  .entries li, .results li { display: grid; grid-template-columns: 6em 1fr 4em 4.5em; gap: 6px; padding: 2px 0; }
  .results li { grid-template-columns: 4em 1fr 4.5em; }
  .entries .dropped { opacity: 0.45; }
  .ev summary { display: flex; flex-wrap: wrap; gap: 6px 12px; cursor: pointer; padding: 6px 0; border-top: 1px solid var(--line); }
  .kind { font-size: 0.8em; text-transform: uppercase; letter-spacing: 0.04em; color: var(--muted); }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
  .strong { font-weight: 600; }
  @media (max-width: 640px) {
    .standings .row { grid-template-columns: 2em 1fr 4.2em 3em; }
    .standings .row > :nth-child(n + 5) { display: none; }
    .entries li { grid-template-columns: 1fr 3em 4em; }
    .entries .kind { display: none; }
  }
</style>
```

(If `--line`, `--muted`, `--ink`, `--bg` are named differently in `global.css`, use the tokens it defines — check with `grep -n "^\s*--" site/src/styles/global.css` first and ledger the substitution.)

- [ ] **Step 3: Pages**

`site/src/pages/annual/index.astro`:

```astro
---
import AnnualPage from '../../components/AnnualPage.astro';
import Base from '../../layouts/Base.astro';
import { loadAnnual } from '../../lib/data';

const data = loadAnnual();
const y = data.years[0];
---
{y ? <AnnualPage data={data} y={y} /> : (
  <Base title="Annual rating" active="annual"><div class="pagehead"><h1 class="display">Annual rating</h1></div><p>No events yet.</p></Base>
)}
```

`site/src/pages/annual/[year].astro`:

```astro
---
import AnnualPage from '../../components/AnnualPage.astro';
import { loadAnnual } from '../../lib/data';

export function getStaticPaths() {
  const data = loadAnnual();
  return data.years.slice(1).map((y) => ({ params: { year: String(y.year) }, props: { data, y } }));
}
const { data, y } = Astro.props;
---
<AnnualPage data={data} y={y} />
```

- [ ] **Step 4: Build and check**

Run: `cd site && npm run check && npm run build`
Expected: `astro check` 0 errors; build passes `check-dist` (links from `/annual/` resolve, including player links and year links). Open `dist/annual/index.html` and confirm the 2026 standings top row is Seezov 132.13 (export from Task 5 Step 6 still in `site/data/`).

- [ ] **Step 5: Commit**

```bash
git add site/src/lib/types.ts site/src/lib/data.ts site/src/layouts/Base.astro site/src/components/AnnualPage.astro site/src/pages/annual
git commit -m "feat(site): annual rating pages"
```

---

### Task 7: `/annual/edit/` admin page

**Files:**
- Create: `site/src/lib/annual/points.ts`, `site/src/lib/annual/points.test.ts`
- Create: `site/src/lib/annual/validate.ts`, `site/src/lib/annual/validate.test.ts`
- Create: `site/src/lib/annual/store.ts`
- Create: `site/src/pages/annual/edit.astro`, `site/src/scripts/annual-edit.ts`

**Interfaces:**
- Consumes: `test/fixtures/annual_points_cases.json` (Task 1), rules (Task 4), `onClubUser`, `signIn`, `signOutUser`, `ClubAdmin` from `site/src/lib/club/store.ts`.
- Produces:
  - `type EventKind = 'tournament' | 'series' | 'marathon' | 'season'`; `eventPoints(kind, place, stars?, participants?): number`.
  - `interface EventDraft { year: number; kind: EventKind; name: string; date: string | null; stars: number | null; participants: number | null; results: { player: string; place: number }[] }`; `validateEvent(d: EventDraft): string[]` (empty = valid).
  - `loadEvents(year): Promise<{ id: string; data: EventDraft }[]>`, `saveEvent(id | null, d, u)`, `deleteEvent(id, u)`, `eventsEmpty(): Promise<boolean>`, `importEvents(list: EventDraft[], u)`.

- [ ] **Step 1: Write the failing TS tests**

`site/src/lib/annual/points.test.ts`:

```ts
import fs from 'node:fs';
import { describe, expect, it } from 'vitest';
import { eventPoints, type EventKind } from './points';

const cases = JSON.parse(fs.readFileSync(new URL('../../../../test/fixtures/annual_points_cases.json', import.meta.url), 'utf8')) as
  { kind: EventKind; place: number; stars: number | null; participants: number | null; points: number }[];

describe('eventPoints', () => {
  it('matches every sheet case (same fixture as the Dart test)', () => {
    expect(cases.length).toBeGreaterThan(0);
    for (const c of cases) expect(eventPoints(c.kind, c.place, c.stars, c.participants)).toBeCloseTo(c.points, 9);
  });
  it('edges', () => {
    expect(eventPoints('season', 101)).toBe(5);
    expect(eventPoints('season', 11)).toBe(2);
    expect(eventPoints('series', 12)).toBe(1);
    expect(eventPoints('tournament', 9, 2, 30)).toBeCloseTo(10.4166666667, 9);
  });
});
```

`site/src/lib/annual/validate.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { validateEvent, type EventDraft } from './validate';

const ok = (): EventDraft => ({
  year: 2026, kind: 'tournament', name: 'Cup', date: '2026-02-28', stars: 2, participants: 30,
  results: [{ player: 'A', place: 1 }, { player: 'B', place: 9 }],
});

describe('validateEvent', () => {
  it('accepts a good event', () => expect(validateEvent(ok())).toEqual([]));
  it('refuses missing name, no rows, bad places, duplicates', () => {
    expect(validateEvent({ ...ok(), name: ' ' })).toContain('Name is required');
    expect(validateEvent({ ...ok(), results: [] })).toContain('Add at least one player');
    expect(validateEvent({ ...ok(), results: [{ player: 'A', place: 0 }] })).toContain('Row 1: place must be a whole number ≥ 1');
    expect(validateEvent({ ...ok(), results: [{ player: '', place: 1 }] })).toContain('Row 1: player is empty');
    expect(validateEvent({ ...ok(), results: [{ player: 'A', place: 1 }, { player: 'a', place: 2 }] })).toContain('A is listed twice');
  });
  it('tournament needs stars 0–5 and participants ≥ the largest place', () => {
    expect(validateEvent({ ...ok(), stars: null })).toContain('Stars must be 0–5');
    expect(validateEvent({ ...ok(), stars: 6 })).toContain('Stars must be 0–5');
    expect(validateEvent({ ...ok(), participants: 5 })).toContain('Participants must be at least 9');
    expect(validateEvent({ ...ok(), kind: 'series', stars: null, participants: null })).toEqual([]);
  });
  it('bad date', () => expect(validateEvent({ ...ok(), date: '28.02.2026' })).toContain('Date must be YYYY-MM-DD'));
});
```

- [ ] **Step 2: Run to verify they fail**

Run: `cd site && npx vitest run src/lib/annual`
Expected: FAIL — modules not found.

- [ ] **Step 3: Implement `points.ts` and `validate.ts`**

`site/src/lib/annual/points.ts`:

```ts
// The annual rating's points per result — a port of lib/services/stats/annual_rating.dart.
// Both are checked against test/fixtures/annual_points_cases.json.
export type EventKind = 'tournament' | 'series' | 'marathon' | 'season';

const SEASON: Record<number, number> = { 1: 18, 2: 15, 3: 12, 4: 9, 5: 6, 101: 5, 102: 4, 103: 3, 104: 2, 105: 1 };
const SERIES: Record<number, number> = { 1: 10, 2: 8, 3: 6, 4: 4, 5: 3, 6: 2, 7: 2 };
const MARATHON: Record<number, number> = { 1: 6, 2: 4, 3: 3, 4: 2, 5: 2 };

export function eventPoints(kind: EventKind, place: number, stars?: number | null, participants?: number | null): number {
  switch (kind) {
    case 'season': return SEASON[place] ?? (place > 10 ? 2 : place > 5 ? 4 : 0);
    case 'series': return SERIES[place] ?? 1;
    case 'marathon': return MARATHON[place] ?? 1;
    case 'tournament': {
      const b = 1 + (stars ?? 0) / 3;
      const n = participants ?? 0;
      if (place < 1) return 0;
      if (place < 11) return b + ((n - place) * b) / 4;
      if (place < n / 2) return b + ((n - place) * b) / 5;
      return b + ((n - place) * b) / 10;
    }
  }
}
```

`site/src/lib/annual/validate.ts`:

```ts
import type { EventKind } from './points';

export interface EventDraft {
  year: number; kind: EventKind; name: string; date: string | null;
  stars: number | null; participants: number | null;
  results: { player: string; place: number }[];
}

/** Problems that keep [d] from being saved; empty when it is fine. */
export function validateEvent(d: EventDraft): string[] {
  const errors: string[] = [];
  if (!d.name.trim()) errors.push('Name is required');
  if (d.date !== null && !/^\d{4}-\d{2}-\d{2}$/.test(d.date)) errors.push('Date must be YYYY-MM-DD');
  if (d.results.length === 0) errors.push('Add at least one player');
  const seen = new Set<string>();
  d.results.forEach((r, i) => {
    if (!r.player.trim()) errors.push(`Row ${i + 1}: player is empty`);
    if (!Number.isInteger(r.place) || r.place < 1) errors.push(`Row ${i + 1}: place must be a whole number ≥ 1`);
    const key = r.player.trim().toLowerCase();
    if (key && seen.has(key)) errors.push(`${r.player.trim()} is listed twice`);
    seen.add(key);
  });
  if (d.kind === 'tournament') {
    if (d.stars === null || !Number.isInteger(d.stars) || d.stars < 0 || d.stars > 5) errors.push('Stars must be 0–5');
    const maxPlace = Math.max(0, ...d.results.map((r) => r.place).filter(Number.isFinite));
    if (d.participants === null || !Number.isInteger(d.participants) || d.participants < Math.max(1, maxPlace)) {
      errors.push(`Participants must be at least ${Math.max(1, maxPlace)}`);
    }
  }
  return errors;
}
```

- [ ] **Step 4: Run the TS tests**

Run: `cd site && npx vitest run src/lib/annual`
Expected: PASS.

- [ ] **Step 5: Firestore client `site/src/lib/annual/store.ts`**

```ts
// Firebase client for /annual/edit/. Access control lives in firestore.rules (events: public read, admin write).
import { collection, doc, getDocs, limit, query, runTransaction, serverTimestamp, where, writeBatch } from 'firebase/firestore';
import { db } from '../firebase';
import type { ClubAdmin } from '../club/store';
import type { EventDraft } from './validate';

const events = () => collection(db, 'events');
const stamp = (u: ClubAdmin) => ({ updatedAt: serverTimestamp(), updatedBy: u.uid, updatedByEmail: u.email });
const body = (d: EventDraft) => ({
  year: d.year, kind: d.kind, name: d.name.trim(), date: d.date,
  stars: d.kind === 'tournament' ? d.stars : null,
  participants: d.kind === 'tournament' ? d.participants : null,
  results: d.results.map((r) => ({ player: r.player.trim(), place: r.place })),
});

export async function loadEvents(year: number): Promise<{ id: string; data: EventDraft }[]> {
  const snap = await getDocs(query(events(), where('year', '==', year)));
  return snap.docs.map((s) => {
    const d = s.data();
    return { id: s.id, data: { year: d.year, kind: d.kind, name: d.name, date: d.date ?? null, stars: d.stars ?? null, participants: d.participants ?? null, results: d.results ?? [] } };
  });
}

export async function eventsEmpty(): Promise<boolean> {
  return (await getDocs(query(events(), limit(1)))).empty;
}

/** Creates (id null) or replaces an event and bumps meta/state so the site rebuilds. */
export async function saveEvent(id: string | null, d: EventDraft, u: ClubAdmin): Promise<string> {
  const ref = id ? doc(db, 'events', id) : doc(events());
  await runTransaction(db, async (tx) => {
    tx.set(ref, { ...body(d), ...stamp(u) });
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
  return ref.id;
}

export async function deleteEvent(id: string, _u: ClubAdmin) {
  await runTransaction(db, async (tx) => {
    tx.delete(doc(db, 'events', id));
    tx.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
  });
}

/** One-time copy of the sheets' events (tool/import/annual_events.json). */
export async function importEvents(list: EventDraft[], u: ClubAdmin) {
  if (!(await eventsEmpty())) throw new Error('events already has documents');
  for (let i = 0; i < list.length; i += 400) {
    const batch = writeBatch(db);
    for (const d of list.slice(i, i + 400)) batch.set(doc(events()), { ...body(d), ...stamp(u) });
    if (i + 400 >= list.length) batch.set(doc(db, 'meta', 'state'), { updatedAt: serverTimestamp() });
    await batch.commit();
  }
}
```

- [ ] **Step 6: Page `site/src/pages/annual/edit.astro`**

```astro
---
import Base from '../../layouts/Base.astro';
import { loadAnnual, loadPlayers } from '../../lib/data';

const years = loadAnnual().years.map((y) => y.year);
const thisYear = new Date().getFullYear();
const options = [...new Set([thisYear, ...years])].sort((a, b) => b - a);
const names = loadPlayers().players.map((p) => p.name);
---
<Base title="Edit annual events" description="Admins add tournaments, series and marathons to the annual rating." active="annual">
  <div class="pagehead"><h1 class="display">Annual events</h1><span class="label" id="state">Loading…</span></div>

  <div class="panel access">
    <span class="label">Editing</span> <span id="who">Read-only</span>
    <button type="button" id="sign-in" class="btn primary">Sign in with Google</button>
    <button type="button" id="sign-out" class="btn" hidden>Sign out</button>
    <button type="button" id="import" class="btn" hidden>Import 2024–2026 from the sheets</button>
    <p class="hint">Admins (hosts with <code>admin: true</code>) can save. Club seasons are added automatically. The site rebuilds within an hour.</p>
  </div>

  <div class="toolbar">
    <label>Year <select id="year">{options.map((y) => <option value={y}>{y}</option>)}</select></label>
    <button type="button" id="add" class="btn" disabled>Add event</button>
  </div>

  <p id="msg" class="msg" role="status"></p>
  <form id="form" class="panel form" hidden></form>
  <div id="list" class="list"></div>

  <datalist id="players">{names.map((n) => <option value={n} />)}</datalist>
  <script type="application/json" id="player-names" set:html={JSON.stringify(names).replace(/</g, '\\u003c')} />
</Base>

<script>
  import '../../scripts/annual-edit';
</script>

<style>
  .access, .toolbar { display: flex; flex-wrap: wrap; gap: 8px 12px; align-items: center; margin-bottom: 12px; }
  .hint { flex-basis: 100%; margin: 0; color: var(--muted); }
  .msg:empty { display: none; }
  .msg.error { color: var(--neg, #c33); }
  .list .ev { display: flex; flex-wrap: wrap; gap: 6px 12px; align-items: baseline; padding: 8px 0; border-top: 1px solid var(--line); }
  .list .ev .name { font-weight: 600; }
  .form { display: grid; gap: 8px; margin-bottom: 16px; }
  .form .fields { display: flex; flex-wrap: wrap; gap: 8px; }
  .form .rows { display: grid; gap: 4px; }
  .form .r { display: grid; grid-template-columns: 1fr 5em 4.5em 2em; gap: 6px; align-items: center; }
  .form .r.guest input[name='player'] { outline: 2px solid var(--warn, #c90); }
  .form .errors { color: var(--neg, #c33); margin: 0; }
  .num { text-align: right; font-variant-numeric: tabular-nums; }
</style>
```

- [ ] **Step 7: Script `site/src/scripts/annual-edit.ts`**

```ts
// /annual/edit/: admins add, edit and delete the annual rating's events in Firestore.
import { onClubUser, signIn, signOutUser, type ClubAdmin } from '../lib/club/store';
import { deleteEvent, eventsEmpty, importEvents, loadEvents, saveEvent } from '../lib/annual/store';
import { eventPoints, type EventKind } from '../lib/annual/points';
import { validateEvent, type EventDraft } from '../lib/annual/validate';

const IMPORT_URL = 'https://raw.githubusercontent.com/Seezov/FamilyMafiaApp/feature/flutter_migration/tool/import/annual_events.json';
const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const names = new Set((JSON.parse($('player-names').textContent!) as string[]).map((n) => n.toLowerCase()));
const esc = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]!);
const LABEL: Record<EventKind, string> = { tournament: 'Tournament', series: 'Series', marathon: 'Marathon', season: 'Season' };

let user: ClubAdmin | null | 'not-host' = null;
let events: { id: string; data: EventDraft }[] = [];
let editing: { id: string | null; draft: EventDraft } | null = null;
let confirmDelete: string | null = null;
let busy = false;
const canSave = () => typeof user === 'object' && user !== null && user.admin;
const year = () => Number(($('year') as HTMLSelectElement).value);

function say(text: string, error = false) {
  const m = $('msg');
  m.textContent = text;
  m.classList.toggle('error', error);
}

async function refresh() {
  $('state').textContent = 'Loading…';
  try {
    events = (await loadEvents(year())).sort((a, b) => (b.data.date ?? '').localeCompare(a.data.date ?? '') || a.data.name.localeCompare(b.data.name));
    $('state').textContent = `${events.length} events in ${year()}`;
  } catch (e) {
    $('state').textContent = 'Could not load events';
    say(String(e), true);
  }
  render();
}

function render() {
  $('add').toggleAttribute('disabled', !canSave() || editing !== null);
  $('list').innerHTML = events.map(({ id, data: d }) => `
    <div class="ev">
      <span class="label">${LABEL[d.kind]}</span><span class="name">${esc(d.name)}</span>
      <span class="label">${d.date ?? 'no date'}${d.kind === 'tournament' ? ` · ${d.stars}★ · ${d.participants} players` : ''} · ${d.results.length} results</span>
      ${canSave() && d.kind !== 'season' ? (confirmDelete === id
        ? `<button class="btn" data-del-yes="${id}">Delete for good</button><button class="btn" data-del-no>Keep</button>`
        : `<button class="btn" data-edit="${id}">Edit</button><button class="btn" data-del="${id}">Delete</button>`) : ''}
    </div>`).join('') || '<p class="hint">No stored events for this year (club seasons are added automatically).</p>';
  renderForm();
}

function renderForm() {
  const f = $('form') as HTMLFormElement;
  f.hidden = editing === null;
  if (!editing) { f.innerHTML = ''; return; }
  const d = editing.draft;
  const t = d.kind === 'tournament';
  f.innerHTML = `
    <div class="fields">
      <label>Kind <select name="kind">${(['tournament', 'series', 'marathon'] as EventKind[]).map((k) => `<option value="${k}" ${k === d.kind ? 'selected' : ''}>${LABEL[k]}</option>`).join('')}</select></label>
      <label>Name <input name="name" value="${esc(d.name)}" required></label>
      <label>Date <input name="date" type="date" value="${d.date ?? ''}"></label>
      ${t ? `<label>Stars <input name="stars" type="number" min="0" max="5" value="${d.stars ?? ''}"></label>
             <label>Participants <input name="participants" type="number" min="1" value="${d.participants ?? ''}"></label>` : ''}
    </div>
    <div class="rows">
      ${d.results.map((r, i) => `
        <div class="r ${r.player.trim() && !names.has(r.player.trim().toLowerCase()) ? 'guest' : ''}" data-i="${i}">
          <input name="player" list="players" value="${esc(r.player)}" placeholder="Player" aria-label="Player ${i + 1}">
          <input name="place" type="number" min="1" value="${Number.isFinite(r.place) ? r.place : ''}" aria-label="Place ${i + 1}">
          <span class="num">${Number.isFinite(r.place) && r.place >= 1 ? eventPoints(d.kind, r.place, d.stars, d.participants).toFixed(2) : ''}</span>
          <button type="button" class="btn" data-rm="${i}" aria-label="Remove row ${i + 1}">×</button>
        </div>`).join('')}
    </div>
    <div><button type="button" class="btn" data-add-row>Add player</button></div>
    <ul class="errors">${validateEvent(d).map((e) => `<li>${esc(e)}</li>`).join('')}</ul>
    <div><button type="submit" class="btn primary" ${busy ? 'disabled' : ''}>Save</button> <button type="button" class="btn" data-cancel>Cancel</button></div>`;
}

/** Reads the form into editing.draft (keeps focus: only re-render on structural changes). */
function readForm() {
  if (!editing) return;
  const f = $('form') as HTMLFormElement;
  const val = (n: string) => (f.elements.namedItem(n) as HTMLInputElement | null)?.value ?? '';
  const int = (s: string) => (s.trim() === '' ? NaN : Number(s));
  const d = editing.draft;
  d.kind = val('kind') as EventKind;
  d.name = val('name');
  d.date = val('date') || null;
  d.stars = d.kind === 'tournament' && val('stars') !== '' ? int(val('stars')) : d.kind === 'tournament' ? null : null;
  d.participants = d.kind === 'tournament' && val('participants') !== '' ? int(val('participants')) : null;
  d.results = [...f.querySelectorAll<HTMLElement>('.r')].map((row) => ({
    player: (row.querySelector('[name=player]') as HTMLInputElement).value,
    place: int((row.querySelector('[name=place]') as HTMLInputElement).value),
  }));
}

function updateLive() {
  if (!editing) return;
  const f = $('form');
  const d = editing.draft;
  f.querySelectorAll<HTMLElement>('.r').forEach((row, i) => {
    const r = d.results[i];
    row.classList.toggle('guest', !!r.player.trim() && !names.has(r.player.trim().toLowerCase()));
    row.querySelector('.num')!.textContent = Number.isFinite(r.place) && r.place >= 1 ? eventPoints(d.kind, r.place, d.stars, d.participants).toFixed(2) : '';
  });
  f.querySelector('.errors')!.innerHTML = validateEvent(d).map((e) => `<li>${esc(e)}</li>`).join('');
}

$('form').addEventListener('input', (ev) => {
  const kindChanged = (ev.target as HTMLElement).getAttribute('name') === 'kind';
  readForm();
  if (kindChanged) renderForm(); else updateLive();
});
$('form').addEventListener('change', (ev) => {
  if ((ev.target as HTMLElement).getAttribute('name') === 'kind') { readForm(); renderForm(); }
});
$('form').addEventListener('click', (ev) => {
  const b = (ev.target as HTMLElement).closest('button');
  if (!b || !editing) return;
  readForm();
  if (b.dataset.rm !== undefined) { editing.draft.results.splice(Number(b.dataset.rm), 1); renderForm(); }
  else if (b.hasAttribute('data-add-row')) {
    const next = Math.max(0, ...editing.draft.results.map((r) => (Number.isFinite(r.place) ? r.place : 0))) + 1;
    editing.draft.results.push({ player: '', place: next });
    renderForm();
  } else if (b.hasAttribute('data-cancel')) { editing = null; render(); }
});
$('form').addEventListener('submit', async (ev) => {
  ev.preventDefault();
  if (!editing || !canSave() || busy) return;
  readForm();
  const errors = validateEvent(editing.draft);
  if (errors.length) { updateLive(); return; }
  busy = true; renderForm();
  try {
    await saveEvent(editing.id, editing.draft, user as ClubAdmin);
    say(`Saved “${editing.draft.name}”. The site updates within an hour.`);
    editing = null;
    await refresh();
  } catch (e) { say(`Could not save: ${e}`, true); } finally { busy = false; renderForm(); }
});

$('list').addEventListener('click', async (ev) => {
  const b = (ev.target as HTMLElement).closest('button');
  if (!b || !canSave() || busy) return;
  if (b.dataset.edit) {
    const e = events.find((x) => x.id === b.dataset.edit)!;
    editing = { id: e.id, draft: structuredClone(e.data) };
    render();
  } else if (b.dataset.del) { confirmDelete = b.dataset.del; render(); }
  else if (b.hasAttribute('data-del-no')) { confirmDelete = null; render(); }
  else if (b.dataset.delYes) {
    busy = true;
    try { await deleteEvent(b.dataset.delYes, user as ClubAdmin); say('Deleted.'); confirmDelete = null; await refresh(); }
    catch (e) { say(`Could not delete: ${e}`, true); } finally { busy = false; }
  }
});

$('add').addEventListener('click', () => {
  editing = { id: null, draft: { year: year(), kind: 'tournament', name: '', date: null, stars: 3, participants: null, results: [{ player: '', place: 1 }] } };
  render();
});
$('year').addEventListener('change', () => { editing = null; confirmDelete = null; refresh(); });
$('sign-in').addEventListener('click', () => signIn().catch((e) => say(String(e), true)));
$('sign-out').addEventListener('click', () => signOutUser());
$('import').addEventListener('click', async () => {
  if (!canSave() || busy) return;
  busy = true;
  say('Importing…');
  try {
    const list = (await (await fetch(IMPORT_URL)).json()) as EventDraft[];
    await importEvents(list, user as ClubAdmin);
    say(`Imported ${list.length} events.`);
    $('import').hidden = true;
    await refresh();
  } catch (e) { say(`Import failed: ${e}`, true); } finally { busy = false; }
});

onClubUser(async (u) => {
  user = u;
  $('who').textContent = u === null ? 'Read-only' : u === 'not-host' ? 'Signed in, not a host — read-only' : `${u.name}${u.admin ? ' (admin)' : ' — not an admin, read-only'}`;
  $('sign-in').hidden = u !== null;
  $('sign-out').hidden = u === null;
  $('import').hidden = !(canSave() && (await eventsEmpty().catch(() => false)));
  render();
});
refresh();
```

- [ ] **Step 8: Type-check, test, build**

Run: `cd site && npm test && npm run check && npm run build`
Expected: all vitest suites pass; `astro check` 0 errors; build + `check-dist` pass; `dist/annual/edit/index.html` exists.

- [ ] **Step 9: Commit**

```bash
git add site/src/lib/annual site/src/pages/annual/edit.astro site/src/scripts/annual-edit.ts
git commit -m "feat(site): admins edit the annual rating's events"
```

---

### Task 8: Docs and full verification

**Files:**
- Modify: `CLAUDE.md` (Web site section)

- [ ] **Step 1: Add to CLAUDE.md's Web site section** (after the Tournaments bullet)

```markdown
- **Annual rating:** `/annual/` (+ `/annual/<year>/`) from `site/data/annual.json`
  (`lib/site_export/annual_export.dart`, formulas in `lib/services/stats/annual_rating.dart`, TS port in
  `site/src/lib/annual/points.ts`, both checked against `test/fixtures/annual_points_cases.json`). External
  tournaments, series and marathons are Firestore `events/{id}`, edited by admins on `/annual/edit/`;
  prefetch snapshots them into `assets/prefetched/annual_events.json`. Club seasons from S28 are added by
  the export once finished (main league 1…N, small league top 5 as 101–105, year of the season's last month).
  2024–2025 came from the sheets once (`tool/import/`).
```

- [ ] **Step 2: Full verification**

Run: `flutter analyze && flutter test > .superpowers/full-test.log 2>&1; tail -3 .superpowers/full-test.log`
Expected: no analyzer issues; `All tests passed!`.

Run: `cd firebase/rules-test && JAVA_HOME="/c/Program Files/Android/AndroidStudio/jbr" PATH="/c/Program Files/Android/AndroidStudio/jbr/bin:$PATH" npm test`
Expected: all pass.

Run: `cd site && npm test && npm run check && npm run build`
Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: annual rating"
```

## Rollout (after the user says so; not part of the tasks)

1. Paste the `events` block (and `optInt`) into the Firebase console Rules tab, Publish, verify a public read of `events` returns 200.
2. Push `feature/flutter_migration` and fast-forward `master`; wait for the deploy.
3. An admin opens `/annual/edit/`, signs in, clicks «Import 2024–2026 from the sheets».
4. After the next rebuild, `/annual/` shows 2026 with Seezov 132.13 at the top; `/annual/2025/` Stone Cold 272.55; `/annual/2024/` Залізний 317.82.
