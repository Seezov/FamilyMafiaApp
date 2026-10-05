part of '../season_loader.dart';

// ── Top-level isolate entry points ──────────────────────────────────────────

/// Rewrites every slot to the player's display name, so a player who shows up
/// under two nicknames in one season (Малишка / Малышка, Скай / Rathma) gets
/// a single rating row. Names missing from players.json are kept as written.
List<Game> _canonicalNames(List<Game> games, PlayerResolver resolver) => [
      for (final g in games)
        g.copyWith(players: [
          for (final n in g.players)
            resolver.resolve(n).id >= 0 ? resolver.resolve(n).displayName : n,
        ]),
    ];

/// A season's rating games with canonical names. A sheet game with a broken
/// role list or a duplicate player is a data error worth failing loudly on; a
/// game recorded on /host/ (firestore snapshot) is skipped instead, so one bad
/// entry cannot stop the app from loading for everyone.
List<Game> _ratingGames(int seasonId, String json, PlayerResolver resolver) {
  final firestore = json.trimLeft().startsWith('{');
  final games = _canonicalNames(
      _parseSeasonGames(seasonId, json).where((g) => g.isRatingGame()).toList(),
      resolver);
  final normal = <Game>[];
  for (var i = 0; i < games.length; i++) {
    if (games[i].isNormalGame() || _sheetCountsIrregular(games[i])) {
      normal.add(games[i]);
    } else if (!firestore) {
      throw Exception('Not a normal game #$i: ${games[i].players}');
    } else {
      debugPrint('Season $seasonId: skipping game #$i (not a normal game): ${games[i].players}');
    }
  }
  return normal;
}

/// Whether [g] is one of the [kSheetCountedIrregularGames].
bool _sheetCountsIrregular(Game g) =>
    kSheetCountedIrregularGames[g.seasonId]
        ?.any((e) => e.$1 == g.date && e.$2 == g.host) ??
    false;

// Top-level function: partial load (no percentiles)
_PartialLoadOutput _computePartialData(_LoadInput input) {
  final rawPlayers =
      (jsonDecode(input.playersJson) as List).cast<Map<String, dynamic>>();
  final players = rawPlayers
      .asMap()
      .entries
      .map((e) => Player.fromJson(e.value).copyWith(id: e.key))
      .toList();
  final resolver = PlayerResolver(players);

  final allGames = <Game>[];
  final ratingsBySeason = <int, List<RatingPlayerStats>>{};
  final statsBySeason = <int, SeasonStats>{};

  for (int si = 0; si < input.seasonMetas.length; si++) {
    final meta = input.seasonMetas[si];
    final json = input.seasonJsons[si];

    final gamesData = _ratingGames(meta.id, json, resolver);

    allGames.addAll(gamesData);

    final playerNames = gamesData.getPlayersList(meta.id);
    final ratings = playerNames
        .map((name) => _computePlayerRating(
            name, gamesData, meta, players))
        .toList();

    ratingsBySeason[meta.id] = ratings;

    final sorted = sortByRating(ratings);
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

// Top-level function: percentiles from already-parsed players and games
Map<int, Map<Role, double?>> _computePercentilesOnly(
        (List<Player>, List<Game>) input) =>
    _computeRolePercentiles(input.$1, input.$2);

// Top-level function required by compute()
_LoadOutput _computeAllData(_LoadInput input) {
  final rawPlayers =
      (jsonDecode(input.playersJson) as List).cast<Map<String, dynamic>>();
  final players = rawPlayers
      .asMap()
      .entries
      .map((e) => Player.fromJson(e.value).copyWith(id: e.key))
      .toList();
  final resolver = PlayerResolver(players);

  final allGames = <Game>[];
  final ratingsBySeason = <int, List<RatingPlayerStats>>{};
  final statsBySeason = <int, SeasonStats>{};

  for (int si = 0; si < input.seasonMetas.length; si++) {
    final meta = input.seasonMetas[si];
    final json = input.seasonJsons[si];

    final gamesData = _ratingGames(meta.id, json, resolver);

    allGames.addAll(gamesData);

    final playerNames = gamesData.getPlayersList(meta.id);
    final ratings = playerNames
        .map((name) => _computePlayerRating(
            name, gamesData, meta, players))
        .toList();

    ratingsBySeason[meta.id] = ratings;

    final sorted = sortByRating(ratings);
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
