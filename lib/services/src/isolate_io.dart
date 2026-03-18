part of '../season_loader.dart';

// ── Background isolate I/O ──────────────────────────────────────────────────

/// Lightweight serializable struct for passing season metadata into an isolate.
class SeasonMeta {
  final int id;
  final int gameLimit;
  final double gamesMultiplier;

  const SeasonMeta(this.id, this.gameLimit, this.gamesMultiplier);
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

  const _LoadOutput({
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

  const _PartialLoadOutput({
    required this.players,
    required this.allGames,
    required this.ratingsBySeason,
    required this.statsBySeason,
  });
}

class _PercentilesInput {
  final String playersJson;
  final List<String> seasonJsons;
  final List<SeasonMeta> seasonMetas;

  const _PercentilesInput(this.playersJson, this.seasonJsons, this.seasonMetas);
}
