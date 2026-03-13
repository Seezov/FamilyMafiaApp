import 'package:family_mafia_app/models/rating_player_stats.dart';

class SeasonStats {
  final List<RatingPlayerStats> playerStats;
  final int mvpPlayerId;
  final int bestSheriffPlayerId;
  final int bestDonPlayerId;
  final int bestCivilianPlayerId;
  final int bestMafiaPlayerId;
  final int mostKilledPlayerId;

  const SeasonStats({
    required this.playerStats,
    required this.mvpPlayerId,
    required this.bestSheriffPlayerId,
    required this.bestDonPlayerId,
    required this.bestCivilianPlayerId,
    required this.bestMafiaPlayerId,
    required this.mostKilledPlayerId,
  });

  SeasonStats copyWith({List<RatingPlayerStats>? playerStats}) {
    return SeasonStats(
      playerStats: playerStats ?? this.playerStats,
      mvpPlayerId: mvpPlayerId,
      bestSheriffPlayerId: bestSheriffPlayerId,
      bestDonPlayerId: bestDonPlayerId,
      bestCivilianPlayerId: bestCivilianPlayerId,
      bestMafiaPlayerId: bestMafiaPlayerId,
      mostKilledPlayerId: mostKilledPlayerId,
    );
  }
}
