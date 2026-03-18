part of '../season_loader.dart';

// ── Season stats ─────────────────────────────────────────────────────────

SeasonStats _generateSeasonStats(List<RatingPlayerStats> sorted, int gameLimit) {
  final withLimit = sorted.where((p) {
    return p.gamesPlayed >= gameLimit;
  }).toList();

  return SeasonStats(
    playerStats: sorted,
    mvpPlayerId:
        withLimit.maxByOrNull((p) => p.mvp)?.player.id ?? -1,
    mostKilledPlayerId:
        withLimit.maxByOrNull((p) => p.firstKilled.toDouble())?.player.id ?? -1,
    bestSheriffPlayerId:
        findBestPlayerForRole(withLimit, Role.sheriff)?.player.id ?? -1,
    bestDonPlayerId:
        findBestPlayerForRole(withLimit, Role.don)?.player.id ?? -1,
    bestCivilianPlayerId:
        findBestPlayerForRole(withLimit, Role.civilian)?.player.id ?? -1,
    bestMafiaPlayerId:
        findBestPlayerForRole(withLimit, Role.mafia)?.player.id ?? -1,
  );
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
