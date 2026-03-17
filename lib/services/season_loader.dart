import 'dart:convert';
import 'dart:math';

import 'package:family_mafia_app/enums/game_values.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/extensions/list_extensions.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ── Background isolate I/O ──────────────────────────────────────────────────

class _LoadInput {
  final String playersJson;
  // Parallel to Season.values order
  final List<String> seasonJsons;

  const _LoadInput(this.playersJson, this.seasonJsons);
}

class _LoadOutput {
  final List<Player> players;
  final List<Game> allGames;
  final Map<int, List<RatingPlayerStats>> ratingsBySeason;
  final Map<int, SeasonStats> statsBySeason;
  final Map<int, Map<Role, double?>> percentiles;

  const _LoadOutput({
    required this.players,
    required this.allGames,
    required this.ratingsBySeason,
    required this.statsBySeason,
    required this.percentiles,
  });
}

// Top-level function required by compute()
_LoadOutput _computeAllData(_LoadInput input) {
  final rawPlayers =
      (jsonDecode(input.playersJson) as List).cast<Map<String, dynamic>>();
  final players = rawPlayers
      .asMap()
      .entries
      .map((e) => Player.fromJson(e.value).copyWith(id: e.key))
      .toList();

  final allGames = <Game>[];
  final ratingsBySeason = <int, List<RatingPlayerStats>>{};
  final statsBySeason = <int, SeasonStats>{};

  for (int si = 0; si < Season.values.length; si++) {
    final season = Season.values[si];
    final json = input.seasonJsons[si];

    final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final rawData = raw
        .map((e) => GamesDataSeason.fromJson(e))
        .where((d) => SeasonLoaderService._filterRawData(d, season.id))
        .toList();

    final gamesData =
        SeasonLoaderService._getGamesDataSeason(season.id, rawData)
            .where((g) => g.isRatingGame())
            .toList();

    for (var i = 0; i < gamesData.length; i++) {
      if (!gamesData[i].isNormalGame()) {
        throw Exception('Not a normal game #$i: ${gamesData[i].players}');
      }
    }

    allGames.addAll(gamesData);

    final playerNames = gamesData.getPlayersList(season.id);
    final ratings = playerNames
        .map((name) => SeasonLoaderService._computePlayerRating(
            name, gamesData, season, players))
        .toList();

    ratingsBySeason[season.id] = ratings;

    final sorted = ratings.sortedByDescending((r) => r.ratingCoefficient);
    statsBySeason[season.id] = SeasonLoaderService._generateSeasonStats(sorted);
  }

  final percentiles =
      SeasonLoaderService._computeRolePercentiles(players, allGames);

  return _LoadOutput(
    players: players,
    allGames: allGames,
    ratingsBySeason: ratingsBySeason,
    statsBySeason: statsBySeason,
    percentiles: percentiles,
  );
}

// ── Service ─────────────────────────────────────────────────────────────────

class SeasonLoaderService {
  final PlayersRepository _playersRepo;
  final GamesRepository _gamesRepo;
  final RatingRepository _ratingRepo;
  final SeasonRepository _seasonRepo;
  final RolePercentilesRepository _rolePercRepo;

  SeasonLoaderService(
    this._playersRepo,
    this._gamesRepo,
    this._ratingRepo,
    this._seasonRepo,
    this._rolePercRepo,
  );

  Future<void> loadAll() async {
    // Phase 1: load asset strings on the main thread (platform channel)
    final playersJson =
        await rootBundle.loadString('assets/raw/players.json');
    final seasonJsons = <String>[];
    for (final season in Season.values) {
      seasonJsons.add(await rootBundle.loadString(season.assetPath));
    }

    // Phase 2: all CPU work in a background isolate
    final out =
        await compute(_computeAllData, _LoadInput(playersJson, seasonJsons));

    // Phase 3: populate repositories on the main thread
    _playersRepo.addPlayers(out.players);
    _gamesRepo.addGames(out.allGames);
    for (final entry in out.ratingsBySeason.entries) {
      _ratingRepo.addRatings(Season.findById(entry.key)!, entry.value);
    }
    for (final entry in out.statsBySeason.entries) {
      _seasonRepo.addSeason(entry.key, entry.value);
    }
    _rolePercRepo.setPercentiles(out.percentiles);
  }

