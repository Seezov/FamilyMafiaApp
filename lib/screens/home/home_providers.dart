import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When non-null, overrides the season's gameLimit for filtering.
final gameLimitOverrideProvider = StateProvider<int?>((ref) => null);

/// The effective game limit: override if set, otherwise the season's default.
final effectiveGameLimitProvider = Provider<int>((ref) {
  final override = ref.watch(gameLimitOverrideProvider);
  final season = ref.watch(selectedSeasonProvider);
  return override ?? season?.gameLimit ?? 0;
});

/// Whether any players meet the season's *default* gameLimit.
final hasQualifyingPlayersProvider = Provider<bool>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return false;

  final seasonMap = ref.watch(seasonRepositoryProvider);
  final full = seasonMap[season.id];
  if (full == null) return false;

  return full.playerStats.any((p) => p.gamesPlayed >= season.gameLimit);
});

/// Aggregate stats for the season hero card.
final seasonSummaryProvider =
    Provider<({int games, int players, double cityWR, double mafiaWR})?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;
  final allGames = ref
      .watch(gamesRepositoryProvider)
      .where((g) => g.seasonId == season.id)
      .toList();
  if (allGames.isEmpty) return null;

  int cityWins = 0;
  int mafiaWins = 0;
  int decided = 0;
  for (final g in allGames) {
    if (g.cityWon == true) {
      cityWins++;
      decided++;
    } else if (g.cityWon == false) {
      mafiaWins++;
      decided++;
    }
  }

  final uniquePlayers = <String>{};
  for (final g in allGames) {
    uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));
  }

  return (
    games: allGames.length,
    players: uniquePlayers.length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
    mafiaWR: decided > 0 ? mafiaWins / decided : 0.0,
  );
});

/// Returns the SeasonStats for the selected season, with players filtered
/// by the effective game limit.
final currentSeasonStatsProvider = Provider<SeasonStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;

  final seasonMap = ref.watch(seasonRepositoryProvider);
  final full = seasonMap[season.id];
  if (full == null) return null;

  final limit = ref.watch(effectiveGameLimitProvider);

  return full.copyWith(
    playerStats: full.playerStats
        .where((p) => p.gamesPlayed >= limit)
        .toList(),
  );
});
