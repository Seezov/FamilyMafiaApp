import 'package:family_mafia_app/models/player.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'rating_player_stats.freezed.dart';

@freezed
class RatingPlayerStats with _$RatingPlayerStats {
  const factory RatingPlayerStats({
    required int seasonId,
    required Player player,
    @Default(0.0) double ratingCoefficient,
    @Default(0) int wins,
    @Default(0) int gamesPlayed,
    @Default(0.0) double winRate,
    @Default(0.0) double additionalPoints,
    @Default(0.0) double penaltyPoints,
    @Default(0.0) double bestMovePoints,
    @Default(0) int firstKilled,
    @Default(0) int firstKilledCityLost,
    @Default(0.0) double percentOfDeath,
    @Default(0.0) double ciForGame,
    @Default(0.0) double ci,
    @Default(0.0) double mvp,
    // (roleSheetValue, count)
    @Default([]) List<(String, int)> winByRole,
    @Default([]) List<(String, int)> gamesForRole,
    @Default([]) List<(String, double)> bestMoveAndAdditionalPointsByRole,
    @Default([]) List<(String, double)> penaltyPointsByRole,
    @Default(0) int seasonGameLimit,
    @Default(0.0) double protocolPoints,
    @Default(0) int protocolCorrectGuesses,
    @Default(0) int protocolTotalGuesses,
  }) = _RatingPlayerStats;
}
