import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef RoleLeaderEntry = ({Player player, int games, int wins, double wr});

const minRatingGames = 140;
const _topN = 10;

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
      if (totalGames < minRatingGames) continue;
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
    result[role] = entries.take(_topN).toList();
  }

  return result;
});
