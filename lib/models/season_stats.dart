import 'package:family_mafia_app/models/rating_player_stats.dart';

class SeasonStats {
  final List<RatingPlayerStats> playerStats;

  /// Award rankings, best first, capped at [kAwardRankingSize]. Index 0 is the
  /// award's winner; the entries after it are the runners-up shown when a
  /// nomination is expanded. Empty when nobody qualified for the award.
  final List<int> mvpRanking;
  final List<int> bestSheriffRanking;
  final List<int> bestDonRanking;
  final List<int> bestCivilianRanking;
  final List<int> bestMafiaRanking;
  final List<int> mostKilledRanking;

  const SeasonStats({
    required this.playerStats,
    required this.mvpRanking,
    required this.bestSheriffRanking,
    required this.bestDonRanking,
    required this.bestCivilianRanking,
    required this.bestMafiaRanking,
    required this.mostKilledRanking,
  });

  static int _winner(List<int> ranking) =>
      ranking.isEmpty ? -1 : ranking.first;

  int get mvpPlayerId => _winner(mvpRanking);
  int get bestSheriffPlayerId => _winner(bestSheriffRanking);
  int get bestDonPlayerId => _winner(bestDonRanking);
  int get bestCivilianPlayerId => _winner(bestCivilianRanking);
  int get bestMafiaPlayerId => _winner(bestMafiaRanking);
  int get mostKilledPlayerId => _winner(mostKilledRanking);

  SeasonStats copyWith({List<RatingPlayerStats>? playerStats}) {
    return SeasonStats(
      playerStats: playerStats ?? this.playerStats,
      mvpRanking: mvpRanking,
      bestSheriffRanking: bestSheriffRanking,
      bestDonRanking: bestDonRanking,
      bestCivilianRanking: bestCivilianRanking,
      bestMafiaRanking: bestMafiaRanking,
      mostKilledRanking: mostKilledRanking,
    );
  }
}
