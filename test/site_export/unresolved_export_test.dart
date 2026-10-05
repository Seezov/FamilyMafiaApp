import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/unresolved_export.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(int season, List<String> players) => Game(
      seasonId: season, players: players, roles: List.filled(players.length, 'Мирний'),
      firstKilled: 0, bestMovePoints: 0, bestMove: const []);

void main() {
  test('lists names no player owns, junk and placeholders left out', () {
    final resolver = PlayerResolver(const [Player(id: 0, displayName: 'Braun', nicknames: ['Браун'])]);
    final out = unresolvedNames([
      _g(30, ['Braun', 'Новенький', '_blank_3', '17', '/']),
      _g(31, ['Новенький', 'Гість', 'x']),
    ], resolver);
    expect(out, [
      {'name': 'Новенький', 'games': 2, 'lastSeason': 31},
      {'name': 'Гість', 'games': 1, 'lastSeason': 31},
    ]);
  });
}
