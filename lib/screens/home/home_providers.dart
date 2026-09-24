import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which standing the season screen shows.
///
/// Main league: players who reached the season's `gameLimit`.
/// Small league: players between `smallLeagueMinGames` (inclusive) and
/// `gameLimit` (exclusive) — so a player on exactly `gameLimit` is main
/// league only and the two never overlap.
enum League { main, small }

/// The league currently shown on the season screen.
final selectedLeagueProvider = StateProvider<League>((ref) => League.main);

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

  return (
    games: allGames.length,
    players: allGames.getPlayersList(season.id).length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
    mafiaWR: decided > 0 ? mafiaWins / decided : 0.0,
  );
});

/// Returns the SeasonStats for the selected season, with players filtered
/// by the effective game limit and by the selected league (main vs. small).
final currentSeasonStatsProvider = Provider<SeasonStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;

  final seasonMap = ref.watch(seasonRepositoryProvider);
  final full = seasonMap[season.id];
  if (full == null) return null;

  final limit = ref.watch(effectiveGameLimitProvider);
  final league = ref.watch(selectedLeagueProvider);

  final filtered = switch (league) {
    League.main => full.playerStats.where((p) => p.gamesPlayed >= limit),
    League.small => full.playerStats.where((p) =>
        p.gamesPlayed >= season.smallLeagueMinGames && p.gamesPlayed < limit),
  };

  return full.copyWith(playerStats: filtered.toList());
});

/// Keeps the manual game-limit override from contradicting the league toggle.
///
/// Both control the same threshold, so the override only makes sense while the
/// main league is selected. Watched by [HomeScreen].
final leagueOverrideResetProvider = Provider<void>((ref) {
  ref.listen<League>(selectedLeagueProvider, (previous, next) {
    if (next == League.small) {
      ref.read(gameLimitOverrideProvider.notifier).state = null;
    }
  });
});

/// Canonical-name lookup built once from players.json.
final playerResolverProvider = Provider<PlayerResolver>(
  (ref) => PlayerResolver(ref.watch(playersRepositoryProvider)),
);

/// Main / small league head-counts for the selected season (default limits).
final seasonLeagueCountsProvider = Provider<({int main, int small})?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  if (season == null) return null;
  final full = ref.watch(seasonRepositoryProvider)[season.id];
  if (full == null) return null;
  return leagueCounts(full.playerStats, season);
});

/// Data for the Season Stats card, following the league toggle.
final seasonExtraStatsProvider = Provider<SeasonExtraStats?>((ref) {
  final season = ref.watch(selectedSeasonProvider);
  final stats = ref.watch(currentSeasonStatsProvider);
  if (season == null || stats == null) return null;
  final games = ref
      .watch(gamesRepositoryProvider)
      .where((g) => g.seasonId == season.id)
      .toList();
  return buildSeasonExtraStats(
    leaguePlayers: stats.playerStats,
    seasonGames: games,
    seasonTournaments: ref
        .watch(tournamentsProvider)
        .where((t) => t.seasonId == season.id)
        .toList(),
    resolver: ref.watch(playerResolverProvider),
  );
});
