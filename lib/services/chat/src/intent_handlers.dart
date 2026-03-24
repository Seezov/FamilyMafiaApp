part of '../chat_engine.dart';

typedef _ChatResponse = ({String text, List<String> suggestions});

extension _IntentHandlers on ChatEngine {
  _ChatResponse _handleIntent(QueryIntent intent) {
    return switch (intent) {
      PlayerStatsIntent i => _handlePlayerStats(i),
      SeasonQueryIntent i => _handleSeasonQuery(i),
      ComparePlayersIntent i => _handleCompare(i),
      LeaderboardIntent i => _handleLeaderboard(i),
      RecordIntent i => _handleRecord(i),
      HelpIntent() => _handleHelp(),
      UnknownIntent i => _handleUnknown(i),
    };
  }

  // ── Player Stats ──────────────────────────────────────────────────────

  _ChatResponse _handlePlayerStats(PlayerStatsIntent intent) {
    final candidates = resolvePlayerCandidates(intent.playerQuery);
    if (candidates.isEmpty) {
      return (
        text: 'I couldn\'t find a player matching "${intent.playerQuery}". Check the spelling or try a different name.',
        suggestions: ['Top 5 players', 'Help'],
      );
    }
    if (candidates.length > 1 && candidates.first.displayName.toLowerCase() != intent.playerQuery.toLowerCase()) {
      final names = candidates.take(5).map((p) => p.displayName).toList();
      return (
        text: 'Multiple matches for "${intent.playerQuery}": ${names.join(", ")}.\nPlease be more specific.',
        suggestions: names.map((n) => '$n stats').toList(),
      );
    }

    final player = candidates.first;

    // Season-specific stats
    if (intent.seasonId != null) {
      return _playerSeasonStats(player, intent.seasonId!);
    }

    // All-time overview
    return _playerOverview(player, intent.statType);
  }

  _ChatResponse _playerOverview(Player player, String? statType) {
    int totalGames = 0;
    int totalWins = 0;
    double latestRating = 0;
    int latestSeason = -1;
    final roleGames = <String, int>{};
    final roleWins = <String, int>{};
    int seasonsPlayed = 0;

    for (final entry in ratings.entries) {
      final stats = entry.value.where((r) => r.player.id == player.id).firstOrNull;
      if (stats == null || stats.gamesPlayed == 0) continue;
      seasonsPlayed++;
      totalGames += stats.gamesPlayed;
      totalWins += stats.wins;
      if (entry.key > latestSeason) {
        latestSeason = entry.key;
        latestRating = stats.ratingCoefficient;
      }
      for (final (rv, c) in stats.gamesForRole) {
        roleGames[rv] = (roleGames[rv] ?? 0) + c;
      }
      for (final (rv, w) in stats.winByRole) {
        roleWins[rv] = (roleWins[rv] ?? 0) + w;
      }
    }

    if (totalGames == 0) {
      return (
        text: '${player.displayName} has no recorded games.',
        suggestions: ['Top 5 players', 'Help'],
      );
    }

    final winRate = (totalWins / totalGames * 100).roundTo(1);
    final buf = StringBuffer('${player.displayName}\n');
    buf.writeln('─' * 20);
    buf.writeln('Seasons played: $seasonsPlayed');
    buf.writeln('Total games: $totalGames');
    buf.writeln('Wins: $totalWins ($winRate%)');
    if (latestSeason >= 0) {
      buf.writeln('Latest rating (S$latestSeason): ${latestRating.roundTo(2)}');
    }

    // Role breakdown
    if (statType == 'role' || statType == null) {
      buf.writeln('');
      buf.writeln('Roles:');
      for (final role in Role.values) {
        final g = roleGames[role.sheetValue] ?? 0;
        final w = roleWins[role.sheetValue] ?? 0;
        if (g == 0) continue;
        final wr = (w / g * 100).roundTo(1);
        buf.writeln('  ${role.name.toUpperCase()}: $g games, $w wins ($wr%)');
      }
    }

    // Find best role
    String? bestRole;
    double bestWR = -1;
    for (final role in Role.values) {
      final g = roleGames[role.sheetValue] ?? 0;
      final w = roleWins[role.sheetValue] ?? 0;
      if (g >= 5) {
        final wr = w / g;
        if (wr > bestWR) {
          bestWR = wr;
          bestRole = role.name;
        }
      }
    }

    return (
      text: buf.toString().trimRight(),
      suggestions: [
        if (latestSeason >= 0) '${player.displayName} season $latestSeason',
        'Compare ${player.displayName} and ...',
        if (bestRole != null) 'Best ${bestRole}s',
        'Top 5 players',
      ],
    );
  }

