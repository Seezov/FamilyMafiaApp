import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The player this debug screen reports on. Change here when inspecting
/// a different player.
const kDebugPlayer = 'Seezov';

/// Win-rate stats for a single player slot (1..10).
typedef SlotWinRate = ({int slot, int played, int wins, double winRate});

/// Computes win rate per player slot (slots 1..10) for [player] over the
/// rating games in [games] (games where `isRatingGame()` is true).
///
/// Slot index i (0..9) maps to displayed slot i + 1. Games where the player
/// is absent or in a slot >= 10 are skipped.
List<SlotWinRate> winRateBySlot(List<Game> games, String player) {
  final played = List<int>.filled(10, 0);
  final wins = List<int>.filled(10, 0);

  for (final game in games) {
    if (!game.isRatingGame()) continue;
    final idx = game.getPlayerSlot(player);
    if (idx < 0 || idx >= 10) continue;
    played[idx]++;
    if (game.hasPlayerWon(player)) wins[idx]++;
  }

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

/// Per-slot win-rate stats for [kDebugPlayer], recomputed when games change.
final debugSlotWinRateProvider = Provider<List<SlotWinRate>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  return winRateBySlot(games, kDebugPlayer);
});
