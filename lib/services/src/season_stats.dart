part of '../season_loader.dart';

// ── Season stats ─────────────────────────────────────────────────────────

/// How many players each season award lists: the winner plus three runners-up.
const kAwardRankingSize = 4;

SeasonStats _generateSeasonStats(List<RatingPlayerStats> sorted, int gameLimit) {
  final withLimit = sorted.where((p) {
    return p.gamesPlayed >= gameLimit;
  }).toList();

  List<int> byRole(Role role) =>
      rankPlayersForRole(withLimit, role).map((p) => p.player.id).toList();

  return SeasonStats(
    playerStats: sorted,
    mvpRanking: _rankBy(withLimit, (p) => p.mvp),
    mostKilledRanking: _rankBy(withLimit, (p) => p.firstKilled.toDouble()),
    bestSheriffRanking: byRole(Role.sheriff),
    bestDonRanking: byRole(Role.don),
    bestCivilianRanking: byRole(Role.civilian),
    bestMafiaRanking: byRole(Role.mafia),
  );
}

/// Ranks [players] by [score], highest first, and returns their ids.
List<int> _rankBy(
  List<RatingPlayerStats> players,
  double Function(RatingPlayerStats) score,
) {
  final ordered = [...players]
    ..sort((a, b) => score(b).compareTo(score(a)));
  return ordered.take(kAwardRankingSize).map((p) => p.player.id).toList();
}

/// The best [take] players for [role], best first.
///
/// Applies [findBestPlayerForRole] repeatedly, dropping each pick, so the first
/// entry is always the player that function would have chosen on its own and
/// the runners-up follow the same rule rather than a second, competing one.
List<RatingPlayerStats> rankPlayersForRole(
  List<RatingPlayerStats> players,
  Role role, {
  int take = kAwardRankingSize,
}) {
  final remaining = [...players];
  final ranking = <RatingPlayerStats>[];

  while (ranking.length < take) {
    final next = findBestPlayerForRole(remaining, role);
    if (next == null) break;
    ranking.add(next);
    remaining.removeWhere((p) => p.player.id == next.player.id);
  }

  return ranking;
}

RatingPlayerStats? findBestPlayerForRole(
    List<RatingPlayerStats> players, Role role) {
  final roleKey = role.sheetValue;

  final eligible = players.map((p) {
    final gamesForRole = p.gamesForRole
        .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0))
        .$2;
    final winsForRole = p.winByRole
        .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0))
        .$2;
    final pointsForRole = p.bestMoveAndAdditionalPointsByRole
        .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0.0))
        .$2;
    final gameLimit = p.seasonGameLimit * role.chanceToDraw;

    if (gamesForRole == 0 || gamesForRole < gameLimit) return null;

    final winRate = winsForRole / gamesForRole;
    final avgPoints = pointsForRole / gamesForRole;
    return (p, winRate, avgPoints);
  }).whereType<(RatingPlayerStats, double, double)>().toList();

  if (eligible.isEmpty) return null;

  final maxWinRate = eligible.map((e) => e.$2).reduce(max);

  return eligible
      .where((e) => e.$2 >= maxWinRate - 0.2)
      .reduce((a, b) {
        if ((a.$3 - b.$3).abs() > 1e-9) return a.$3 > b.$3 ? a : b;
        return a.$2 >= b.$2 ? a : b;
      })
      .$1;
}
