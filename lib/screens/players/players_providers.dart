import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerSearchQueryProvider = StateProvider<String>((ref) => '');

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

const _invalidNames = {'.', '..', '/'};

/// All players sorted by total games descending,
/// excluding those with empty nicknames lists or invalid display names.
final playersListProvider = Provider<List<Player>>((ref) {
  final players = ref.watch(playersRepositoryProvider);
  final entries = ref.watch(seasonGamesProvider);
  final totals = {
    for (final e in entries)
      e.name: e.seasonData.fold(0, (s, x) => s + x.games)
  };
  return (players
        .where((p) =>
            p.displayName.trim().isNotEmpty &&
            !(p.nicknames != null && p.nicknames!.isEmpty) &&
            !_invalidNames.contains(p.displayName))
        .toList())
      ..sort((a, b) =>
          (totals[b.displayName] ?? 0).compareTo(totals[a.displayName] ?? 0));
});

/// Players filtered by the current search query.
final filteredPlayersProvider = Provider<List<Player>>((ref) {
  final players = ref.watch(playersListProvider);
  final query = ref.watch(playerSearchQueryProvider).toLowerCase().trim();
  if (query.isEmpty) return players;
  return players
      .where((p) => p.displayName.toLowerCase().contains(query))
      .toList();
});

/// Counts all-time accomplishments (placements + awards) for a given player.
final playerAccomplishmentsProvider =
    Provider.family<PlayerAccomplishments, Player>((ref, player) {
  final allSeasonStats = ref.watch(seasonRepositoryProvider);
  final acc = PlayerAccomplishments(player);

  for (final entry in allSeasonStats.entries) {
    final season = Season.findById(entry.key);
    if (season == null) continue;
    final stats = entry.value;

    final qualifiers = stats.playerStats
        .where((p) => p.gamesPlayed >= season.gameLimit)
        .toList(); // already sorted by ratingCoefficient desc

    for (var i = 0; i < qualifiers.length && i < 3; i++) {
      if (qualifiers[i].player.id == player.id) {
        if (i == 0) {
          acc.firsts++;
        } else if (i == 1) {
          acc.seconds++;
        } else {
          acc.thirds++;
        }
        break;
      }
    }

    if (stats.mvpPlayerId == player.id) acc.mvp++;
    if (stats.bestSheriffPlayerId == player.id) acc.bestSheriff++;
    if (stats.bestDonPlayerId == player.id) acc.bestDon++;
    if (stats.bestCivilianPlayerId == player.id) acc.bestCivilian++;
    if (stats.bestMafiaPlayerId == player.id) acc.bestMafia++;
  }

  return acc;
});