  // ─── Raw data filtering ────────────────────────────────────────────────────

  static bool _filterRawData(GamesDataSeason d, int seasonId) {
    if (seasonId <= 16) return int.tryParse(d.a) != null;
    return d.a.isNotEmpty && d.c.isNotEmpty;
  }

  // ─── JSON → Game objects ───────────────────────────────────────────────────

  static List<Game> _getGamesDataSeason(
      int seasonId, List<GamesDataSeason> rawData) {
    final chunkSize = seasonId <= 16 ? 10 : 14;
    return rawData.chunked(chunkSize).map((p) => _buildGame(seasonId, p)).toList();
  }

  static Game _buildGame(int seasonId, List<GamesDataSeason> p) {
    if (seasonId <= 1) {
      return Game(
        seasonId: seasonId,
        players: p.map((r) => r.b).toList(),
        roles: p.map((r) => r.c).toList(),
        cityWon: () {
          final role = Role.findByValue(p.first.c);
          if (role == null) return null;
          return role.isBlack
              ? p.first.d != GameValues.yes.sheetValues.first
              : p.first.d == GameValues.yes.sheetValues.first;
        }(),
        firstKilled: () {
          final row = p.where((r) => r.f == GameValues.yes.sheetValues.first);
          return row.isEmpty ? 0 : (int.tryParse(row.first.a) ?? 0);
        }(),
        bestMovePoints: () {
          final row = p.where((r) => r.g.isNotEmpty);
          return row.isEmpty ? 0.0 : (double.tryParse(row.first.g) ?? 0.0);
        }(),
        wonByPlayer: p.map((r) => r.d).toList(),
        penaltyPoints: p
            .map((r) =>
                r.e == GameValues.yes.sheetValues.first ? -1.0 : 0.0)
            .toList(),
        bestMove: const [],
      );
    }

    if (seasonId <= 3) {
      final firstKilled = int.tryParse(p[1].c) ?? 0;
      return Game(
        seasonId: seasonId,
        players: p.map((r) => r.g).toList(),
        roles: p.map((r) => r.h).toList(),
        cityWon: _getVictoryTeam(p[0].c),
        firstKilled: firstKilled,
        bestMovePoints: _bestMovePointsOldFormat(firstKilled, p.map((r) => r.j).toList()),
        penaltyPoints:
            p.map((r) => int.tryParse(r.f) == 4 ? -1.0 : 0.0).toList(),
        bestMove: [
          int.tryParse(p[2].c) ?? 0,
          int.tryParse(p[2].d) ?? 0,
          int.tryParse(p[2].e) ?? 0,
        ],
        additionalPoints:
            p.map((r) => double.tryParse(r.i) ?? 0.0).toList(),
      );
    }

    if (seasonId <= 16) {
      final firstKilled = int.tryParse(p[1].c) ?? 0;
      return Game(
        seasonId: seasonId,
        players: p.map((r) => r.g).toList(),
        roles: p.map((r) => r.h).toList(),
        cityWon: _getVictoryTeam(p[0].c),
        firstKilled: firstKilled,
        bestMovePoints: _bestMovePointsOldFormat(firstKilled, p.map((r) => r.j).toList()),
        bestMove: [
          int.tryParse(p[2].c) ?? 0,
          int.tryParse(p[2].d) ?? 0,
          int.tryParse(p[2].e) ?? 0,
        ],
        additionalPoints:
            p.map((r) => double.tryParse(r.i) ?? 0.0).toList(),
      );
    }

    // Season 17+: chunk of 14 rows; player rows are p[2]..p[11]
    final firstKilled = int.tryParse(p[12].b) ?? 0;
    return Game(
      seasonId: seasonId,
      players: p.sublist(2, 12).map((r) => r.b).toList(),
      roles: p.sublist(2, 12).map((r) => r.c).toList(),
      cityWon: _getVictoryTeam(p.last.c),
      firstKilled: firstKilled,
      // index = firstKilled + 1 because player rows start at index 2
      bestMovePoints: firstKilled == 0
          ? 0.0
          : _tryParseDouble(p.map((r) => r.i).toList(), firstKilled + 1),
      bestMove: [
        int.tryParse(p[12].d) ?? 0,
        int.tryParse(p[12].e) ?? 0,
        int.tryParse(p[12].f) ?? 0,
      ],
      additionalPoints:
          p.sublist(2, 12).map((r) => double.tryParse(r.j) ?? 0.0).toList(),
      // H column = autoAdditionalPoints for S17-20, penaltyPoints for S21+
      autoAdditionalPoints: seasonId <= 20
          ? p.sublist(2, 12).map((r) => double.tryParse(r.h) ?? 0.0).toList()
          : null,
      penaltyPoints: seasonId > 20
          ? p.sublist(2, 12).map((r) => double.tryParse(r.h) ?? 0.0).toList()
          : null,
    );
  }

