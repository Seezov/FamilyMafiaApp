import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef RoleLeaderEntry = ({Player player, int games, int wins, double wr});

/// For each role, the top [_topN] players by all-time win rate.
/// Only players with at least [minRatingGames] total rating games qualify.
final topPlayersByRoleProvider =
    Provider<Map<Role, List<RoleLeaderEntry>>>((ref) {
  final allRatings = ref.watch(ratingRepositoryProvider);

  // Aggregate wins + games per player per role across all seasons,
  // and total rating games per player.
  // Map<playerId, (player, totalGames, Map<Role, ({wins, games})>)>
  final perPlayer =
      <int, (Player, int, Map<Role, ({int wins, int games})>)>{};

  for (final seasonStats in allRatings.values) {
    for (final stats in seasonStats) {
      final pid = stats.player.id;
      perPlayer.putIfAbsent(pid, () => (stats.player, 0, {}));
      final (player, totalGames, roleData) = perPlayer[pid]!;
      perPlayer[pid] = (player, totalGames + stats.gamesPlayed, roleData);

      for (final (roleValue, count) in stats.gamesForRole) {
        final role = Role.findByValue(roleValue);
        if (role == null) continue;
        final cur = roleData[role] ?? (wins: 0, games: 0);
        roleData[role] = (wins: cur.wins, games: cur.games + count);
      }

      for (final (roleValue, wins) in stats.winByRole) {
        final role = Role.findByValue(roleValue);
        if (role == null) continue;
        final cur = roleData[role] ?? (wins: 0, games: 0);
        roleData[role] = (wins: cur.wins + wins, games: cur.games);
      }
    }
  }

  final result = <Role, List<RoleLeaderEntry>>{};

  for (final role in Role.values) {
    final entries = <RoleLeaderEntry>[];
    for (final (player, totalGames, roleData) in perPlayer.values) {
      if (totalGames < kDashboardMinRatingGames) continue;
      final rd = roleData[role];
      if (rd == null || rd.games == 0) continue;
      entries.add((
        player: player,
        games: rd.games,
        wins: rd.wins,
        wr: rd.wins / rd.games,
      ));
    }
    entries.sort((a, b) => b.wr.compareTo(a.wr));
    result[role] = entries.take(kDashboardTopN).toList();
  }

  return result;
});

// ---------------------------------------------------------------------------
// Club overview (hero card)
// ---------------------------------------------------------------------------

/// All-time club stats for the dashboard hero card.
final clubOverviewProvider =
    Provider<({int seasons, int games, int players, double cityWR})>((ref) {
  final configs = ref.watch(loadedSeasonConfigsProvider);
  final allGames = ref.watch(gamesRepositoryProvider);

  int cityWins = 0;
  int decided = 0;
  final uniquePlayers = <String>{};

  for (final g in allGames) {
    if (g.cityWon == true) {
      cityWins++;
      decided++;
    } else if (g.cityWon == false) {
      decided++;
    }
    uniquePlayers.addAll(g.players.where((p) => p.isNotEmpty));
  }

  return (
    seasons: configs.length,
    games: allGames.length,
    players: uniquePlayers.length,
    cityWR: decided > 0 ? cityWins / decided : 0.0,
  );
});

// ---------------------------------------------------------------------------
// Role win rates (circular rings)
// ---------------------------------------------------------------------------

/// All-time win rate per role for the circular rings.
final roleWinRateProvider = Provider<Map<Role, double>>((ref) {
  final allGames = ref.watch(gamesRepositoryProvider);
  final winsPerRole = <Role, int>{};
  final gamesPerRole = <Role, int>{};

  for (final g in allGames) {
    if (g.cityWon == null) continue;
    for (int i = 0; i < g.players.length; i++) {
      if (i >= g.roles.length) continue;
      final role = Role.findByValue(g.roles[i]);
      if (role == null) continue;
      gamesPerRole[role] = (gamesPerRole[role] ?? 0) + 1;
      final won = role.isBlack ? !g.cityWon! : g.cityWon!;
      if (won) winsPerRole[role] = (winsPerRole[role] ?? 0) + 1;
    }
  }

  return {
    for (final role in Role.values)
      role: gamesPerRole[role] != null && gamesPerRole[role]! > 0
          ? (winsPerRole[role] ?? 0) / gamesPerRole[role]!
          : 0.0,
  };
});

// ---------------------------------------------------------------------------
// Protocol guesses leaderboard
// ---------------------------------------------------------------------------

typedef ProtocolLeaderEntry = ({
  Player player,
  int correct,
  int total,
  double accuracy,
});

/// Top players by protocol guess accuracy.
/// Aggregates correct/total guesses from all games with protocol data.
final protocolGuessLeaderboardProvider =
    Provider<List<ProtocolLeaderEntry>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final playersRepo = ref.read(playersRepositoryProvider.notifier);

  // playerName → (correct, total)
  final acc = <String, ({int correct, int total})>{};

  for (final game in games) {
    if (game.protocol == null) continue;
    for (final entry in game.protocol!) {
      if (entry.colorGuesses.isEmpty) continue;
      final slot = entry.killedSlot;
      if (slot < 1 || slot > game.players.length) continue;
      final name = game.players[slot - 1];

      final prev = acc[name] ?? (correct: 0, total: 0);
      int correct = prev.correct;
      int total = prev.total;

      for (final guess in entry.colorGuesses) {
        final guessedSlot = guess.abs();
        if (guessedSlot < 1 || guessedSlot > game.roles.length) continue;
        total++;
        final role = Role.findByValue(game.roles[guessedSlot - 1]);
        if (role == null) continue;
        if ((guess < 0) == role.isBlack) correct++;
      }

      acc[name] = (correct: correct, total: total);
    }
  }

  final entries = acc.entries
      .where((e) => e.value.total > 0)
      .map((e) => (
            player: playersRepo.findPlayer(e.key),
            correct: e.value.correct,
            total: e.value.total,
            accuracy: e.value.correct / e.value.total,
          ))
      .toList()
    ..sort((a, b) {
      final cmp = b.accuracy.compareTo(a.accuracy);
      return cmp != 0 ? cmp : b.total.compareTo(a.total);
    });

  return entries.take(kDashboardTopN).toList();
});
