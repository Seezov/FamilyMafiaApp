import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// The original player × game scan, kept as the reference the fast
/// implementation must match exactly.
Map<int, Map<Role, double?>> _referencePercentiles(List<Player> players, List<Game> games) {
  final pool = <int, Map<Role, ({int games, int wins})>>{};
  for (final player in players) {
    if (player.displayName.trim().isEmpty) continue;
    if (player.nicknames != null && player.nicknames!.isEmpty) continue;
    if (const {'.', '..', '/'}.contains(player.displayName)) continue;
    final names = player.nicknames ?? [player.displayName];
    final roleStats = <Role, ({int games, int wins})>{};
    var totalGames = 0;
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
      roleStats[role] = (games: prev.games + 1, wins: prev.wins + (game.hasPlayerWon(playerName) ? 1 : 0));
    }
    if (totalGames >= kMinTotalGames) pool[player.id] = roleStats;
  }
  final sortedWrsByRole = {
    for (final role in Role.values)
      role: pool.values
          .map((m) => m[role])
          .whereType<({int games, int wins})>()
          .where((s) => s.games >= kMinRoleGames)
          .map((s) => s.wins / s.games)
          .toList()
        ..sort((a, b) => b.compareTo(a)),
  };
  final result = <int, Map<Role, double?>>{};
  for (final MapEntry(key: id, value: stats) in pool.entries) {
    final percentiles = <Role, double?>{};
    for (final role in Role.values) {
      final s = stats[role];
      final poolWrs = sortedWrsByRole[role]!;
      if (s == null || s.games < kMinRoleGames || poolWrs.isEmpty) {
        percentiles[role] = null;
        continue;
      }
      final rank = poolWrs.indexWhere((wr) => wr <= s.wins / s.games) + 1;
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
    result[id] = percentiles;
  }
  return result;
}

void main() {
  final playersJson = File('assets/raw/players.json').readAsStringSync();
  final bundled = [
    for (final c in (jsonDecode(File('assets/raw/season_config.json').readAsStringSync())['seasons'] as List)
        .cast<Map<String, dynamic>>())
      if (c['source'] == 'bundled') c,
  ];
  final metas = [
    for (final c in bundled)
      SeasonMeta(c['id'] as int, c['gameLimit'] as int, (c['gamesMultiplier'] as num).toDouble()),
  ];
  final jsons = [for (final c in bundled) File('assets/raw/${c['jsonFile']}').readAsStringSync()];

  test('role percentiles over every bundled season match the reference scan', () async {
    final players = PlayersRepository();
    final games = GamesRepository();
    final percentiles = RolePercentilesRepository();
    final loader = SeasonLoaderService(players, games, RatingRepository(), SeasonRepository(), percentiles);

    await loader.loadAll(metas: metas, playersJson: playersJson, seasonJsons: jsons);

    final expected = _referencePercentiles(players.state, games.state);
    expect(expected, isNotEmpty, reason: 'the pool must not be trivially empty');
    expect(percentiles.state, expected);
  });

  test('recomputePercentiles after incremental loads gives the loadAll result', () async {
    final all = RolePercentilesRepository();
    await SeasonLoaderService(PlayersRepository(), GamesRepository(), RatingRepository(), SeasonRepository(), all)
        .loadAll(metas: metas, playersJson: playersJson, seasonJsons: jsons);

    final players = PlayersRepository();
    final games = GamesRepository();
    final incremental = RolePercentilesRepository();
    final loader = SeasonLoaderService(players, games, RatingRepository(), SeasonRepository(), incremental);
    await loader.loadSeasons(metas: metas, playersJson: playersJson, seasonJsons: jsons);
    await loader.recomputePercentiles(players: players.state, games: games.state);

    expect(incremental.state, all.state);
  });
}
