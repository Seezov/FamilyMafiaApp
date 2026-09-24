import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(String? host, {double plus = 0, double minus = 0, int season = 10}) => Game(
      seasonId: season,
      players: List.generate(10, (i) => 'p$i'),
      roles: List.filled(10, 'Мирный'),
      cityWon: true,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
      host: host,
      additionalPoints: [plus, minus, ...List.filled(8, 0.0)],
    );

final _resolver = PlayerResolver(const [
  Player(id: 7, displayName: 'Seezov', nicknames: ['Сізов']),
]);

void main() {
  test('counts hosted games and merges nicknames', () {
    final stats = hostStats([_g('Seezov'), _g('Сізов'), _g('Луна')], _resolver);
    expect(stats.first.host.displayName, 'Seezov');
    expect(stats.first.hosted, 2);
    expect(stats.last.host.displayName, 'Луна');
  });

  test('averages plus and minus per hosted game', () {
    final stats = hostStats(
        [_g('A', plus: 1.0, minus: -0.2), _g('A', plus: 0.5)], _resolver);
    expect(stats.single.avgPlus, closeTo(0.75, 1e-9));
    expect(stats.single.avgMinus, closeTo(-0.1, 1e-9));
  });

  test('average rankings need 20 hosted games', () {
    final games = [
      for (var i = 0; i < 20; i++) _g('Many', plus: 0.2),
      for (var i = 0; i < 19; i++) _g('Few', plus: 2.0),
    ];
    final ranked = rankHostsByAvgPlus(hostStats(games, _resolver));
    expect(ranked.map((h) => h.host.displayName), ['Many']);
  });

  test('ties are ordered by name', () {
    final stats = hostStats([_g('B'), _g('A')], _resolver);
    expect(stats.map((h) => h.host.displayName), ['A', 'B']);
  });

  test('games without host: null when the season has no host data', () {
    expect(gamesWithoutHost([_g(null), _g(null)]), isNull);
    expect(gamesWithoutHost([_g('A'), _g(null)]), 1);
  });

  test('minus ranking puts the most negative first', () {
    final games = [
      for (var i = 0; i < 20; i++) _g('Soft', minus: -0.1),
      for (var i = 0; i < 20; i++) _g('Hard', minus: -0.5),
    ];
    final ranked = rankHostsByAvgMinus(hostStats(games, _resolver));
    expect(ranked.first.host.displayName, 'Hard');
  });
}