  _ChatResponse _playerSeasonStats(Player player, int seasonId) {
    final seasonRatings = ratings[seasonId];
    if (seasonRatings == null) {
      return (
        text: 'No data for season $seasonId.',
        suggestions: ['${player.displayName} stats', 'Help'],
      );
    }

    final stats = seasonRatings.where((r) => r.player.id == player.id).firstOrNull;
    if (stats == null || stats.gamesPlayed == 0) {
      return (
        text: '${player.displayName} didn\'t play in season $seasonId.',
        suggestions: ['${player.displayName} stats', 'Season $seasonId stats'],
      );
    }

    final config = configs.where((c) => c.id == seasonId).firstOrNull;
    final qualified = config != null && stats.gamesPlayed >= config.gameLimit;

    // Find rank
    final sorted = seasonRatings
        .where((r) => config == null || r.gamesPlayed >= config.gameLimit)
        .toList()
      ..sort((a, b) => b.ratingCoefficient.compareTo(a.ratingCoefficient));
    final rank = sorted.indexWhere((r) => r.player.id == player.id) + 1;

    final buf = StringBuffer('${player.displayName} — Season $seasonId\n');
    buf.writeln('─' * 20);
    buf.writeln('Rating: ${stats.ratingCoefficient.roundTo(2)}${qualified && rank > 0 ? " (#$rank)" : " (unranked)"}');
    buf.writeln('Games: ${stats.gamesPlayed}${config != null ? " / ${config.gameLimit} needed" : ""}');
    buf.writeln('Wins: ${stats.wins} (${(stats.winRate * 100).roundTo(1)}%)');
    buf.writeln('Add. points: ${stats.additionalPoints.roundTo(2)}');
    buf.writeln('Penalty: ${stats.penaltyPoints.roundTo(2)}');
    buf.writeln('Best move: ${stats.bestMovePoints.roundTo(2)}');
    buf.writeln('First killed: ${stats.firstKilled} times');

    return (
      text: buf.toString().trimRight(),
      suggestions: [
        '${player.displayName} stats',
        'Who won season $seasonId?',
        'Season $seasonId stats',
      ],
    );
  }

  // ── Season Query ──────────────────────────────────────────────────────

  _ChatResponse _handleSeasonQuery(SeasonQueryIntent intent) {
    final sid = intent.seasonId;
    final seasonStats = seasons[sid];
    final config = configs.where((c) => c.id == sid).firstOrNull;

    if (seasonStats == null) {
      return (
        text: 'No data for season $sid.',
        suggestions: configs.take(3).map((c) => 'Season ${c.id} stats').toList(),
      );
    }

    final qType = intent.questionType;

    // Winner
    if (qType == 'winner') {
      final qualified = seasonStats.playerStats
          .where((p) => config == null || p.gamesPlayed >= config.gameLimit)
          .toList();
      if (qualified.isEmpty) {
        return (text: 'No qualified players in season $sid.', suggestions: ['Season $sid stats']);
      }
      final winner = qualified.first;
      return (
        text: 'Season $sid winner: ${winner.player.displayName} (rating: ${winner.ratingCoefficient.roundTo(2)}, ${winner.gamesPlayed} games, ${(winner.winRate * 100).roundTo(1)}% WR)',
        suggestions: ['${winner.player.displayName} stats', 'Season $sid stats', 'MVP season $sid'],
      );
    }

    // MVP / role awards
    if (qType == 'mvp' || qType?.startsWith('best_') == true) {
      final playerId = switch (qType) {
        'mvp' => seasonStats.mvpPlayerId,
        'best_sheriff' => seasonStats.bestSheriffPlayerId,
        'best_don' => seasonStats.bestDonPlayerId,
        'best_civilian' => seasonStats.bestCivilianPlayerId,
        'best_mafia' => seasonStats.bestMafiaPlayerId,
        _ => seasonStats.mvpPlayerId,
      };
      final player = players.where((p) => p.id == playerId).firstOrNull;
      final label = switch (qType) {
        'mvp' => 'MVP',
        'best_sheriff' => 'Best Sheriff',
        'best_don' => 'Best Don',
        'best_civilian' => 'Best Civilian',
        'best_mafia' => 'Best Mafia',
        _ => 'MVP',
      };
      if (player == null) {
        return (text: 'Could not find the $label for season $sid.', suggestions: ['Season $sid stats']);
      }
      return (
        text: 'Season $sid $label: ${player.displayName}',
        suggestions: ['${player.displayName} season $sid', 'Season $sid stats', 'Who won season $sid?'],
      );
    }

    // Season overview
    return _seasonOverview(sid, seasonStats, config);
  }

