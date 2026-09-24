import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a player whose only role record is [role]: [games] played,
/// [wins] won, and [points] of best-move + additional + penalty points.
RatingPlayerStats _p(
  int id,
  Role role, {
  required int games,
  required int wins,
  double points = 0.0,
  int gameLimit = 60,
}) {
  return RatingPlayerStats(
    seasonId: 30,
    player: Player(id: id, displayName: 'P$id'),
    gamesPlayed: games,
    seasonGameLimit: gameLimit,
    gamesForRole: [(role.sheetValue, games)],
    winByRole: [(role.sheetValue, wins)],
    bestMoveAndAdditionalPointsByRole: [(role.sheetValue, points)],
  );
}

void main() {
  // Sheriff needs gameLimit * 0.1 games, so 6 games qualifies at gameLimit 60.

  group('rankPlayersForRole', () {
    test('returns an empty list when nobody is eligible', () {
      final players = [_p(1, Role.sheriff, games: 2, wins: 2)];
      expect(rankPlayersForRole(players, Role.sheriff), isEmpty);
    });

    test('first place is the same player findBestPlayerForRole picks', () {
      final players = [
        _p(1, Role.sheriff, games: 10, wins: 5, points: 1.0),
        _p(2, Role.sheriff, games: 10, wins: 5, points: 3.0),
        _p(3, Role.sheriff, games: 10, wins: 4, points: 9.0),
      ];
      final winner = findBestPlayerForRole(players, Role.sheriff);
      final ranking = rankPlayersForRole(players, Role.sheriff);
      expect(ranking.first.player.id, winner!.player.id);
    });

    test('never repeats a player', () {
      final players = [
        _p(1, Role.sheriff, games: 10, wins: 5, points: 1.0),
        _p(2, Role.sheriff, games: 10, wins: 5, points: 3.0),
        _p(3, Role.sheriff, games: 10, wins: 4, points: 9.0),
      ];
      final ids = rankPlayersForRole(players, Role.sheriff)
          .map((p) => p.player.id)
          .toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ranks the whole eligible field when fewer than the cap', () {
      final players = [
        _p(1, Role.sheriff, games: 10, wins: 5, points: 1.0),
        _p(2, Role.sheriff, games: 10, wins: 5, points: 3.0),
        _p(3, Role.sheriff, games: 2, wins: 2, points: 9.0), // not eligible
      ];
      final ranking = rankPlayersForRole(players, Role.sheriff);
      expect(ranking.map((p) => p.player.id), [2, 1]);
    });

    test('caps the ranking at the requested size', () {
      final players = [
        for (var i = 1; i <= 6; i++)
          _p(i, Role.mafia, games: 20, wins: 10, points: i.toDouble()),
      ];
      expect(rankPlayersForRole(players, Role.mafia).length, 4);
      expect(rankPlayersForRole(players, Role.mafia, take: 2).length, 2);
    });

    test('orders by the same rule used to pick the winner', () {
      // All within 0.2 win rate of each other, so average points decides.
      final players = [
        _p(1, Role.mafia, games: 20, wins: 10, points: 2.0),
        _p(2, Role.mafia, games: 20, wins: 10, points: 6.0),
        _p(3, Role.mafia, games: 20, wins: 10, points: 4.0),
      ];
      final ranking = rankPlayersForRole(players, Role.mafia);
      expect(ranking.map((p) => p.player.id), [2, 3, 1]);
    });
  });
}
