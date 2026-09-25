part of '../season_loader.dart';

// ── Role percentiles ─────────────────────────────────────────────────────

Map<int, Map<Role, double?>> _computeRolePercentiles(
    List<Player> players, List<Game> games) {
  // Build role stats for every valid player with kMinTotalGames+ rating games.
  // One pass over the games via a name → (player, name rank) index, instead of
  // scanning every game for every player (which froze the web UI for ~16 s).
  // In each game a player counts once, under the first of their names (in
  // nickname order) that appears in it.
  final validPlayers = <Player>[];
  final byName = <String, List<(int, int)>>{}; // name → (index in validPlayers, rank)
  for (final player in players) {
    if (player.displayName.trim().isEmpty) continue;
    if (player.nicknames != null && player.nicknames!.isEmpty) continue;
    if (const {'.', '..', '/'}.contains(player.displayName)) continue;

    final names = player.nicknames ?? [player.displayName];
    for (var rank = 0; rank < names.length; rank++) {
      (byName[names[rank]] ??= []).add((validPlayers.length, rank));
    }
    validPlayers.add(player);
  }

  final roleStats = [
    for (var i = 0; i < validPlayers.length; i++) <Role, ({int games, int wins})>{},
  ];
  final totalGames = List.filled(validPlayers.length, 0);

  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    // Player index → (rank, name) of their best-ranked name in this game.
    final matched = <int, (int, String)>{};
    for (final name in game.players.toSet()) {
      for (final (index, rank) in byName[name] ?? const <(int, int)>[]) {
        final best = matched[index];
        if (best == null || rank < best.$1) matched[index] = (rank, name);
      }
    }
    for (final MapEntry(key: index, value: (_, playerName)) in matched.entries) {
      totalGames[index]++;
      final role = Role.findByValue(game.getPlayerRole(playerName));
      if (role == null) continue;
      final prev = roleStats[index][role] ?? (games: 0, wins: 0);
      final won = game.hasPlayerWon(playerName) ? 1 : 0;
      roleStats[index][role] = (games: prev.games + 1, wins: prev.wins + won);
    }
  }

  final pool = <int, Map<Role, ({int games, int wins})>>{
    for (var i = 0; i < validPlayers.length; i++)
      if (totalGames[i] >= kMinTotalGames) validPlayers[i].id: roleStats[i],
  };

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