  static double _bestMovePointsOldFormat(
      int firstKilled, List<String> jColumn) {
    if (firstKilled == 0) return 0.0;
    try {
      return double.parse(jColumn[firstKilled - 1]);
    } catch (_) {
      return 0.0;
    }
  }

  static double _tryParseDouble(List<String> column, int index) {
    try {
      return double.parse(column[index]);
    } catch (_) {
      return 0.0;
    }
  }

  static bool? _getVictoryTeam(String s) {
    if (GameValues.mafiaWon.sheetValues.contains(s)) return false;
    if (GameValues.cityWon.sheetValues.contains(s)) return true;
    return null;
  }

  // ─── Per-player rating computation ────────────────────────────────────────

  static Player _findPlayer(String name, List<Player> players) {
    return players.firstWhere(
      (p) =>
          p.displayName == name ||
          (p.nicknames?.contains(name) ?? false),
      orElse: () => Player(id: -1, displayName: name),
    );
  }

  static RatingPlayerStats _computePlayerRating(
      String name, List<Game> gamesData, Season season, List<Player> players) {
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

    for (final g in gamesForPlayer) {
      final rawRole = g.getPlayerRole(name);
      final roleVal = Role.findByValue(rawRole)?.sheetValue ?? rawRole;
      final won = g.hasPlayerWon(name);
      final isFK = g.isFirstKilled(name);
      final prev = roleAcc[roleVal] ?? emptyAcc();
      roleAcc[roleVal] = (
        wins: prev.wins + (won ? 1 : 0),
        losses: prev.losses + (won ? 0 : 1),
        additional: prev.additional + g.getPlayerAdditionalPoints(name),
        penalty: prev.penalty + g.getPlayerPenaltyPoints(name),
        bestMovePoints: prev.bestMovePoints + (isFK ? g.bestMovePoints : 0.0),
        games: prev.games + 1,
      );
      if (isFK) {
        firstKilled++;
        if (!won) firstKilledCityLost++;
      }
      autoAdditionalPointsByRoleSum += g.getPlayerAutoAdditionalPoints(name);
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
        _calculateWinByRole(season.id, e.$1, e.$2));

    final loseByRoleSum = loseByRole.sumOfInt((e) =>
        _isDonOrSheriff(e.$1) ? e.$2 : 0);

    final ciForGame = _calculateCiForGame(
        firstKilledCityLost, firstKilled, gamesPlayed, season.id);
    final ci = ciForGame * firstKilledCityLost;

    final percentOfDeath =
        gamesAsRed > 0 ? firstKilled / gamesAsRed : 0.0;
    final winRate = wins / gamesPlayed;

    final winPoints = _calculateWinPoints(
      season.id,
      additionalPointsByRoleSum,
      bestMovePointsByRoleSum,
      penaltyPointsByRoleSum,
      ci,
      autoAdditionalPointsByRoleSum,
      winByRoleSum,
      loseByRoleSum,
    );

    final mvp = _calculateMvp(
      season.id,
      gamesPlayed,
      additionalPointsByRoleSum,
      bestMovePointsByRoleSum,
      penaltyPointsByRoleSum,
      winPoints,
    );

    final ratingCoefficient = _calculateRatingCoefficient(
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
    );
  }

