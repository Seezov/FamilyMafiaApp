part of '../season_loader.dart';

// ── Top-level isolate entry points ──────────────────────────────────────────

// Top-level function: partial load (no percentiles)
_PartialLoadOutput _computePartialData(_LoadInput input) {
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

  for (int si = 0; si < input.seasonMetas.length; si++) {
    final meta = input.seasonMetas[si];
    final json = input.seasonJsons[si];

    final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final rawData = raw
        .map((e) => GamesDataSeason.fromJson(e))
        .where((d) => _filterRawData(d, meta.id))
        .toList();

    final gamesData =
        _getGamesDataSeason(meta.id, rawData)
            .where((g) => g.isRatingGame())
            .toList();

    for (var i = 0; i < gamesData.length; i++) {
      if (!gamesData[i].isNormalGame()) {
        throw Exception('Not a normal game #$i: ${gamesData[i].players}');
      }
    }

    allGames.addAll(gamesData);

    final playerNames = gamesData.getPlayersList(meta.id);
    final ratings = playerNames
        .map((name) => _computePlayerRating(
            name, gamesData, meta, players))
        .toList();

    ratingsBySeason[meta.id] = ratings;

    final sorted = ratings.sortedByDescending((r) => r.ratingCoefficient);
    statsBySeason[meta.id] =
        _generateSeasonStats(sorted, meta.gameLimit);
  }

  return _PartialLoadOutput(
    players: players,
    allGames: allGames,
    ratingsBySeason: ratingsBySeason,
    statsBySeason: statsBySeason,
  );
}

// Top-level function: re-parse all seasons and compute only percentiles
Map<int, Map<Role, double?>> _computePercentilesOnly(_PercentilesInput input) {
  final rawPlayers =
      (jsonDecode(input.playersJson) as List).cast<Map<String, dynamic>>();
  final players = rawPlayers
      .asMap()
      .entries
      .map((e) => Player.fromJson(e.value).copyWith(id: e.key))
      .toList();

  final allGames = <Game>[];
  for (int si = 0; si < input.seasonMetas.length; si++) {
    final meta = input.seasonMetas[si];
    final json = input.seasonJsons[si];

    final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final rawData = raw
        .map((e) => GamesDataSeason.fromJson(e))
        .where((d) => _filterRawData(d, meta.id))
        .toList();

    final gamesData =
        _getGamesDataSeason(meta.id, rawData)
            .where((g) => g.isRatingGame())
            .toList();

    allGames.addAll(gamesData);
  }

  return _computeRolePercentiles(players, allGames);
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

  for (int si = 0; si < input.seasonMetas.length; si++) {
    final meta = input.seasonMetas[si];
    final json = input.seasonJsons[si];

    final raw = (jsonDecode(json) as List).cast<Map<String, dynamic>>();
    final rawData = raw
        .map((e) => GamesDataSeason.fromJson(e))
        .where((d) => _filterRawData(d, meta.id))
        .toList();

    final gamesData =
        _getGamesDataSeason(meta.id, rawData)
            .where((g) => g.isRatingGame())
            .toList();

    for (var i = 0; i < gamesData.length; i++) {
      if (!gamesData[i].isNormalGame()) {
        throw Exception('Not a normal game #$i: ${gamesData[i].players}');
      }
    }

    allGames.addAll(gamesData);

    final playerNames = gamesData.getPlayersList(meta.id);
    final ratings = playerNames
        .map((name) => _computePlayerRating(
            name, gamesData, meta, players))
        .toList();

    ratingsBySeason[meta.id] = ratings;

    final sorted = ratings.sortedByDescending((r) => r.ratingCoefficient);
    statsBySeason[meta.id] =
        _generateSeasonStats(sorted, meta.gameLimit);
  }

  final percentiles =
      _computeRolePercentiles(players, allGames);

  return _LoadOutput(
    players: players,
    allGames: allGames,
    ratingsBySeason: ratingsBySeason,
    statsBySeason: statsBySeason,
    percentiles: percentiles,
  );
}
