import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

List<Game> _season(int id) {
  final raw = (jsonDecode(File('assets/raw/season$id.json').readAsStringSync())
          as List)
      .cast<Map<String, dynamic>>();
  return parseSeasonGamesForTest(id, raw);
}

void main() {
  test('seasons 0-1 have no host or date', () {
    final g = _season(0).first;
    expect(g.host, isNull);
    expect(g.date, isNull);
  });

  test('season 2 reads host from slot 9 and date from slot 10', () {
    final g = _season(2).first;
    expect(g.host, 'Рауль');
    expect(g.date, DateTime.utc(2019, 3, 5));
  });

  test('season 16 ignores the host score next to the host name', () {
    final g = _season(16).first;
    expect(g.host, 'Скай');
    expect(g.date, DateTime.utc(2022, 12, 1));
  });

  test('season 20 reads host from the game header row', () {
    final g = _season(20).first;
    expect(g.host, 'Малишка');
    expect(g.date, DateTime.utc(2023, 3, 12));
  });

  test('most season 16 games have a host', () {
    final games = _season(16).where((g) => g.isRatingGame()).toList();
    final withHost = games.where((g) => g.host != null).length;
    expect(withHost / games.length, greaterThan(0.9));
  });
}
