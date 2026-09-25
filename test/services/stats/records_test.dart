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
      configs: [_cfg(2), _cfg(10), _cfg(21)],
      games: games ?? [_g(10, add0: 0.5, add1: -0.3), _g(10, add0: 0.1)],
      resolver: PlayerResolver(const [Player(id: 1, displayName: 'P1'), Player(id: 2, displayName: 'P2')]),
    );

Game _hostGame(int season, {double plus = 0}) => Game(
      seasonId: season,
      players: List.generate(10, (i) => 'x$i'),
      roles: List.filled(10, 'Мирный'),
      cityWon: true, firstKilled: 0, bestMovePoints: 0, bestMove: const [],
      additionalPoints: [plus, ...List.filled(9, 0.0)],
      host: 'H',
    );

void main() {
  test('MVP: main league only, per game and max single доп', () {
    final r = mvpRecords(_input(), PointsPeriod.modern);
    expect(r.map((e) => e.player.id), [1]); // P2 has 1 game < gameLimit 2
    expect(r.single.addPerGame, closeTo(0.3, 1e-9));
    expect(r.single.maxSingleAdd, closeTo(0.5, 1e-9));
    expect(r.single.totalAdd, closeTo(0.6, 1e-9));
  });

  test('MVP addPerGame follows the club MVP formula', () {
    // (additionalPoints + bestMovePoints + penaltyPoints) / gamesPlayed,
    // same as calculateMvp for seasons 2+: (1.0 + 0.4 - 0.4) / 2 = 0.5.
    final input = _input(ratings: {10: [
      RatingPlayerStats(
        seasonId: 10, player: const Player(id: 1, displayName: 'P1'),
        gamesPlayed: 2, wins: 1, winRate: 0.5,
        additionalPoints: 1.0, bestMovePoints: 0.4, penaltyPoints: -0.4,
      ),
    ]});
    final r = mvpRecords(input, PointsPeriod.modern);
    expect(r.single.addPerGame, closeTo(0.5, 1e-9));
    expect(r.single.totalAdd, closeTo(1.0, 1e-9));
  });

  test('MVP maxSingleAdd includes the first-killed best move and subtracts that game\'s penalty', () {
    final gameWithBestMove = Game(
      seasonId: 10,
      players: ['P1', 'P2', ...List.generate(8, (i) => 'x$i')],
      roles: List.filled(10, 'Мирный'),
      cityWon: true,
      firstKilled: 1, // slot 0 = P1
      bestMovePoints: 0.8,
      bestMove: const [],
      additionalPoints: [0.2, 0, ...List.filled(8, 0.0)],
      penaltyPoints: [-0.3, 0, ...List.filled(8, 0.0)],
    );
    final otherGame = _g(10, add0: 0.5); // no best move, no penalty: gp = 0.5
    final input = _input(ratings: {10: [_r(10, 1)]}, games: [gameWithBestMove, otherGame]);
    final r = mvpRecords(input, PointsPeriod.modern);
    // 0.2 (доп) - 0.3 (штраф) + 0.8 (кращий хід) = 0.7, beats the other game's 0.5.
    expect(r.single.maxSingleAdd, closeTo(0.7, 1e-9));
  });

  test('periods keep seasons 2-3 apart from 4+', () {
    final input = _input(ratings: {2: [_r(2, 1)], 10: [_r(10, 1)]});
    expect(mvpRecords(input, PointsPeriod.li).single.seasonId, 2);
    expect(mvpRecords(input, PointsPeriod.modern).single.seasonId, 10);
  });

  test('penalties read the minus from games', () {
    final input = _input(ratings: {21: [_r(21, 2)]}, games: [_g(21, add1: -0.3)]);
    final r = penaltyRecords(input);
    expect(r.single.totalMinus, closeTo(-0.3, 1e-9));
    expect(r.single.maxSingleMinus, closeTo(-0.3, 1e-9));
  });

  test('penalties only count seasons 21+, where the Штраф column exists', () {
    final input = _input(
      ratings: {10: [_r(10, 1)], 20: [_r(20, 1)], 21: [_r(21, 1)]},
      games: [_g(10, add0: -0.5), _g(20, add0: -0.5), _g(21, add0: -0.3)],
    );
    final r = penaltyRecords(input);
    expect(r.map((e) => e.seasonId), [21]);
  });

  test('a -2 доп (disqualification) is excluded from penalty totals', () {
    final input = _input(
      ratings: {21: [_r(21, 1), _r(21, 2)]},
      games: [_g(21, add0: -0.3, add1: -2.0)],
    );
    final r = penaltyRecords(input);
    final p1 = r.firstWhere((e) => e.player.id == 1);
    final p2 = r.firstWhere((e) => e.player.id == 2);
    expect(p1.totalMinus, closeTo(-0.3, 1e-9));
    expect(p2.totalMinus, closeTo(0, 1e-9));
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

  test('MVP ties break by fewer games first, then name', () {
    // Both addPerGame = 0.3, but P2 played fewer games than P1.
    final input = _input(ratings: {10: [
      _r(10, 1, games: 4, add: 1.2),
      _r(10, 2, games: 2, add: 0.6),
    ]});
    expect(mvpRecords(input, PointsPeriod.modern).map((e) => e.player.id), [2, 1]);
  });

  test('penalty ties break by fewer games first, then name', () {
    // Both minusPerGame = -0.3; 'Zed' (id 1) played fewer games than 'Amy'
    // (id 2), but 'Amy' sorts first by name — the games tie-break must win.
    final input = _input(
      ratings: {21: [
        RatingPlayerStats(seasonId: 21, player: const Player(id: 1, displayName: 'Zed'), gamesPlayed: 2),
        RatingPlayerStats(seasonId: 21, player: const Player(id: 2, displayName: 'Amy'), gamesPlayed: 4),
      ]},
      games: [_g(21, add0: -0.6), _g(21, add1: -1.2)],
    );
    final r = penaltyRecords(input);
    expect(r.map((e) => e.player.displayName), ['Zed', 'Amy']);
  });

  test('roles: ties break by fewer role games first, then name', () {
    RatingPlayerStats stats(int id, String name, int games, double points) => RatingPlayerStats(
          seasonId: 10, player: Player(id: id, displayName: name),
          gamesPlayed: games, wins: 1, winRate: 0.5,
          gamesForRole: [('Мирний', games)], winByRole: [('Мирний', 1)],
          bestMoveAndAdditionalPointsByRole: [('Мирний', points)],
        );
    // Both pointsPerGame = 0.3; 'Zed' has fewer role games than 'Amy', but
    // 'Amy' sorts first by name — the games tie-break must win.
    final input = _input(ratings: {10: [stats(1, 'Zed', 2, 0.6), stats(2, 'Amy', 4, 1.2)]});
    final r = roleRecords(input, Role.civilian, PointsPeriod.modern);
    expect(r.map((e) => e.player.displayName), ['Zed', 'Amy']);
  });

  test('hostRecords all-time: hosted counts every season, averages use only the period games', () {
    final games = [
      for (var i = 0; i < 5; i++) _hostGame(2, plus: 1.0), // li period
      for (var i = 0; i < 5; i++) _hostGame(10, plus: 2.0), // modern period
    ];
    final input = RecordsInput(ratings: const {}, configs: [_cfg(2), _cfg(10)], games: games, resolver: PlayerResolver(const []));
    final r = hostRecords(input, allTime: true, period: PointsPeriod.modern);
    expect(r.single.hosted, 10);
    expect(r.single.periodGames, 5);
    expect(r.single.avgPlus, closeTo(2.0, 1e-9));
  });

  test('hostRecords per season: every season with hosts appears, even outside the period', () {
    final games = [
      for (var i = 0; i < 3; i++) _hostGame(2, plus: 1.0), // li period
      for (var i = 0; i < 3; i++) _hostGame(10, plus: 2.0), // modern period
    ];
    final input = RecordsInput(ratings: const {}, configs: [_cfg(2), _cfg(10)], games: games, resolver: PlayerResolver(const []));
    final r = hostRecords(input, allTime: false, period: PointsPeriod.modern);
    final bySeason = {for (final row in r) row.seasonId: row};
    expect(bySeason.keys, containsAll([2, 10]));
    expect(bySeason[2]!.hosted, 3);
    expect(bySeason[2]!.periodGames, 0); // season 2 is outside 'modern'
    expect(bySeason[10]!.hosted, 3);
    expect(bySeason[10]!.periodGames, 3);
  });

  test('first kill: ties break by fewer red games first, then name', () {
    RatingPlayerStats fk(int id, String name, int games, int redG) => RatingPlayerStats(
          seasonId: 10, player: Player(id: id, displayName: name),
          gamesPlayed: games, firstKilled: 1, percentOfDeath: 0.5,
          gamesForRole: [('Мирний', redG)],
        );
    // Both count = 1, percentOfDeath = 0.5; 'Zed' has fewer red games than
    // 'Amy', but 'Amy' sorts first by name — the games tie-break must win.
    final input = _input(ratings: {10: [fk(1, 'Zed', 2, 2), fk(2, 'Amy', 4, 4)]});
    final r = firstKillRecords(input);
    expect(r.map((e) => e.player.displayName), ['Zed', 'Amy']);
  });
}
