part of '../season_loader.dart';

// ── JSON → Game objects ───────────────────────────────────────────────────

/// [sheet] reproduces the season sheet's own counting, quirks included (used
/// for the main league); otherwise games are read by the club's rules.
List<Game> _getGamesDataSeason(
    int seasonId, List<GamesDataSeason> rawData, {bool sheet = false}) {
  final chunkSize = seasonId <= kLegacyMaxSeason ? kOldChunkSize : kNewChunkSize;
  return rawData
      .chunked(chunkSize)
      .map((p) => _buildGame(seasonId, p, sheet: sheet))
      .toList();
}

/// A season's JSON is either sheet rows (a list) or a firestore snapshot (a map).
List<Game> _parseSeasonGames(int seasonId, String json, {bool sheet = false}) {
  final decoded = jsonDecode(json);
  if (decoded is Map<String, dynamic>) {
    return gamesFromFirestoreSnapshot(seasonId, decoded);
  }
  final raw = (decoded as List)
      .cast<Map<String, dynamic>>()
      .map(GamesDataSeason.fromJson)
      .toList();
  final games = _getGamesDataSeason(
      seasonId, raw.where((d) => _filterRawData(d, seasonId)).toList(),
      sheet: sheet);
  // The sheet-quirk pass only feeds the main-league table; it needs no extras.
  if (sheet) return games;
  return _withExtras(seasonId, games, sheetGameExtras(seasonId, raw));
}

/// [extras] zipped onto [games] by position. If the anchors don't line up the
/// sheet has a stray row; no extras beat comments on the wrong game.
List<Game> _withExtras(int seasonId, List<Game> games, List<SheetGameExtras> extras) {
  if (extras.length != games.length) {
    debugPrint('Season $seasonId: ${extras.length} comment blocks for ${games.length} games, skipping comments');
    return games;
  }
  return [
    for (var i = 0; i < games.length; i++)
      games[i].copyWith(
        comments: extras[i].comments.isEmpty ? null : extras[i].comments,
        label: extras[i].label,
        table: extras[i].table,
      ),
  ];
}

/// A season 17+ player row's name, or blank when the sheet doesn't count the
/// seat for anyone: its Бал cell is empty, as games are COUNTIFS(Бал > -1)
/// (season 17: Луна on 05.03.2023; season 27: Мідас), or it is one of the
/// [kSheetUncountedSeats].
String _sheetCountedName(int seasonId, DateTime? date, GamesDataSeason row) {
  if (row.g.trim().isEmpty) return '';
  final uncounted = kSheetUncountedSeats[seasonId]
          ?.any((e) => e.$1 == date && e.$2 == row.b) ??
      false;
  return uncounted ? '' : row.b;
}

/// A season 17+ player row's win as the sheet counts it: COUNTIFS(Бал = 1),
/// whatever the role and result say (season 17, 23.04.2023: two civilians
/// scored 1 in a mafia win).
String _sheetWin(GamesDataSeason row) => double.tryParse(row.g) == 1
    ? GameValues.yes.sheetValues.first
    : GameValues.no.sheetValues.first;

/// The ПУ seat as the sheet counts it: only when that seat's КХ cell holds a
/// number, since ПУ is COUNTIFS(КХ > -1) (season 21: Tina; season 22: Braun).
int _sheetFirstKilled(String puCell, List<GamesDataSeason> playerRows) {
  final seat = int.tryParse(puCell) ?? 0;
  if (seat < 1 || seat > playerRows.length) return 0;
  return double.tryParse(playerRows[seat - 1].i) == null ? 0 : seat;
}

