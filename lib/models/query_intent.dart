sealed class QueryIntent {
  const QueryIntent();
}

class PlayerStatsIntent extends QueryIntent {
  final String playerQuery;
  final String? statType; // "games", "winrate", "rating", "role", null=overview
  final int? seasonId;
  const PlayerStatsIntent({required this.playerQuery, this.statType, this.seasonId});
}

class SeasonQueryIntent extends QueryIntent {
  final int seasonId;
  final String? questionType; // "winner", "mvp", "best_sheriff", "best_don", "best_civilian", "best_mafia", "stats", null=overview
  const SeasonQueryIntent({required this.seasonId, this.questionType});
}

class ComparePlayersIntent extends QueryIntent {
  final String player1Query;
  final String player2Query;
  const ComparePlayersIntent({required this.player1Query, required this.player2Query});
}

class LeaderboardIntent extends QueryIntent {
  final int topN;
  final String? category; // "overall", "sheriff", "don", "civilian", "mafia", "games", null=overall
  final int? seasonId;
  const LeaderboardIntent({this.topN = 5, this.category, this.seasonId});
}

class RecordIntent extends QueryIntent {
  final String recordType; // "most_games", "highest_rating", "best_winrate", "most_killed"
  const RecordIntent({required this.recordType});
}

class HelpIntent extends QueryIntent {
  const HelpIntent();
}

class UnknownIntent extends QueryIntent {
  final String originalQuery;
  const UnknownIntent({required this.originalQuery});
}
