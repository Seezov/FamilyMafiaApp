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
    final Map json = seasonJson(x, season);
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
    final Map json = seasonJson(x, season);
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
    final Map json = seasonJson(x, x.seasons.last);
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
