import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/html_export_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Win-rate stats for a single player slot (1..10).
typedef SlotWinRate = ({int slot, int played, int wins, double winRate});

/// Win-rate stats for one (slot, role) cell.
typedef RoleWinRate = ({int played, int wins, double winRate});

/// A slot row of the slot x role matrix: win rate per role for that seat.
typedef SlotRoleRow = ({int slot, Map<Role, RoleWinRate> cells});

/// Role columns of the matrix, in display order.
const kMatrixRoles = [Role.sheriff, Role.don, Role.civilian, Role.mafia];

/// Currently selected player on the stats screen. `null` => global stats.
final selectedPlayerProvider = StateProvider<Player?>((ref) => null);

List<SlotWinRate> _toSlots(List<int> played, List<int> wins) {
  return [
    for (var i = 0; i < 10; i++)
      (
        slot: i + 1,
        played: played[i],
        wins: wins[i],
        winRate: played[i] == 0 ? 0.0 : wins[i] / played[i],
      ),
  ];
}

/// Per-slot win rate across ALL players over rating, normal games. For each
/// seat index 0..9 with a non-empty name, counts the seat as played and a
/// win if that seat won.
List<SlotWinRate> winRateBySlotGlobal(List<Game> games) {
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    for (var i = 0; i < game.players.length && i < 10; i++) {
      final name = game.players[i];
      if (name.isEmpty) continue;
      played[i]++;
      if (game.hasPlayerWon(name)) wins[i]++;
    }
  }
  return _toSlots(played, wins);
}

/// Per-slot win rate for [player], matching any of the player's nicknames
/// (falling back to displayName) over the rating, normal games in [games].
List<SlotWinRate> winRateBySlotForPlayer(List<Game> games, Player player) {
  final names = player.nicknames ?? [player.displayName];
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    String? matched;
    for (final n in names) {
      if (game.players.contains(n)) {
        matched = n;
        break;
      }
    }
    if (matched == null) continue;
    final idx = game.getPlayerSlot(matched);
    if (idx < 0 || idx >= 10) continue;
    played[idx]++;
    if (game.hasPlayerWon(matched)) wins[idx]++;
  }
  return _toSlots(played, wins);
}

/// Per-slot win-rate stats. Global when no player is selected, otherwise for
/// the selected player. Recomputed when games or selection change.
final debugSlotWinRateProvider = Provider<List<SlotWinRate>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final player = ref.watch(selectedPlayerProvider);
  return player == null
      ? winRateBySlotGlobal(games)
      : winRateBySlotForPlayer(games, player);
});

List<Map<Role, int>> _emptyMatrix() =>
    [for (var i = 0; i < 10; i++) {for (final r in kMatrixRoles) r: 0}];

List<SlotRoleRow> _toRows(
  List<Map<Role, int>> played,
  List<Map<Role, int>> wins,
) {
  return [
    for (var i = 0; i < 10; i++)
      (
        slot: i + 1,
        cells: {
          for (final r in kMatrixRoles)
            r: (
              played: played[i][r]!,
              wins: wins[i][r]!,
              winRate: played[i][r]! == 0 ? 0.0 : wins[i][r]! / played[i][r]!,
            ),
        },
      ),
  ];
}

/// Slot x role win-rate matrix across ALL players over rating, normal games.
/// For each seat, tallies played/wins bucketed by the role held that seat.
List<SlotRoleRow> winRateBySlotRoleGlobal(List<Game> games) {
  final played = _emptyMatrix();
  final wins = _emptyMatrix();
  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    for (var i = 0; i < game.players.length && i < 10; i++) {
      final name = game.players[i];
      if (name.isEmpty || i >= game.roles.length) continue;
      final role = Role.findByValue(game.roles[i]);
      if (role == null) continue;
      played[i][role] = played[i][role]! + 1;
      if (game.hasPlayerWon(name)) wins[i][role] = wins[i][role]! + 1;
    }
  }
  return _toRows(played, wins);
}

/// Slot x role win-rate matrix for [player], matching any of the player's
/// nicknames (falling back to displayName) over the rating, normal games.
List<SlotRoleRow> winRateBySlotRoleForPlayer(List<Game> games, Player player) {
  final names = player.nicknames ?? [player.displayName];
  final played = _emptyMatrix();
  final wins = _emptyMatrix();
  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    String? matched;
    for (final n in names) {
      if (game.players.contains(n)) {
        matched = n;
        break;
      }
    }
    if (matched == null) continue;
    final idx = game.getPlayerSlot(matched);
    if (idx < 0 || idx >= 10) continue;
    final role = Role.findByValue(game.getPlayerRole(matched));
    if (role == null) continue;
    played[idx][role] = played[idx][role]! + 1;
    if (game.hasPlayerWon(matched)) wins[idx][role] = wins[idx][role]! + 1;
  }
  return _toRows(played, wins);
}

/// Slot x role win-rate matrix. Global when no player is selected, otherwise
/// for the selected player. Recomputed when games or selection change.
final debugSlotRoleProvider = Provider<List<SlotRoleRow>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final player = ref.watch(selectedPlayerProvider);
  return player == null
      ? winRateBySlotRoleGlobal(games)
      : winRateBySlotRoleForPlayer(games, player);
});

/// Assembles the HTML export payload: the global slot x role matrix plus every
/// player's matrix (for offline per-player search filtering). Players with no
/// games in any seat are omitted. All numbers are computed from live data.
final statsExportDataProvider = Provider<StatsExportData>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final players = ref.watch(playersListProvider);

  final playerMatrices = <PlayerMatrix>[];
  for (final p in players) {
    final matrix = winRateBySlotRoleForPlayer(games, p);
    final hasGames =
        matrix.any((row) => row.cells.values.any((c) => c.played > 0));
    if (hasGames) {
      playerMatrices.add((name: p.displayName, matrix: matrix));
    }
  }

  return (
    generatedAt: DateTime.now(),
    globalMatrix: winRateBySlotRoleGlobal(games),
    players: playerMatrices,
  );
});
