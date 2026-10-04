import 'dart:convert';

import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';

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

  test('hosts have no period split and a "Без ведучого" row per season and all time', () async {
    final c = await fixtureContainer(seasonIds: const [21, 22]);
    final x = ExportContext(c);
    final json = jsonDecode(jsonEncode(recordsJson(x))) as Map;
    final hosts = (json['categories'] as List).firstWhere((cat) => cat['slug'] == 'hosts');
    expect(hosts['filters'], ['scope']);
    final tables = json['tables'] as Map;
    expect(tables.keys.where((k) => (k as String).startsWith('hosts/')),
        unorderedEquals(['hosts/season', 'hosts/alltime']));

    final games = c.read(gamesRepositoryProvider);
    final expected = <String, int>{
      for (final s in [21, 22])
        if ((gamesWithoutHost(games.where((g) => g.seasonId == s)) ?? 0) > 0)
          'S$s': gamesWithoutHost(games.where((g) => g.seasonId == s))!,
    };
    expect(expected, isNotEmpty, reason: 'fixture needs games without a host');

    List noHostRows(String key) => (tables[key]['table']['rows'] as List)
        .where((r) => r[0]['t'] == 'Без ведучого')
        .toList();
    expect({for (final r in noHostRows('hosts/season')) r[4]['t']: r[1]['s']}, expected);

    final all = noHostRows('hosts/alltime').single;
    expect(all[1]['s'], expected.values.fold<int>(0, (a, b) => a + b));
    expect((all[0] as Map).containsKey('link'), isFalse);
    expect(all[2]['t'], '—');
    expect(all[3]['t'], '—');
  });
}
