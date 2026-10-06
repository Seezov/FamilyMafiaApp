import 'dart:convert';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/site_export/allstars_export.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

AllstarsEvent ev(int year, List<String> order,
        {List<AllstarsGame> games = const [], List<AllstarsNomination>? noms, String? host, String? source}) =>
    AllstarsEvent(
      year: year,
      name: 'Event $year',
      date: null,
      hostLabel: 'Ведучий',
      host: host,
      source: source,
      gameCount: games.length,
      columns: const [AllstarsColumn('Бали')],
      standings: [for (var i = 0; i < order.length; i++) AllstarsStanding(order[i], ['${10 - i}'])],
      nominations: noms,
      games: games,
    );

void main() {
  late Map json;
  setUp(() async {
    final c = await fixtureContainer();
    final events = [
      ev(2019, ['Железный', 'Nobody Known', 'Аглая'], games: [
        AllstarsGame(firstKilled: 2, seats: const [
          AllstarsSeat(player: 'Железный', role: AllstarsRole.civilian, add: 0.3, bestMove: 0),
          AllstarsSeat(player: 'Nobody Known', role: AllstarsRole.mafia, add: 0, bestMove: 0.4),
          AllstarsSeat(player: 'Аглая', role: AllstarsRole.don, add: -0.5, bestMove: 0),
        ]),
      ]),
      ev(2025, ['Аглая', 'Залізний'], host: 'Суддя Х', source: 'https://example.org/r', noms: [
        const AllstarsNomination('mvp', [(player: 'Аглая', value: '4.30')]),
      ]),
    ];
    json = jsonDecode(jsonEncode(allstarsJson(ExportContext(c), events))) as Map;
  });

  test('events newest first, null fields omitted', () {
    final events = json['events'] as List;
    expect([for (final e in events) e['year']], [2025, 2019]);
    expect(events[1].containsKey('host'), isFalse);
    expect(events[1].containsKey('source'), isFalse);
    expect(events[1].containsKey('date'), isFalse);
    expect(events[0]['source'], 'https://example.org/r');
    expect(events[0]['players'], 2);
  });

  test('podium resolves nicknames and leaves unknown names unlinked', () {
    final podium = (json['events'] as List)[1]['podium'] as List;
    expect(podium[0]['t'], 'Залізний');
    expect(podium[0]['link'], isNotNull);
    expect(podium[1], {'t': 'Nobody Known'});
  });

  test('official nominations pass through; computed ones are flagged', () {
    final e25 = (json['events'] as List)[0]['nominations'] as List;
    expect(e25.single['official'], isTrue);
    expect(e25.single['rows'][0]['value'], '4.30');

    final e19 = (json['events'] as List)[1]['nominations'] as List;
    expect([for (final n in e19) n['key']], ['mvp', 'firstKilled', 'bestRed', 'bestMafia']);
    expect(e19.every((n) => n['official'] == false), isTrue);
    final killed = e19[1]['rows'] as List;
    expect(killed.single['player']['t'], 'Nobody Known');
    expect(killed.single['value'], '1');
    expect((e19[0]['rows'] as List).first['value'], '0.40');
  });

  test('the final table keeps its order and is not re-sortable', () {
    final table = (json['events'] as List)[1]['table'] as Map;
    expect(table.containsKey('sortColumn'), isFalse);
    expect(table['showRank'], isTrue);
    expect([for (final r in table['rows'] as List) r[0]['t']], ['Залізний', 'Nobody Known', 'Аглая']);
  });

  test('champions merge nicknames across years', () {
    final rows = (json['champions'] as Map)['rows'] as List;
    final aglaya = rows.firstWhere((r) => r[0]['t'] == 'Аглая');
    final zal = rows.firstWhere((r) => r[0]['t'] == 'Залізний');
    expect([aglaya[1]['t'], aglaya[3]['t']], ['1', '1']); // 1st 2025, 3rd 2019
    expect([zal[1]['t'], zal[2]['t']], ['1', '1']);      // 1st 2019, 2nd 2025
    expect(aglaya[5]['t'], '2025');
  });
}
