import 'package:family_mafia_app/models/player.dart';

class RatingPlayerStats {
  final int seasonId;
  final Player player;
  final double ratingCoefficient;
  final int wins;
  final int gamesPlayed;
  final double winRate;
  final double additionalPoints;
  final double penaltyPoints;
  final double bestMovePoints;
  final int firstKilled;
  final int firstKilledCityLost;
  final double percentOfDeath;
  final double ciForGame;
  final double ci;
  final double mvp;
  // (roleSheetValue, count)
  final List<(String, int)> winByRole;
  final List<(String, int)> gamesForRole;
  final List<(String, double)> bestMoveAndAdditionalPointsByRole;
  final List<(String, double)> penaltyPointsByRole;
  final int seasonGameLimit;

  const RatingPlayerStats({
    required this.seasonId,
    required this.player,
    this.ratingCoefficient = 0.0,
    this.wins = 0,
    this.gamesPlayed = 0,
    this.winRate = 0.0,
    this.additionalPoints = 0.0,
    this.penaltyPoints = 0.0,
    this.bestMovePoints = 0.0,
    this.firstKilled = 0,
    this.firstKilledCityLost = 0,
    this.percentOfDeath = 0.0,
    this.ciForGame = 0.0,
    this.ci = 0.0,
    this.mvp = 0.0,
    this.winByRole = const [],
    this.gamesForRole = const [],
    this.bestMoveAndAdditionalPointsByRole = const [],
    this.penaltyPointsByRole = const [],
    this.seasonGameLimit = 0,
  });

  RatingPlayerStats copyWith({
    int? seasonId,
    Player? player,
    double? ratingCoefficient,
    int? wins,
    int? gamesPlayed,
    double? winRate,
    double? additionalPoints,
    double? penaltyPoints,
    double? bestMovePoints,
    int? firstKilled,
    int? firstKilledCityLost,
    double? percentOfDeath,
    double? ciForGame,
    double? ci,
    double? mvp,
    List<(String, int)>? winByRole,
    List<(String, int)>? gamesForRole,
    List<(String, double)>? bestMoveAndAdditionalPointsByRole,
    List<(String, double)>? penaltyPointsByRole,
    int? seasonGameLimit,
  }) {
    return RatingPlayerStats(
      seasonId: seasonId ?? this.seasonId,
      player: player ?? this.player,
      ratingCoefficient: ratingCoefficient ?? this.ratingCoefficient,
      wins: wins ?? this.wins,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      winRate: winRate ?? this.winRate,
      additionalPoints: additionalPoints ?? this.additionalPoints,
      penaltyPoints: penaltyPoints ?? this.penaltyPoints,
      bestMovePoints: bestMovePoints ?? this.bestMovePoints,
      firstKilled: firstKilled ?? this.firstKilled,
      firstKilledCityLost: firstKilledCityLost ?? this.firstKilledCityLost,
      percentOfDeath: percentOfDeath ?? this.percentOfDeath,
      ciForGame: ciForGame ?? this.ciForGame,
      ci: ci ?? this.ci,
      mvp: mvp ?? this.mvp,
      winByRole: winByRole ?? this.winByRole,
      gamesForRole: gamesForRole ?? this.gamesForRole,
      bestMoveAndAdditionalPointsByRole: bestMoveAndAdditionalPointsByRole ??
          this.bestMoveAndAdditionalPointsByRole,
      penaltyPointsByRole: penaltyPointsByRole ?? this.penaltyPointsByRole,
      seasonGameLimit: seasonGameLimit ?? this.seasonGameLimit,
    );
  }
}
