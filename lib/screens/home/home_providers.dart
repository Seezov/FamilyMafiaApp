import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedSeasonProvider = StateProvider<Season?>((ref) => null);

/// Returns the SeasonStats for the selected season, with players filtered
/// to those meeting the season's gameLimit — mirrors HomeViewModel.displaySeason().
final currentSeasonStatsProvider = Provider<SeasonStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;

  final seasonMap = ref.watch(seasonRepositoryProvider);
  final full = seasonMap[season.id];
  if (full == null) return null;

  return full.copyWith(
    playerStats: full.playerStats
        .where((p) => p.gamesPlayed >= season.gameLimit)
        .toList(),
  );
});