Game _buildGame(int seasonId, List<GamesDataSeason> p, {bool sheet = false}) {
  if (seasonId <= kOldFormatMaxSeason) {
    return Game(
      seasonId: seasonId,
      players: _fillBlanks(p.map((r) => r.b).toList()),
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
      // The sheet's Балы add up column G on every row (SUMIFS): the first
      // killed's best move, and also bonuses or minuses on other seats.
      bestMovePoints: () {
        final row = p.where((r) => r.f == GameValues.yes.sheetValues.first);
        return row.isEmpty ? 0.0 : (double.tryParse(row.first.g) ?? 0.0);
      }(),
      additionalPoints: p
          .map((r) => r.f == GameValues.yes.sheetValues.first
              ? 0.0
              : double.tryParse(r.g) ?? 0.0)
          .toList(),
      wonByPlayer: p.map((r) => r.d).toList(),
      penaltyPoints: p
          .map((r) =>
              r.e == GameValues.yes.sheetValues.first ? -1.0 : 0.0)
          .toList(),
      bestMove: const [],
    );
  }

  if (seasonId <= kMidFormatMaxSeason) {
    final firstKilled = int.tryParse(p[1].c) ?? 0;
    return Game(
      seasonId: seasonId,
      players: _fillBlanks(p.map((r) => r.g).toList()),
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
      host: _parseHost(p[8].c),
      date: p[9].b.trim() == 'Дата' ? _parseSheetDate(p[9].c) : null,
    );
  }

  if (seasonId <= kLegacyMaxSeason) {
    final firstKilled = int.tryParse(p[1].c) ?? 0;
    final host = _parseHost(p[8].c);
    final date = p[9].b.trim() == 'Дата' ? _parseSheetDate(p[9].c) : null;
    final cityWon = _getVictoryTeam(p[0].c);
    // A game with a blank result the sheet still counts: played, lost by all.
    final unresolved = sheet &&
        p[0].c.trim().isEmpty &&
        (kSheetCountedUnresolvedGames[seasonId]
                ?.any((e) => e.$1 == date && e.$2 == host && e.$3 == p[0].g) ??
            false);
    return Game(
      seasonId: seasonId,
      players: _fillBlanks(p.map((r) => r.g).toList()),
      roles: p.map((r) => r.h).toList(),
      cityWon: unresolved ? false : cityWon,
      wonByPlayer: unresolved
          ? List.filled(p.length, GameValues.no.sheetValues.first)
          : null,
      firstKilled: firstKilled,
      bestMovePoints: _bestMovePointsOldFormat(firstKilled, p.map((r) => r.j).toList()),
      bestMove: [
        int.tryParse(p[2].c) ?? 0,
        int.tryParse(p[2].d) ?? 0,
        int.tryParse(p[2].e) ?? 0,
      ],
      additionalPoints:
          p.map((r) => double.tryParse(r.i) ?? 0.0).toList(),
      host: host,
      date: date,
    );
  }

  // Season 17–28: chunk of 14 rows; player rows are p[2]..p[11]
  final playerRows = p.sublist(2, 12);
  final firstKilled = sheet
      ? _sheetFirstKilled(p[12].b, playerRows)
      : int.tryParse(p[12].b) ?? 0;
  final date = p[0].a.trim() == 'Дата' ? _parseSheetDate(p[0].b) : null;
  final players = _fillBlanks(playerRows
      .map((r) => sheet ? _sheetCountedName(seasonId, date, r) : r.b)
      .toList());
  final wonByPlayer = sheet ? playerRows.map(_sheetWin).toList() : null;

  if (seasonId <= kPreProtocolMaxSeason) {
    return Game(
      seasonId: seasonId,
      players: players,
      wonByPlayer: wonByPlayer,
      roles: playerRows.map((r) => r.c).toList(),
      cityWon: _getVictoryTeam(p.last.c),
      firstKilled: firstKilled,
      bestMovePoints: firstKilled == 0
          ? 0.0
          : _tryParseDouble(p.map((r) => r.i).toList(), firstKilled + 1),
      bestMove: [
        int.tryParse(p[12].d) ?? 0,
        int.tryParse(p[12].e) ?? 0,
        int.tryParse(p[12].f) ?? 0,
      ],
      additionalPoints:
          playerRows.map((r) => double.tryParse(r.j) ?? 0.0).toList(),
      autoAdditionalPoints: seasonId <= kAutoPointsMaxSeason
          ? playerRows.map((r) => double.tryParse(r.h) ?? 0.0).toList()
          : null,
      penaltyPoints: seasonId > kAutoPointsMaxSeason
          ? playerRows.map((r) => double.tryParse(r.h) ?? 0.0).toList()
          : null,
      host: _hostLabels.contains(p[0].c.trim()) ? _parseHost(p[0].d) : null,
      date: date,
    );
  }

  // Season 29+: same 14-row chunk layout + extra columns K–Q
  // Parse protocol entries from rows p[2]..p[6] (up to 5 night kills)
  final protocolEntries = <ProtocolEntry>[];
  for (int pi = 0; pi < 5; pi++) {
    final row = p[2 + pi];
    final killedSlot = int.tryParse(row.n);
    if (killedSlot == null || killedSlot == 0) continue;
    final guesses = [row.o, row.p, row.q]
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .where((v) => v != 0)
        .toList();
    protocolEntries.add(ProtocolEntry(
      killedSlot: killedSlot,
      colorGuesses: guesses,
    ));
  }

  // Parse support five from p[12] columns d–h
  final supportFive = [p[12].d, p[12].e, p[12].f, p[12].g, p[12].h]
      .map((s) => int.tryParse(s))
      .whereType<int>()
      .where((v) => v != 0)
      .toList();

  return Game(
    seasonId: seasonId,
    players: players,
    wonByPlayer: wonByPlayer,
    roles: playerRows.map((r) => r.c).toList(),
    cityWon: _getVictoryTeam(p.last.c),
    firstKilled: firstKilled,
    bestMovePoints: firstKilled == 0
        ? 0.0
        : _tryParseDouble(p.map((r) => r.i).toList(), firstKilled + 1),
    bestMove: const [],
    additionalPoints:
        playerRows.map((r) => double.tryParse(r.j) ?? 0.0).toList(),
    penaltyPoints:
        playerRows.map((r) => double.tryParse(r.h) ?? 0.0).toList(),
    protocolAdditionalPoints:
        playerRows.map((r) => double.tryParse(r.k) ?? 0.0).toList(),
    protocolPenaltyPoints:
        playerRows.map((r) => double.tryParse(r.l) ?? 0.0).toList(),
    protocol: protocolEntries.isEmpty ? null : protocolEntries,
    supportFive: supportFive.isEmpty ? null : supportFive,
    host: _hostLabels.contains(p[0].c.trim()) ? _parseHost(p[0].d) : null,
    date: date,
  );
}