  _ChatResponse _seasonOverview(int sid, SeasonStats seasonStats, SeasonConfig? config) {
    final seasonGames = games.where((g) => g.seasonId == sid).toList();
    final ratingGames = seasonGames.where((g) => g.isRatingGame()).toList();
    int cityWins = 0;
    int decided = 0;
    for (final g in seasonGames) {
      if (g.cityWon == true) { cityWins++; decided++; }
      else if (g.cityWon == false) { decided++; }
    }
    final cityWR = decided > 0 ? (cityWins / decided * 100).roundTo(1) : 0.0;
    final mafiaWR = decided > 0 ? ((decided - cityWins) / decided * 100).roundTo(1) : 0.0;
    final uniquePlayers = <String>{};
    for (final g in seasonGames) {
      uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));
    }

    final qualified = seasonStats.playerStats
        .where((p) => config == null || p.gamesPlayed >= config.gameLimit)
        .toList();
    final winner = qualified.isNotEmpty ? qualified.first : null;

    final mvpPlayer = players.where((p) => p.id == seasonStats.mvpPlayerId).firstOrNull;

    final buf = StringBuffer('Season $sid${config != null ? " — ${config.title}" : ""}\n');
    buf.writeln('─' * 20);
    buf.writeln('Total games: ${seasonGames.length} (${ratingGames.length} rating)');
    buf.writeln('Players: ${uniquePlayers.length}');
    if (config != null) buf.writeln('Game limit: ${config.gameLimit}');
    buf.writeln('City win rate: $cityWR%');
    buf.writeln('Mafia win rate: $mafiaWR%');
    if (winner != null) {
      buf.writeln('Winner: ${winner.player.displayName} (${winner.ratingCoefficient.roundTo(2)})');
    }
    if (mvpPlayer != null) buf.writeln('MVP: ${mvpPlayer.displayName}');

    return (
      text: buf.toString().trimRight(),
      suggestions: [
        'Who won season $sid?',
        'MVP season $sid',
        if (winner != null) '${winner.player.displayName} stats',
        'Top 5 players',
      ],
    );
  }

  // ── Compare ───────────────────────────────────────────────────────────

  _ChatResponse _handleCompare(ComparePlayersIntent intent) {
    final p1 = resolvePlayer(intent.player1Query);
    final p2 = resolvePlayer(intent.player2Query);

    if (p1 == null || p2 == null) {
      final missing = <String>[];
      if (p1 == null) missing.add(intent.player1Query);
      if (p2 == null) missing.add(intent.player2Query);
      return (
        text: 'Could not find: ${missing.join(", ")}',
        suggestions: ['Top 5 players', 'Help'],
      );
    }

    final s1 = _aggregatePlayer(p1);
    final s2 = _aggregatePlayer(p2);

    final buf = StringBuffer('${p1.displayName} vs ${p2.displayName}\n');
    buf.writeln('─' * 30);
    buf.writeln('${"".padRight(14)} ${p1.displayName.padRight(12)} ${p2.displayName}');
    buf.writeln('Games:         ${s1.games.toString().padRight(12)} ${s2.games}');
    buf.writeln('Wins:          ${s1.wins.toString().padRight(12)} ${s2.wins}');
    buf.writeln('Win rate:      ${"${s1.winRate}%".padRight(12)} ${s2.winRate}%');
    buf.writeln('Seasons:       ${s1.seasons.toString().padRight(12)} ${s2.seasons}');
    if (s1.latestRating != null || s2.latestRating != null) {
      final r1 = s1.latestRating?.roundTo(2).toString() ?? '-';
      final r2 = s2.latestRating?.roundTo(2).toString() ?? '-';
      buf.writeln('Latest rating: ${r1.padRight(12)} $r2');
    }

    return (
      text: buf.toString().trimRight(),
      suggestions: [
        '${p1.displayName} stats',
        '${p2.displayName} stats',
        'Top 5 players',
      ],
    );
  }

  ({int games, int wins, double winRate, int seasons, double? latestRating}) _aggregatePlayer(Player player) {
    int totalGames = 0, totalWins = 0, seasonsPlayed = 0;
    double? latestRating;
    int latestSeason = -1;

    for (final entry in ratings.entries) {
      final stats = entry.value.where((r) => r.player.id == player.id).firstOrNull;
      if (stats == null || stats.gamesPlayed == 0) continue;
      seasonsPlayed++;
      totalGames += stats.gamesPlayed;
      totalWins += stats.wins;
      if (entry.key > latestSeason) {
        latestSeason = entry.key;
        latestRating = stats.ratingCoefficient;
      }
    }

    return (
      games: totalGames,
      wins: totalWins,
      winRate: totalGames > 0 ? (totalWins / totalGames * 100).roundTo(1) : 0.0,
      seasons: seasonsPlayed,
      latestRating: latestRating,
    );
  }

  // ── Leaderboard ───────────────────────────────────────────────────────

  _ChatResponse _handleLeaderboard(LeaderboardIntent intent) {
    final n = intent.topN.clamp(1, 20);
    final cat = intent.category ?? 'overall';

    if (cat == 'games') return _leaderboardByGames(n);
    if (cat == 'overall') return _leaderboardOverall(n, intent.seasonId);

    // Role leaderboard
    final role = switch (cat) {
      'sheriff' => Role.sheriff,
      'don' => Role.don,
      'civilian' => Role.civilian,
      'mafia' => Role.mafia,
      _ => null,
    };
    if (role != null) return _leaderboardByRole(n, role);
    return _leaderboardOverall(n, intent.seasonId);
  }

  _ChatResponse _leaderboardOverall(int n, int? seasonId) {
    if (seasonId != null) {
      final seasonRatings = ratings[seasonId];
      final config = configs.where((c) => c.id == seasonId).firstOrNull;
      if (seasonRatings == null) {
        return (text: 'No data for season $seasonId.', suggestions: ['Help']);
      }
      final qualified = seasonRatings
          .where((r) => config == null || r.gamesPlayed >= config.gameLimit)
          .toList()
        ..sort((a, b) => b.ratingCoefficient.compareTo(a.ratingCoefficient));

      final top = qualified.take(n).toList();
      final buf = StringBuffer('Top $n — Season $seasonId\n');
      buf.writeln('─' * 20);
      for (int i = 0; i < top.length; i++) {
        buf.writeln('${i + 1}. ${top[i].player.displayName} — ${top[i].ratingCoefficient.roundTo(2)} (${(top[i].winRate * 100).roundTo(1)}% WR)');
      }
      return (
        text: buf.toString().trimRight(),
        suggestions: [
          if (top.isNotEmpty) '${top.first.player.displayName} season $seasonId',
          'Season $seasonId stats',
          'Top $n players',
        ],
      );
    }

    // All-time by win rate (with min games)
    final aggregated = <int, ({Player player, int games, int wins})>{};
    for (final seasonStats in ratings.values) {
      for (final ps in seasonStats) {
        final prev = aggregated[ps.player.id];
        if (prev != null) {
          aggregated[ps.player.id] = (player: ps.player, games: prev.games + ps.gamesPlayed, wins: prev.wins + ps.wins);
        } else {
          aggregated[ps.player.id] = (player: ps.player, games: ps.gamesPlayed, wins: ps.wins);
        }
      }
    }

    final entries = aggregated.values
        .where((e) => e.games >= 20)
        .toList()
      ..sort((a, b) {
        final wrA = a.wins / a.games;
        final wrB = b.wins / b.games;
        final cmp = wrB.compareTo(wrA);
        return cmp != 0 ? cmp : b.games.compareTo(a.games);
      });

    final top = entries.take(n).toList();
    final buf = StringBuffer('Top $n Players (all-time, min 20 games)\n');
    buf.writeln('─' * 20);
    for (int i = 0; i < top.length; i++) {
      final wr = (top[i].wins / top[i].games * 100).roundTo(1);
      buf.writeln('${i + 1}. ${top[i].player.displayName} — $wr% WR (${top[i].games} games)');
    }
    return (
      text: buf.toString().trimRight(),
      suggestions: [
        if (top.isNotEmpty) '${top.first.player.displayName} stats',
        'Top $n sheriffs',
        'Most games played?',
      ],
    );
  }

  _ChatResponse _leaderboardByGames(int n) {
    final aggregated = <int, ({Player player, int games})>{};
    for (final seasonStats in ratings.values) {
      for (final ps in seasonStats) {
        final prev = aggregated[ps.player.id];
        if (prev != null) {
          aggregated[ps.player.id] = (player: ps.player, games: prev.games + ps.gamesPlayed);
        } else {
          aggregated[ps.player.id] = (player: ps.player, games: ps.gamesPlayed);
        }
      }
    }

    final entries = aggregated.values.toList()
      ..sort((a, b) => b.games.compareTo(a.games));
    final top = entries.take(n).toList();

    final buf = StringBuffer('Top $n by Games Played\n');
    buf.writeln('─' * 20);
    for (int i = 0; i < top.length; i++) {
      buf.writeln('${i + 1}. ${top[i].player.displayName} — ${top[i].games} games');
    }
    return (
      text: buf.toString().trimRight(),
      suggestions: [
        if (top.isNotEmpty) '${top.first.player.displayName} stats',
        'Top $n players',
        'Highest rating ever?',
      ],
    );
  }

  _ChatResponse _leaderboardByRole(int n, Role role) {
    final perPlayer = <int, ({Player player, int totalGames, int roleGames, int roleWins})>{};

    for (final seasonStats in ratings.values) {
      for (final stats in seasonStats) {
        final pid = stats.player.id;
        final prev = perPlayer[pid];
        int rg = 0, rw = 0;
        for (final (rv, c) in stats.gamesForRole) {
          if (Role.findByValue(rv) == role) rg += c;
        }
        for (final (rv, w) in stats.winByRole) {
          if (Role.findByValue(rv) == role) rw += w;
        }
        if (prev != null) {
          perPlayer[pid] = (
            player: stats.player,
            totalGames: prev.totalGames + stats.gamesPlayed,
            roleGames: prev.roleGames + rg,
            roleWins: prev.roleWins + rw,
          );
        } else {
          perPlayer[pid] = (
            player: stats.player,
            totalGames: stats.gamesPlayed,
            roleGames: rg,
            roleWins: rw,
          );
        }
      }
    }

    final entries = perPlayer.values
        .where((e) => e.roleGames >= 10 && e.totalGames >= 20)
        .toList()
      ..sort((a, b) {
        final wrA = a.roleWins / a.roleGames;
        final wrB = b.roleWins / b.roleGames;
        final cmp = wrB.compareTo(wrA);
        return cmp != 0 ? cmp : b.roleGames.compareTo(a.roleGames);
      });

    final top = entries.take(n).toList();
    final buf = StringBuffer('Top $n ${role.name.toUpperCase()} Players\n');
    buf.writeln('─' * 20);
    for (int i = 0; i < top.length; i++) {
      final wr = (top[i].roleWins / top[i].roleGames * 100).roundTo(1);
      buf.writeln('${i + 1}. ${top[i].player.displayName} — $wr% WR (${top[i].roleGames} games as ${role.name})');
    }
    return (
      text: buf.toString().trimRight(),
      suggestions: [
        if (top.isNotEmpty) '${top.first.player.displayName} stats',
        ...Role.values
            .where((r) => r != role)
            .take(2)
            .map((r) => 'Top $n ${r.name}s'),
        'Top $n players',
      ],
    );
  }

  // ── Records ───────────────────────────────────────────────────────────

  _ChatResponse _handleRecord(RecordIntent intent) {
    return switch (intent.recordType) {
      'most_games' => _recordMostGames(),
      'highest_rating' => _recordHighestRating(),
      'best_winrate' => _recordBestWinRate(),
      'most_killed' => _recordMostKilled(),
      _ => _handleHelp(),
    };
  }

  _ChatResponse _recordMostGames() {
    final aggregated = <int, ({Player player, int games})>{};
    for (final seasonStats in ratings.values) {
      for (final ps in seasonStats) {
        final prev = aggregated[ps.player.id];
        aggregated[ps.player.id] = (
          player: ps.player,
          games: (prev?.games ?? 0) + ps.gamesPlayed,
        );
      }
    }
    final entries = aggregated.values.toList()..sort((a, b) => b.games.compareTo(a.games));
    if (entries.isEmpty) return (text: 'No game data available.', suggestions: ['Help']);
    final top = entries.first;
    return (
      text: 'Most games played: ${top.player.displayName} with ${top.games} games across all seasons.',
      suggestions: ['${top.player.displayName} stats', 'Top 5 by games', 'Highest rating ever?'],
    );
  }

  _ChatResponse _recordHighestRating() {
    Player? bestPlayer;
    double bestRating = -1;
    int bestSeason = -1;

    for (final entry in ratings.entries) {
      final config = configs.where((c) => c.id == entry.key).firstOrNull;
      for (final ps in entry.value) {
        if (config != null && ps.gamesPlayed < config.gameLimit) continue;
        if (ps.ratingCoefficient > bestRating) {
          bestRating = ps.ratingCoefficient;
          bestPlayer = ps.player;
          bestSeason = entry.key;
        }
      }
    }

    if (bestPlayer == null) return (text: 'No rating data available.', suggestions: ['Help']);
    return (
      text: 'Highest rating ever: ${bestPlayer.displayName} with ${bestRating.roundTo(2)} in season $bestSeason.',
      suggestions: ['${bestPlayer.displayName} stats', 'Season $bestSeason stats', 'Best win rate?'],
    );
  }

  _ChatResponse _recordBestWinRate() {
    final aggregated = <int, ({Player player, int games, int wins})>{};
    for (final seasonStats in ratings.values) {
      for (final ps in seasonStats) {
        final prev = aggregated[ps.player.id];
        aggregated[ps.player.id] = (
          player: ps.player,
          games: (prev?.games ?? 0) + ps.gamesPlayed,
          wins: (prev?.wins ?? 0) + ps.wins,
        );
      }
    }
    final entries = aggregated.values
        .where((e) => e.games >= 20)
        .toList()
      ..sort((a, b) => (b.wins / b.games).compareTo(a.wins / a.games));
    if (entries.isEmpty) return (text: 'No data available.', suggestions: ['Help']);
    final top = entries.first;
    final wr = (top.wins / top.games * 100).roundTo(1);
    return (
      text: 'Best all-time win rate (min 20 games): ${top.player.displayName} with $wr% (${top.wins} wins in ${top.games} games).',
      suggestions: ['${top.player.displayName} stats', 'Most games played?', 'Top 5 players'],
    );
  }

  _ChatResponse _recordMostKilled() {
    final aggregated = <int, ({Player player, int killed})>{};
    for (final seasonStats in ratings.values) {
      for (final ps in seasonStats) {
        final prev = aggregated[ps.player.id];
        aggregated[ps.player.id] = (
          player: ps.player,
          killed: (prev?.killed ?? 0) + ps.firstKilled,
        );
      }
    }
    final entries = aggregated.values.toList()..sort((a, b) => b.killed.compareTo(a.killed));
    if (entries.isEmpty) return (text: 'No data available.', suggestions: ['Help']);
    final top = entries.first;
    return (
      text: 'Most first-killed: ${top.player.displayName} with ${top.killed} times across all seasons.',
      suggestions: ['${top.player.displayName} stats', 'Most games played?', 'Top 5 players'],
    );
  }

  // ── Help ──────────────────────────────────────────────────────────────

  _ChatResponse _handleHelp() {
    return (
      text: 'Here\'s what you can ask me:\n'
          '\n'
          'Player stats:\n'
          '  "Sasha stats" or "How many games did Sasha play?"\n'
          '\n'
          'Player in a season:\n'
          '  "Sasha season 20"\n'
          '\n'
          'Season info:\n'
          '  "Season 20 stats" or "Who won season 15?"\n'
          '  "MVP season 20" or "Best sheriff season 15"\n'
          '\n'
          'Compare players:\n'
          '  "Compare Sasha and Dima" or "Sasha vs Dima"\n'
          '\n'
          'Leaderboards:\n'
          '  "Top 5 players" or "Top 10 sheriffs"\n'
          '\n'
          'Records:\n'
          '  "Most games played?" or "Highest rating ever?"\n'
          '  "Best win rate?" or "Most killed?"',
      suggestions: ['Top 5 players', 'Most games played?', 'Highest rating ever?'],
    );
  }

  // ── Unknown ───────────────────────────────────────────────────────────

  _ChatResponse _handleUnknown(UnknownIntent intent) {
    return (
      text: 'I didn\'t understand "${intent.originalQuery}".\nTry asking about a player, season, or type "help" for examples.',
      suggestions: ['Help', 'Top 5 players', 'Most games played?'],
    );
  }
}
