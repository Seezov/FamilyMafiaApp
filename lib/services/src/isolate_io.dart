part of '../season_loader.dart';

// ── Background isolate I/O ──────────────────────────────────────────────────

/// Lightweight serializable struct for passing season metadata into an isolate.
class SeasonMeta {
  final int id;
  final int gameLimit;
  final double gamesMultiplier;
  final GameLimitRule rule;

  /// Whether [gameLimit] is a set value (for a top3 season: the admin's
  /// final value); a top3 season without one passes 0 and false.
  final bool gameLimitSet;

  /// The clock for [seasonInProgress]; null = now.
  final DateTime? now;

  const SeasonMeta(this.id, this.gameLimit, this.gamesMultiplier,
      {this.rule = GameLimitRule.fixed, this.gameLimitSet = true, this.now});

  SeasonMeta withGameLimit(int limit) => SeasonMeta(id, limit, gamesMultiplier,
      rule: rule, gameLimitSet: gameLimitSet, now: now);
}

class _LoadInput {
  final String playersJson;
  final List<String> seasonJsons;
  final List<SeasonMeta> seasonMetas;

  const _LoadInput(this.playersJson, this.seasonJsons, this.seasonMetas);
}

class _LoadOutput {
  final List<Player> players;
  final List<Game> allGames;
  final Map<int, List<RatingPlayerStats>> ratingsBySeason;
  final Map<int, SeasonStats> statsBySeason;
  final Map<int, Map<Role, double?>> percentiles;
  final Map<int, SeasonThreshold> thresholds;

  const _LoadOutput({
    required this.thresholds,
    required this.players,
    required this.allGames,
    required this.ratingsBySeason,
    required this.statsBySeason,
    required this.percentiles,
  });
}

/// Like _LoadOutput but without percentiles (used for incremental loading).
class _PartialLoadOutput {
  final List<Player> players;
  final List<Game> allGames;
  final Map<int, List<RatingPlayerStats>> ratingsBySeason;
  final Map<int, SeasonStats> statsBySeason;
  final Map<int, SeasonThreshold> thresholds;

  const _PartialLoadOutput({
    required this.thresholds,
    required this.players,
    required this.allGames,
    required this.ratingsBySeason,
    required this.statsBySeason,
  });
}

