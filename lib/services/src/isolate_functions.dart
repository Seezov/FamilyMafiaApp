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
/// entry cannot stop the app from loading for everyone. [sheet] counts games
/// the way the season sheet does (see [_buildGame]).
List<Game> _ratingGames(int seasonId, String json, PlayerResolver resolver,
    {bool sheet = false}) {
  final firestore = json.trimLeft().startsWith('{');
  final games = _canonicalNames(
      _parseSeasonGames(seasonId, json, sheet: sheet)
          .where((g) => g.isRatingGame())
          .toList(),
      resolver);
  final normal = <Game>[];
  for (var i = 0; i < games.length; i++) {
    if (games[i].isNormalGame()) {
      normal.add(games[i]);
    } else if (_sheetCountsIrregular(games[i])) {
      // Not a real table: only the sheet's own count includes it.
      if (sheet) normal.add(games[i]);
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

/// One season's games and rating rows. The main league is the season sheet's
/// own count, quirks included, so its standings equal the sheet; every other
/// row, and the games behind the rest of the stats, follow the club's rules.
({List<Game> games, List<RatingPlayerStats> ratings}) _seasonData(
    SeasonMeta meta, String json, PlayerResolver resolver, List<Player> players) {
  final games = _ratingGames(meta.id, json, resolver);

  Map<String, RatingPlayerStats> rate(List<Game> gs, {required bool sheet}) => {
        for (final name in gs.getPlayersList(meta.id))
          name: _computePlayerRating(name, gs, meta, players, sheet: sheet),
      };
  final byRules = rate(games, sheet: false);
  if (meta.id >= kExactRatingStartSeason) {
    return (games: games, ratings: byRules.values.toList());
  }
  final sheetGames = _ratingGames(meta.id, json, resolver, sheet: true);
  final bySheet = rate(sheetGames, sheet: true);

  bool main(RatingPlayerStats? r) => r != null && r.gamesPlayed >= meta.gameLimit;
  final ratings = [
    for (final name in {...bySheet.keys, ...byRules.keys})
      // Main league membership is the sheet's: a player the rules would lift
      // over the limit but the sheet keeps below stays the sheet's row.
      if (main(bySheet[name]) || (main(byRules[name]) && bySheet[name] != null))
        bySheet[name]!
      else
        byRules[name]!,
  ];
  return (games: games, ratings: ratings);
}

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

    final (:games, :ratings) = _seasonData(meta, json, resolver, players);
    allGames.addAll(games);

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

    final (:games, :ratings) = _seasonData(meta, json, resolver, players);
    allGames.addAll(games);

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