  // ─── Formula functions ────────────────────────────────────────────────────

  static int _calculateWinByRole(int seasonId, String role, int wins) {
    if (seasonId <= 1) return _isDonOrSheriff(role) ? wins * 4 : wins * 3;
    if (seasonId <= 3) return wins * 2;
    if (seasonId <= 16) return wins;
    return 0;
  }

  static bool _isDonOrSheriff(String role) {
    final r = Role.findByValue(role);
    return r == Role.don || r == Role.sheriff;
  }

  static double _calculateWinPoints(
    int seasonId,
    double additionalPoints,
    double bestMovePoints,
    double penaltyPoints,
    double ci,
    double autoAdditionalPoints,
    int winByRoleSum,
    int loseByRoleSum,
  ) {
    if (seasonId <= 1) {
      return winByRoleSum - loseByRoleSum + penaltyPoints + bestMovePoints;
    }
    if (seasonId <= 3) {
      return winByRoleSum + additionalPoints + bestMovePoints + penaltyPoints;
    }
    if (seasonId <= 16) {
      return winByRoleSum + additionalPoints + bestMovePoints;
    }
    return additionalPoints + autoAdditionalPoints + penaltyPoints + bestMovePoints + ci;
  }

  static double _calculateCiForGame(
    int firstKilledCityLost,
    int firstKilled,
    int gamesPlayed,
    int seasonId,
  ) {
    if (seasonId <= 16) return 0.0;
    if (seasonId <= 18) return 0.1;

    final r = firstKilled / gamesPlayed;
    if (seasonId <= 20) {
      return r > 0.399
          ? 0.4 * firstKilledCityLost
          : r * 5 / 2 * 0.4;
    }
    return r > 0.399 ? 0.5 : r * 1.25;
  }

  static double _calculateMvp(
    int seasonId,
    int gamesPlayed,
    double additionalPoints,
    double bestMovePoints,
    double penaltyPoints,
    double winPoints,
  ) {
    if (seasonId <= 1) return (winPoints / gamesPlayed).roundTo(3);
    return ((additionalPoints + bestMovePoints + penaltyPoints) / gamesPlayed)
        .roundTo(4);
  }

  static double _calculateRatingCoefficient({
    required String player,
    required double winPoints,
    required int gamesPlayed,
    required double winRate,
    required double ci,
    required double bestMovePoints,
    required double additionalPoints,
    required double penaltyPoints,
    required double autoAdditionalPoints,
    required Season season,
  }) {
    final id = season.id;
    final m = season.gamesMultiplier;
    double result;

    if (id <= 1) {
      result = (winPoints / gamesPlayed).roundTo(2) * 100 + gamesPlayed * m;
    } else if (id <= 3) {
      result = winPoints / gamesPlayed + gamesPlayed * m;
    } else if (id == 4) {
      result = (winPoints / gamesPlayed + gamesPlayed * m) * 100;
    } else if (id <= 16) {
      result = ((winPoints / gamesPlayed).roundTo(2) +
              gamesPlayed *
                  (winRate * 100).roundTo(2) /
                  100 *
                  m)
          .roundTo(3) *
          100;
    } else if (id == 17) {
      // Season 17: +1 correction for "Железный" (historical fake win)
      result = winRate * 100 +
          winPoints / gamesPlayed +
          ci +
          bestMovePoints +
          autoAdditionalPoints +
          additionalPoints +
          (player == 'Железный' ? 1 : 0);
    } else if (id <= 20) {
      final gamesWithoutAutoPoints =
          gamesPlayed - (autoAdditionalPoints / 0.3).round();
      result = winRate * 100 +
          winPoints / gamesPlayed +
          ci +
          bestMovePoints +
          additionalPoints -
          gamesWithoutAutoPoints * 0.3;
    } else {
      result = winRate * 100 +
          winPoints / gamesPlayed +
          ci +
          bestMovePoints +
          additionalPoints +
          penaltyPoints;
    }

    return result.roundTo(3);
  }

