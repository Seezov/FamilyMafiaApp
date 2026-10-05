import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/services/sheet_game_extras.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

String? seasonFile(int id) {
  for (final p in ['assets/raw/season$id.json', 'assets/prefetched/season$id.json']) {
    if (File(p).existsSync()) return p;
  }
  return null;
}

void main() {
  test('every bundled and prefetched season aligns extras with games', () {
    for (var id = 0; id <= 40; id++) {
      final path = seasonFile(id);
      if (path == null) continue;
      final json = File(path).readAsStringSync();
      if (json.trimLeft().startsWith('{')) continue; // firestore snapshot
      final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>().map(GamesDataSeason.fromJson).toList();
      expect(sheetGameExtras(id, raw).length, parseSeasonJsonForTest(id, json).length, reason: 'season $id');
    }
  });

  test('S21 games carry their comments; S25 games their tables', () {
    final s21 = parseSeasonJsonForTest(21, File('assets/raw/season21.json').readAsStringSync());
    final g = s21.firstWhere((g) => g.comments?.any((c) => c.text.startsWith('играла во всех черных')) ?? false);
    expect(g.players[7], isNotEmpty); // seat 8 exists
    final s25 = parseSeasonJsonForTest(25, File('assets/raw/season25.json').readAsStringSync());
    expect(s25.where((g) => g.table == 2), isNotEmpty);
  });

  test('misaligned extras are dropped, not shifted', () {
    final rows = (jsonDecode(File('assets/raw/season21.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    // An extra «Дата» row with nothing after it adds an anchor but no game.
    final broken = [...rows, {'A': 'Дата', 'B': '2024-05-31', 'C': ''}];
    final games = parseSeasonJsonForTest(21, jsonEncode(broken));
    expect(games.every((g) => g.comments == null && g.label == null && g.table == null), isTrue);
  });

  test('browserGames keeps non-rating games and canonical names', () {
    final players = (jsonDecode(File('assets/raw/players.json').readAsStringSync()) as List)
        .map((e) => Player.fromJson(e as Map<String, dynamic>))
        .toList();
    final json = File('assets/raw/season21.json').readAsStringSync();
    final all = browserGames(21, json, PlayerResolver(players));
    expect(all.length, parseSeasonJsonForTest(21, json).length);
    expect(all.where((g) => !g.isRatingGame()), isNotEmpty);
  });
}
