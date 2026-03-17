import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/best_moves.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerSearchQueryProvider = StateProvider<String>((ref) => '');

typedef SeasonEntry = ({int seasonId, int games});
typedef SeasonGamesEntry = ({String name, List<SeasonEntry> seasonData});

/// For each player: their display name + (seasonId → game count) pairs,
/// sorted by total game count descending.
/// Aggregated from pre-computed RatingPlayerStats (no raw game scan).
final seasonGamesProvider = Provider<List<SeasonGamesEntry>>((ref) {
  final players = ref.watch(playersRepositoryProvider);
  final allRatings = ref.watch(ratingRepositoryProvider);

  final result = players.map((player) {
    final seasonData = <SeasonEntry>[];
    for (final entry in allRatings.entries) {
      final stats = entry.value
          .where((r) => r.player.id == player.id)
          .firstOrNull;
      if (stats != null && stats.gamesPlayed > 0) {
        seasonData.add((seasonId: entry.key, games: stats.gamesPlayed));
      }
    }
    seasonData.sort((a, b) => a.seasonId.compareTo(b.seasonId));
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

/// Games-played count per role for a player, aggregated from pre-computed
/// RatingPlayerStats across all seasons.
final playerRoleGamesProvider =
    Provider.family<Map<String, int>, Player>((ref, player) {
  final allRatings = ref.watch(ratingRepositoryProvider);
  final Map<String, int> result = {};
  for (final seasonStats in allRatings.values) {
    final stats =
        seasonStats.where((r) => r.player.id == player.id).firstOrNull;
    if (stats == null) continue;
    for (final (roleValue, count) in stats.gamesForRole) {
      result[roleValue] = (result[roleValue] ?? 0) + count;
    }
  }
  return result;
});

/// Percentile rank ("Top X%") per role for a player — precomputed during app load.
/// Returns null for a role if the player has < 10 games in that role or < 140 total games.
final roleWinRatePercentilesProvider =
    Provider.family<Map<Role, double?>, Player>((ref, player) {
  final cache = ref.watch(rolePercentilesRepositoryProvider);
  return cache[player.id] ?? {for (final role in Role.values) role: null};
});

/// Win count per role for a player, aggregated from pre-computed
/// RatingPlayerStats across all seasons.
final playerRoleWinsProvider =
    Provider.family<Map<String, int>, Player>((ref, player) {
  final allRatings = ref.watch(ratingRepositoryProvider);
  final Map<String, int> result = {};
  for (final seasonStats in allRatings.values) {
    final stats =
        seasonStats.where((r) => r.player.id == player.id).firstOrNull;
    if (stats == null) continue;
    for (final (roleValue, wins) in stats.winByRole) {
      result[roleValue] = (result[roleValue] ?? 0) + wins;
    }
  }
  return result;
});

/// First-kill totals for a player (civ/sheriff only), aggregated from
/// pre-computed RatingPlayerStats across all seasons.
final playerFirstKillProvider =
    Provider.family<({int total, int cityLost, int civSherGames}), Player>(
        (ref, player) {
  final allRatings = ref.watch(ratingRepositoryProvider);
  int total = 0;
  int cityLost = 0;
  int civSherGames = 0;
  for (final seasonStats in allRatings.values) {
    final stats =
        seasonStats.where((r) => r.player.id == player.id).firstOrNull;
    if (stats == null) continue;
    total += stats.firstKilled;
    cityLost += stats.firstKilledCityLost;
    for (final (roleValue, count) in stats.gamesForRole) {
      final role = Role.findByValue(roleValue);
      if (role != null && !role.isBlack) civSherGames += count;
    }
  }
  return (total: total, cityLost: cityLost, civSherGames: civSherGames);
});

/// Best-move breakdown for a player: how many times first-killed, and how many
/// of those nominations found 0/1/2/3 black cards.
final playerBestMovesProvider =
    Provider.family<BestMoves, Player>((ref, player) {
  final games = ref.watch(gamesRepositoryProvider);
  int firstKilledCount = 0;
  int zero = 0, one = 0, two = 0, three = 0;

  for (final game in games) {
    if (!game.isRatingGame() || !game.isNormalGame()) continue;
    if (game.bestMove.isEmpty || game.bestMove.every((s) => s == 0)) continue;

    final names = player.nicknames ?? [player.displayName];
    String? playerName;
    for (final n in names) {
      if (game.players.contains(n)) {
        playerName = n;
        break;
      }
    }
    if (playerName == null) continue;
    if (!game.isFirstKilled(playerName)) continue;
    final role = Role.findByValue(game.getPlayerRole(playerName));
    if (role == null || role.isBlack) continue;

    firstKilledCount++;
    int blacks = 0;
    for (final slot in game.bestMove) {
      if (slot == 0) continue;
      final idx = slot - 1;
      if (idx < 0 || idx >= game.roles.length) continue;
      if (Role.findByValue(game.roles[idx])?.isBlack == true) blacks++;
    }
    switch (blacks) {
      case 0:
        zero++;
      case 1:
        one++;
      case 2:
        two++;
      case 3:
        three++;
    }
  }

  return BestMoves(
    player: player.displayName,
    isFirstKilled: firstKilledCount,
    zeroBlacks: zero,
    oneBlack: one,
    twoBlacks: two,
    threeBlacks: three,
  );
});