  // ─── Season stats ─────────────────────────────────────────────────────────

  static SeasonStats _generateSeasonStats(List<RatingPlayerStats> sorted) {
    final withLimit = sorted.where((p) {
      final season = Season.findById(p.seasonId)!;
      return p.gamesPlayed >= season.gameLimit;
    }).toList();

    return SeasonStats(
      playerStats: sorted,
      mvpPlayerId:
          withLimit.maxByOrNull((p) => p.mvp)?.player.id ?? -1,
      mostKilledPlayerId:
          withLimit.maxByOrNull((p) => p.firstKilled.toDouble())?.player.id ?? -1,
      bestSheriffPlayerId:
          findBestPlayerForRole(withLimit, Role.sheriff)?.player.id ?? -1,
      bestDonPlayerId:
          findBestPlayerForRole(withLimit, Role.don)?.player.id ?? -1,
      bestCivilianPlayerId:
          findBestPlayerForRole(withLimit, Role.civilian)?.player.id ?? -1,
      bestMafiaPlayerId:
          findBestPlayerForRole(withLimit, Role.mafia)?.player.id ?? -1,
    );
  }

  static RatingPlayerStats? findBestPlayerForRole(
      List<RatingPlayerStats> players, Role role) {
    final roleKey = role.sheetValue;

    final eligible = players.map((p) {
      final gamesForRole = p.gamesForRole
          .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0))
          .$2;
      final winsForRole = p.winByRole
          .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0))
          .$2;
      final pointsForRole = p.bestMoveAndAdditionalPointsByRole
          .firstWhere((e) => e.$1 == roleKey, orElse: () => (roleKey, 0.0))
          .$2;
      final gameLimit = p.seasonGameLimit * role.chanceToDraw;

      if (gamesForRole == 0 || gamesForRole < gameLimit) return null;

      final winRate = winsForRole / gamesForRole;
      final avgPoints = pointsForRole / gamesForRole;
      return (p, winRate, avgPoints);
    }).whereType<(RatingPlayerStats, double, double)>().toList();

    if (eligible.isEmpty) return null;

    final maxWinRate = eligible.map((e) => e.$2).reduce(max);

    return eligible
        .where((e) => e.$2 >= maxWinRate - 0.2)
        .reduce((a, b) {
          if ((a.$3 - b.$3).abs() > 1e-9) return a.$3 > b.$3 ? a : b;
          return a.$2 >= b.$2 ? a : b;
        })
        .$1;
  }

  // ─── Role percentiles ─────────────────────────────────────────────────────

  static Map<int, Map<Role, double?>> _computeRolePercentiles(
      List<Player> players, List<Game> games) {
    const minRoleGames = 10;

    // Build role stats for every valid player with 140+ rating games
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

      if (totalGames >= 140) pool[player.id] = roleStats;
    }

    // Pre-sort WR lists per role once instead of per-player
    final sortedWrsByRole = <Role, List<double>>{};
    for (final role in Role.values) {
      sortedWrsByRole[role] = pool.values
          .map((m) => m[role])
          .whereType<({int games, int wins})>()
          .where((s) => s.games >= minRoleGames)
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
        if (myRoleStats == null || myRoleStats.games < minRoleGames) {
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
}
