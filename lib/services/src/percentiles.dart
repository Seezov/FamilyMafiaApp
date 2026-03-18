part of '../season_loader.dart';

// ── Role percentiles ─────────────────────────────────────────────────────

Map<int, Map<Role, double?>> _computeRolePercentiles(
    List<Player> players, List<Game> games) {
  // Build role stats for every valid player with kMinTotalGames+ rating games
  final pool = <int, Map<Role, ({int games, int wins})>>{};
  for (final player in players) {
    if (player.displayName.trim().isEmpty) continue;
    if (player.nicknames != null && player.nicknames!.isEmpty) continue;
    if (const {'.', '..', '/'}.contains(player.displayName)) continue;

    final names = player.nicknames ?? [player.displayName];
    final Map<Role, ({int games, int wins})> roleStats = {};
    int totalGames = 0;

    for (final game in games) {
      if (!game.isRatingGame() || !game.isNormalGame()) continue;
      String? playerName;
      for (final n in names) {
        if (game.players.contains(n)) {
          playerName = n;
          break;
        }
      }
      if (playerName == null) continue;
      totalGames++;
      final role = Role.findByValue(game.getPlayerRole(playerName));
      if (role == null) continue;
      final prev = roleStats[role] ?? (games: 0, wins: 0);
      final won = game.hasPlayerWon(playerName) ? 1 : 0;
      roleStats[role] = (games: prev.games + 1, wins: prev.wins + won);
    }

    if (totalGames >= kMinTotalGames) pool[player.id] = roleStats;
  }

  // Pre-sort WR lists per role once instead of per-player
  final sortedWrsByRole = <Role, List<double>>{};
  for (final role in Role.values) {
    sortedWrsByRole[role] = pool.values
        .map((m) => m[role])
        .whereType<({int games, int wins})>()
        .where((s) => s.games >= kMinRoleGames)
        .map((s) => s.wins / s.games)
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  // Compute percentile per player per role
  final result = <int, Map<Role, double?>>{};
  for (final entry in pool.entries) {
    final myStats = entry.value;
    final Map<Role, double?> percentiles = {};

    for (final role in Role.values) {
      final myRoleStats = myStats[role];
      if (myRoleStats == null || myRoleStats.games < kMinRoleGames) {
        percentiles[role] = null;
        continue;
      }
      final myWr = myRoleStats.wins / myRoleStats.games;
      final poolWrs = sortedWrsByRole[role]!;

      if (poolWrs.isEmpty) {
        percentiles[role] = null;
        continue;
      }

      final rank = poolWrs.indexWhere((wr) => wr <= myWr) + 1;
      final exact = rank / poolWrs.length * 100;

      double snapped;
      if (exact < 1) {
        snapped = (exact * 10).round() / 10.0;
        if (snapped == 0) snapped = 0.1;
      } else {
        snapped = exact.round().toDouble();
        if (snapped == 0) snapped = 1;
      }
      percentiles[role] = snapped;
    }
    result[entry.key] = percentiles;
  }

  return result;
}
