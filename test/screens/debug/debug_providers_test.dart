import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a minimal rating game. `players` are slot 0..n names, `roles`
/// parallel to players. `cityWon` null => non-rating game.
Game _game({
  required List<String> players,
  required List<String> roles,
  required bool? cityWon,
}) {
  return Game(
    seasonId: 5,
    players: players,
    roles: roles,
    cityWon: cityWon,
    firstKilled: 0,
    bestMovePoints: 0.0,
    bestMove: const [],
  );
}

// Roles used by Game.hasPlayerWon via Role.findByValue.
const _civ = 'Мирный';
const _maf = 'Мафия';

void main() {
  group('winRateBySlotForPlayer', () {
    final seezov = const Player(id: 1, displayName: 'Seezov');

    test('returns 10 slots numbered 1..10 in order', () {
      final result = winRateBySlotForPlayer(const [], seezov);
      expect(result.length, 10);
      expect(result.map((s) => s.slot).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('empty games => zero played, zero winRate for every slot', () {
      final result = winRateBySlotForPlayer(const [], seezov);
      for (final s in result) {
        expect(s.played, 0);
        expect(s.wins, 0);
        expect(s.winRate, 0.0);
      }
    });

    test('counts played and wins in the correct slot', () {
      final games = [
        _game(players: ['Seezov', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: true),
        _game(players: ['Seezov', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: false),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].slot, 1);
      expect(result[0].played, 2);
      expect(result[0].wins, 1);
      expect(result[0].winRate, 0.5);
      expect(result[1].played, 0);
    });

    test('ignores non-rating games (cityWon == null)', () {
      final games = [
        _game(players: ['Seezov'], roles: [_civ], cityWon: null),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].played, 0);
    });

    test('ignores games where the player is absent', () {
      final games = [
        _game(players: ['X', 'Y'], roles: [_civ, _maf], cityWon: true),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      for (final s in result) {
        expect(s.played, 0);
      }
    });

    test('counts a mafia (black-role) win when city loses', () {
      final games = [
        _game(players: ['Seezov', 'B', 'C'], roles: [_maf, _civ, _civ], cityWon: false),
      ];
      final result = winRateBySlotForPlayer(games, seezov);
      expect(result[0].played, 1);
      expect(result[0].wins, 1);
      expect(result[0].winRate, 1.0);
    });

    test('matches a player via a secondary nickname', () {
      final player = const Player(id: 1, displayName: 'Seezov', nicknames: ['Seezov', 'Seez']);
      final games = [
        _game(players: ['A', 'Seez', 'C'], roles: [_civ, _civ, _maf], cityWon: true),
      ];
      final result = winRateBySlotForPlayer(games, player);
      expect(result[1].slot, 2);
      expect(result[1].played, 1);
      expect(result[1].wins, 1);
    });
  });

  group('winRateBySlotGlobal', () {
    test('returns 10 slots numbered 1..10 in order', () {
      final result = winRateBySlotGlobal(const []);
      expect(result.map((s) => s.slot).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    });

    test('empty games => zeros', () {
      final result = winRateBySlotGlobal(const []);
      for (final s in result) {
        expect(s.played, 0);
        expect(s.wins, 0);
      }
    });

    test('counts every seat across rating games', () {
      final games = [
        _game(players: ['A', 'B', 'C'], roles: [_civ, _maf, _civ], cityWon: true),
        _game(players: ['D', 'E', 'F'], roles: [_civ, _maf, _civ], cityWon: false),
      ];
      final result = winRateBySlotGlobal(games);
      expect(result[0].played, 2);
      expect(result[0].wins, 1);
      expect(result[1].played, 2);
      expect(result[1].wins, 1);
      expect(result[2].played, 2);
      expect(result[2].wins, 1);
    });

    test('ignores non-rating games', () {
      final games = [
        _game(players: ['A', 'B'], roles: [_civ, _maf], cityWon: null),
      ];
      final result = winRateBySlotGlobal(games);
      for (final s in result) {
        expect(s.played, 0);
      }
    });
  });
}
