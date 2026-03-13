import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef SeasonEntry = ({int seasonId, int games});
typedef SeasonGamesEntry = ({String name, List<SeasonEntry> seasonData});

/// For each player: their display name + (seasonId → game count) pairs,
/// sorted by total game count descending.
/// Only counts rating + normal games.
final seasonGamesProvider = Provider<List<SeasonGamesEntry>>((ref) {
  final games = ref.watch(gamesRepositoryProvider);
  final players = ref.watch(playersRepositoryProvider);

  final ratingGames =
      games.where((g) => g.isRatingGame() && g.isNormalGame()).toList();

  final result = players.map((player) {
    final gamesByPlayer = ratingGames.where((game) {
      if (player.nicknames == null) {
        return game.players.contains(player.displayName);
      }
      return player.nicknames!.any((n) => game.players.contains(n));
    }).toList();

    final Map<int, int> seasonToCount = {};
    for (final game in gamesByPlayer) {
      seasonToCount[game.seasonId] = (seasonToCount[game.seasonId] ?? 0) + 1;
    }

    final seasonData = seasonToCount.entries
        .map((e) => (seasonId: e.key, games: e.value))
        .toList()
      ..sort((a, b) => a.seasonId.compareTo(b.seasonId));

    return (name: player.displayName, seasonData: seasonData);
  }).toList();

  result.sort((a, b) {
    final totalA = a.seasonData.fold(0, (s, e) => s + e.games);
    final totalB = b.seasonData.fold(0, (s, e) => s + e.games);
    return totalB.compareTo(totalA);
  });

  return result;
});
