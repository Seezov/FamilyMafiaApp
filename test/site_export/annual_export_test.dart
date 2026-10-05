import 'package:family_mafia_app/models/annual_event.dart';
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
    final c = await fixtureContainer(seasonIds: [21], clock: () => DateTime.utc(2024, 4, 1));
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
