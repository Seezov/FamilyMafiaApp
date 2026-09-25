import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a tournament entry', () {
    final t = Tournament.fromJson({
      'season': 27, 'type': 'minicap', 'name': 'Мінікап 30.09',
      'games': 4, 'date': '30.09.2025',
    });
    expect(t.seasonId, 27);
    expect(t.type, TournamentType.minicap);
    expect(t.games, 4);
  });

  test('missing key gives no tournaments', () {
    expect(parseTournaments({'seasons': []}), isEmpty);
  });

  test('bundled config lists the collected tournaments', () {
    final json = jsonDecode(
        File('assets/raw/season_config.json').readAsStringSync());
    final all = parseTournaments(json as Map<String, dynamic>);
    expect(all.where((t) => t.seasonId == 25 && t.type == TournamentType.minicap).length, 5);
    expect(all.where((t) => t.seasonId == 25 && t.type == TournamentType.maxicap).length, 3);
    expect(all.where((t) => t.seasonId == 30).single.name, 'Ліга №1');
  });

  test('every bundled tournament has a top-3 podium', () {
    final json = jsonDecode(
        File('assets/raw/season_config.json').readAsStringSync());
    final all = parseTournaments(json as Map<String, dynamic>);
    expect(all.where((t) => t.podium.length != 3), isEmpty);
    expect(all.firstWhere((t) => t.name == 'Мінікап 11.03').podium, ['Braun', 'Скай', 'Фрау']);
    expect(all.where((t) => t.type == TournamentType.bigcap).length, 8);
  });
}
