part of '../season_loader.dart';

// ── Per-player rating computation ────────────────────────────────────────

Player _findPlayer(String name, List<Player> players) {
  return players.firstWhere(
    (p) =>
        p.displayName == name ||
        (p.nicknames?.contains(name) ?? false),
    orElse: () => Player(id: -1, displayName: name),
  );
}

RatingPlayerStats _computePlayerRating(
    String name, List<Game> gamesData, SeasonMeta season, List<Player> players) {
  final gamesForPlayer =
      gamesData.where((g) => g.players.contains(name)).toList();
  final gamesPlayed = gamesForPlayer.length;

  if (gamesPlayed == 0) {
    return RatingPlayerStats(
      seasonId: season.id,
      player: _findPlayer(name, players),
    );
  }

  // Single-pass accumulation over all games for this player.
  // Keyed by canonical role.sheetValue to normalize Ukrainian/Russian variants.
  ({int wins, int losses, double additional, double penalty, double bestMovePoints, int games}) emptyAcc() =>
      (wins: 0, losses: 0, additional: 0.0, penalty: 0.0, bestMovePoints: 0.0, games: 0);

  final Map<String, ({int wins, int losses, double additional, double penalty, double bestMovePoints, int games})>
      roleAcc = {};
  int firstKilled = 0;
  int firstKilledCityLost = 0;
  double autoAdditionalPointsByRoleSum = 0.0;
  double protocolPointsSum = 0.0;
  int protocolCorrectGuesses = 0;
  int protocolTotalGuesses = 0;

  for (final g in gamesForPlayer) {
    final rawRole = g.getPlayerRole(name);
    final roleVal = Role.findByValue(rawRole)?.sheetValue ?? rawRole;
    final won = g.hasPlayerWon(name);
    final isFK = g.isFirstKilled(name);
    final prev = roleAcc[roleVal] ?? emptyAcc();
    roleAcc[roleVal] = (
      wins: prev.wins + (won ? 1 : 0),
      losses: prev.losses + (won ? 0 : 1),
      additional: prev.additional
          + g.getPlayerAdditionalPoints(name)
          + g.getPlayerProtocolAdditionalPoints(name),
      penalty: prev.penalty
          + g.getPlayerPenaltyPoints(name)
          + g.getPlayerProtocolPenaltyPoints(name),
      bestMovePoints: prev.bestMovePoints + (isFK ? g.bestMovePoints : 0.0),
      games: prev.games + 1,
    );
    if (isFK) {
      firstKilled++;
      if (!won) firstKilledCityLost++;
    }
    autoAdditionalPointsByRoleSum += g.getPlayerAutoAdditionalPoints(name);

    // Protocol stats (season 29+)
    protocolPointsSum += g.getPlayerProtocolAdditionalPoints(name)
        + g.getPlayerProtocolPenaltyPoints(name);

    final slot = g.players.indexOf(name) + 1;
    final entry = g.getProtocolEntryForSlot(slot);
    if (entry != null) {
      for (final guess in entry.colorGuesses) {
        protocolTotalGuesses++;
        final guessedSlot = guess.abs();
        if (guessedSlot < 1 || guessedSlot > g.roles.length) continue;
        final actualRole = Role.findByValue(g.roles[guessedSlot - 1]);
        if (actualRole == null) continue;
        final guessedBlack = guess < 0;
        if (guessedBlack == actualRole.isBlack) protocolCorrectGuesses++;
      }
    }
  }

  // Derive per-role lists from accumulator (O(4 roles)).
  final gamesForRole = Role.values
      .map((r) => (r.sheetValue, roleAcc[r.sheetValue]?.games ?? 0))
      .toList();
  final winByRole = Role.values
      .map((r) => (r.sheetValue, roleAcc[r.sheetValue]?.wins ?? 0))
      .toList();
  final loseByRole = Role.values
      .map((r) => (r.sheetValue, roleAcc[r.sheetValue]?.losses ?? 0))
      .toList();
  final additionalPointsByRole = Role.values
      .map((r) => (r.sheetValue, roleAcc[r.sheetValue]?.additional ?? 0.0))
      .toList();
  final penaltyPointsByRole = Role.values
      .map((r) => (r.sheetValue, roleAcc[r.sheetValue]?.penalty ?? 0.0))
      .toList();
  final bestMoveAndAdditionalPointsByRole = Role.values.map((r) {
    final acc = roleAcc[r.sheetValue];
    if (acc == null) return (r.sheetValue, 0.0);
    return (r.sheetValue, acc.additional + acc.bestMovePoints + acc.penalty);
  }).toList();

  final additionalPointsByRoleSum =
      additionalPointsByRole.sumOfDouble((e) => e.$2);
  final penaltyPointsByRoleSum =
      penaltyPointsByRole.sumOfDouble((e) => e.$2);
  final bestMovePointsByRoleSum =
      bestMoveAndAdditionalPointsByRole.sumOfDouble((e) => e.$2) -
          additionalPointsByRoleSum -
          penaltyPointsByRoleSum;

  final gamesAsRed = (roleAcc[Role.sheriff.sheetValue]?.games ?? 0) +
      (roleAcc[Role.civilian.sheetValue]?.games ?? 0);

  final wins = winByRole.sumOfInt((e) => e.$2);

  final winByRoleSum = winByRole.sumOfInt((e) =>
      calculateWinByRole(season.id, e.$1, e.$2));

  final loseByRoleSum = loseByRole.sumOfInt((e) =>
      isDonOrSheriff(e.$1) ? e.$2 : 0);

  final ciForGame = calculateCiForGame(
      firstKilledCityLost, firstKilled, gamesPlayed, season.id);
  final ci = ciForGame * firstKilledCityLost;

  final percentOfDeath =
      gamesAsRed > 0 ? firstKilled / gamesAsRed : 0.0;
  final winRate = wins / gamesPlayed;

  final winPoints = calculateWinPoints(
    season.id,
    additionalPointsByRoleSum,
    bestMovePointsByRoleSum,
    penaltyPointsByRoleSum,
    ci,
    autoAdditionalPointsByRoleSum,
    winByRoleSum,
    loseByRoleSum,
  );

  final mvp = calculateMvp(
    season.id,
    gamesPlayed,
    additionalPointsByRoleSum,
    bestMovePointsByRoleSum,
    penaltyPointsByRoleSum,
    winPoints,
  );

  final ratingCoefficient = calculateRatingCoefficient(
    player: name,
    winPoints: winPoints,
    gamesPlayed: gamesPlayed,
    winRate: winRate,
    ci: ci,
    bestMovePoints: bestMovePointsByRoleSum,
    additionalPoints: additionalPointsByRoleSum,
    penaltyPoints: penaltyPointsByRoleSum,
    autoAdditionalPoints: autoAdditionalPointsByRoleSum,
    season: season,
  );

  return RatingPlayerStats(
    seasonId: season.id,
    player: _findPlayer(name, players),
    ratingCoefficient: ratingCoefficient,
    wins: wins,
    gamesPlayed: gamesPlayed,
    winRate: winRate,
    additionalPoints: additionalPointsByRoleSum,
    penaltyPoints: penaltyPointsByRoleSum,
    bestMovePoints: bestMovePointsByRoleSum,
    firstKilled: firstKilled,
    firstKilledCityLost: firstKilledCityLost,
    percentOfDeath: percentOfDeath,
    ciForGame: ciForGame,
    ci: ci,
    mvp: mvp,
    winByRole: winByRole,
    gamesForRole: gamesForRole,
    bestMoveAndAdditionalPointsByRole: bestMoveAndAdditionalPointsByRole,
    penaltyPointsByRole: penaltyPointsByRole,
    seasonGameLimit: season.gameLimit,
    protocolPoints: protocolPointsSum,
    protocolCorrectGuesses: protocolCorrectGuesses,
    protocolTotalGuesses: protocolTotalGuesses,
  );
}
