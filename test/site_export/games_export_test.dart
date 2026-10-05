import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
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
    // Season 21 already has undated games of its own; the two made here join them.
    final count = undated.where((g) => g.date == null).length;
    expect(count, greaterThanOrEqualTo(2));
    expect((days.last['games'] as List).map((g) => g['id']), [for (var i = 0; i < count; i++) 'g-x-$i']);
    expect(days.where((d) => d['date'] == null).length, 1);
  });

  test('result, host filter list and players list', () {
    final j = json(21);
    expect(games(j).map((g) => g['result']).toSet(), containsAll(['city', 'mafia', 'unrated']));
    expect(j['hosts'], isNotEmpty);
    expect((j['players'] as List).cast<Map>().every((p) => p['key'] != null && p['name'] != null), isTrue);
  });
}