double _bestMovePointsOldFormat(
    int firstKilled, List<String> jColumn) {
  if (firstKilled == 0) return 0.0;
  try {
    return double.parse(jColumn[firstKilled - 1]);
  } catch (_) {
    return 0.0;
  }
}

double _tryParseDouble(List<String> column, int index) {
  try {
    return double.parse(column[index]);
  } catch (_) {
    return 0.0;
  }
}

bool? _getVictoryTeam(String s) {
  if (GameValues.mafiaWon.sheetValues.contains(s)) return false;
  if (GameValues.cityWon.sheetValues.contains(s)) return true;
  return null;
}

const _hostLabels = {'Ведущий', 'Ведучий'};

String? _parseHost(String s) {
  final v = s.trim();
  if (v.isEmpty || _hostLabels.contains(v)) return null;
  return v;
}

/// Sheet dates arrive as an ISO timestamp (local midnight exported as UTC,
/// e.g. 2019-03-04T22:00:00.000Z), a plain `YYYY-MM-DD`, `M/D/YYYY`, or a
/// Sheets serial day number. Returns UTC midnight of the game day.
DateTime? _parseSheetDate(String s) {
  final v = s.trim();
  if (v.isEmpty) return null;
  final serial = int.tryParse(v);
  if (serial != null) {
    final d = DateTime.utc(1899, 12, 30).add(Duration(days: serial));
    return DateTime.utc(d.year, d.month, d.day);
  }
  if (v.contains('/')) {
    final parts = v.split('/');
    if (parts.length != 3) return null;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (m == null || d == null || y == null) return null;
    return DateTime.utc(y, m, d);
  }
  final parsed = DateTime.tryParse(v);
  if (parsed == null) return null;
  // Shift by 12h so a local-midnight timestamp lands on the right day.
  final shifted = v.contains('T') ? parsed.toUtc().add(const Duration(hours: 12)) : parsed;
  return DateTime.utc(shifted.year, shifted.month, shifted.day);
}
