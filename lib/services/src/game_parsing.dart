part of '../season_loader.dart';

// ── JSON → Game objects ───────────────────────────────────────────────────

List<Game> _getGamesDataSeason(
    int seasonId, List<GamesDataSeason> rawData) {
  final chunkSize = seasonId <= kLegacyMaxSeason ? kOldChunkSize : kNewChunkSize;
  return rawData.chunked(chunkSize).map((p) => _buildGame(seasonId, p)).toList();
}

Game _buildGame(int seasonId, List<GamesDataSeason> p) {
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
    );
  }

  if (seasonId <= kLegacyMaxSeason) {
    final firstKilled = int.tryParse(p[1].c) ?? 0;
    return Game(
      seasonId: seasonId,
      players: _fillBlanks(p.map((r) => r.g).toList()),
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

  // Season 17–28: chunk of 14 rows; player rows are p[2]..p[11]
  final firstKilled = int.tryParse(p[12].b) ?? 0;
  final playerRows = p.sublist(2, 12);

  if (seasonId <= kPreProtocolMaxSeason) {
    return Game(
      seasonId: seasonId,
      players: _fillBlanks(playerRows.map((r) => r.b).toList()),
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
    players: _fillBlanks(playerRows.map((r) => r.b).toList()),
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
