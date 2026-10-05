import 'dart:convert';
import 'dart:io';

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
      // The sheet's table lists names by hand and misses a few players (Гоа,
      // Nemo…); everyone it does list must have exactly its score.
      expect({for (final k in want.keys) k: got[k]}, want, reason: '$year');
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
    final want = (totals['2026'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    expect({for (final k in want.keys) k: got[k]}, want);
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
