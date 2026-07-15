import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Win-rate stats for a single player slot (1..10).
typedef SlotWinRate = ({int slot, int played, int wins, double winRate});

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

/// Per-slot win rate across ALL players over rating games. For each seat
/// index 0..9 with a non-empty name, counts the seat as played and a win
/// if that seat won.
List<SlotWinRate> winRateBySlotGlobal(List<Game> games) {
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame()) continue;
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
/// (falling back to displayName) over the rating games in [games].
List<SlotWinRate> winRateBySlotForPlayer(List<Game> games, Player player) {
  final names = player.nicknames ?? [player.displayName];
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);
  for (final game in games) {
    if (!game.isRatingGame()) continue;
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
