import 'dart:convert';

import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/tournaments_export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

const _tournaments = [
  Tournament(
    seasonId: 21,
    type: TournamentType.minicap,
    name: 'Second',
    games: 4,
    podium: ['Железный', 'Nobody Known', 'Залізний'],
  ),
  Tournament(
    seasonId: 17,
    type: TournamentType.marathon,
    name: 'First',
    games: 8,
    date: '14.05.2023',
    podium: ['Залізний'],
  ),
];

void main() {
  late Map json;
  setUp(() async {
    final parent = await fixtureContainer();
    final c = ProviderContainer(parent: parent, overrides: [
      tournamentsProvider.overrideWithValue(_tournaments),
    ]);
    addTearDown(c.dispose);
    json = jsonDecode(jsonEncode(tournamentsJson(ExportContext(c)))) as Map;
  });

  test('totals and per-type counts', () {
    expect(json['totals'], {'tournaments': 2, 'games': 12});
    expect(json['types'], [
      {'type': 'minicap', 'label': 'Minicap', 'count': 1, 'games': 4},
      {'type': 'marathon', 'label': 'Marathon', 'count': 1, 'games': 8},
    ]);
  });

  test('seasons newest first; podium names resolve and link', () {
    final seasons = json['seasons'] as List;
    expect(seasons.map((s) => s['id']), [21, 17]);
    final podium = seasons.first['events'].first['podium'] as List;
    expect(podium[0]['t'], 'Залізний');
    expect(podium[0]['link'], isNotNull);
    expect(podium[1], {'t': 'Nobody Known'});
  });

  test('winners merge nicknames of one player', () {
    final rows = json['winners']['rows'] as List;
    final z = rows.firstWhere((r) => r[0]['t'] == 'Залізний') as List;
    // 1st twice (both spellings), 3rd once, one minicap win.
    expect([for (final c in z.skip(1)) c['t']], ['2', '0', '1', '3', '1']);
  });

  test('by-season table has a row per loaded season', () {
    final rows = json['bySeason']['rows'] as List;
    expect(rows.map((r) => r[0]['t']), ['S17', 'S21']);
    expect(rows.first.last['t'], '8');
  });
}
