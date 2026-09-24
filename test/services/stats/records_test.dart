import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _cfg(int id) => SeasonConfig(
    id: id, title: 'S$id', gameLimit: 2, smallLeagueMinGames: 1,
    gamesMultiplier: 0, source: const BundledSource(jsonFile: 'x'));

RatingPlayerStats _r(int season, int id, {int games = 2, int wins = 1, double add = 0.6}) =>
    RatingPlayerStats(
      seasonId: season, player: Player(id: id, displayName: 'P$id'),
      gamesPlayed: games, wins: wins, winRate: wins / games, additionalPoints: add,
      firstKilled: 1, percentOfDeath: 0.5,
      gamesForRole: [('Мирний', 2)], winByRole: [('Мирний', wins)],
      bestMoveAndAdditionalPointsByRole: [('Мирний', add)],
    );

Game _g(int season, {double add0 = 0, double add1 = 0, String? host}) => Game(
      seasonId: season,
      players: ['P1', 'P2', ...List.generate(8, (i) => 'x$i')],
      roles: List.filled(10, 'Мирный'),
      cityWon: true, firstKilled: 0, bestMovePoints: 0, bestMove: const [],
      additionalPoints: [add0, add1, ...List.filled(8, 0.0)],
      host: host,
    );

RecordsInput _input({Map<int, List<RatingPlayerStats>>? ratings, List<Game>? games}) => RecordsInput(
      ratings: ratings ?? {10: [_r(10, 1), _r(10, 2, games: 1)]},
      configs: [_cfg(2), _cfg(10)],
      games: games ?? [_g(10, add0: 0.5, add1: -0.3), _g(10, add0: 0.1)],
      resolver: PlayerResolver(const [Player(id: 1, displayName: 'P1'), Player(id: 2, displayName: 'P2')]),
    );

void main() {
  test('MVP: main league only, per game and max single доп', () {
    final r = mvpRecords(_input(), PointsPeriod.modern);
    expect(r.map((e) => e.player.id), [1]); // P2 has 1 game < gameLimit 2
    expect(r.single.addPerGame, closeTo(0.3, 1e-9));
    expect(r.single.maxSingleAdd, closeTo(0.5, 1e-9));
  });

  test('periods keep seasons 2-3 apart from 4+', () {
    final input = _input(ratings: {2: [_r(2, 1)], 10: [_r(10, 1)]});
    expect(mvpRecords(input, PointsPeriod.li).single.seasonId, 2);
    expect(mvpRecords(input, PointsPeriod.modern).single.seasonId, 10);
  });

  test('penalties read the minus from games', () {
    final input = _input(ratings: {10: [_r(10, 2)]});
    final r = penaltyRecords(input, PointsPeriod.modern);
    expect(r.single.totalMinus, closeTo(-0.3, 1e-9));
    expect(r.single.maxSingleMinus, closeTo(-0.3, 1e-9));
  });

  test('all-time games include every player and sum seasons', () {
    final input = _input(ratings: {2: [_r(2, 1, games: 1)], 10: [_r(10, 1, games: 1)]});
    expect(gamesRecords(input, allTime: true).single.games, 2);
    expect(gamesRecords(input, allTime: false), isEmpty); // both below gameLimit
  });

  test('roles use the role games and points', () {
    final r = roleRecords(_input(), Role.civilian, PointsPeriod.modern);
    expect(r.single.games, 2);
  });

  test('works with a single loaded season and no games', () {
    final input = RecordsInput(ratings: {10: [_r(10, 1)]}, configs: [_cfg(10)], games: const [], resolver: PlayerResolver(const []));
    expect(mvpRecords(input, PointsPeriod.modern).single.maxSingleAdd, 0);
    expect(hostRecords(input, allTime: true), isEmpty);
  });

  test('ties sort by name', () {
    final input = _input(ratings: {10: [_r(10, 2), _r(10, 1)]});
    expect(mvpRecords(input, PointsPeriod.modern).map((e) => e.player.id), [1, 2]);
  });
}
