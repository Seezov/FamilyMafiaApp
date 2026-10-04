import 'dart:developer' as developer;

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/services/rating_formulas.dart';

export 'package:family_mafia_app/services/firestore_rest.dart';

// Games recorded on the site's /host/ page (Firestore, season 32+).
// The season JSON for a firestore season is {"format": "firestore", "games": [...]},
// each game a plain map in the shape documented in the game-hosting spec.

double _num(Object? v) => (v as num?)?.toDouble() ?? 0.0;

bool? _cityWon(Object? result) => switch (result) {
      'city' => true,
      'mafia' => false,
      _ => null,
    };

Game gameFromFirestore(int seasonId, Map<String, dynamic> doc) {
  final seats = (doc['seats'] as List).cast<Map<String, dynamic>>();
  final roles = [for (final s in seats) s['role'] as String];
  final firstKilled = (doc['firstKilled'] as num?)?.toInt() ?? 0;
  final supportFive =
      ((doc['supportFive'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
  final protocol = [
    for (final p in ((doc['protocol'] as List?) ?? const []).cast<Map<String, dynamic>>())
      ProtocolEntry(
        killedSlot: (p['slot'] as num).toInt(),
        colorGuesses: switch (p['color']) {
          {'slot': final num slot, 'black': final bool black} =>
            [black ? -slot.toInt() : slot.toInt()],
          _ => const [],
        },
        sheriffVersion: (p['version'] as num?)?.toInt(),
      ),
  ];
  final date = DateTime.tryParse(doc['date'] as String? ?? '');
  final host = (doc['host'] as String?)?.trim();
  return Game(
    seasonId: seasonId,
    players: [for (final s in seats) (s['player'] as String).trim()],
    roles: roles,
    cityWon: _cityWon(doc['result']),
    firstKilled: firstKilled,
    bestMovePoints:
        firstKilled == 0 ? 0.0 : calculateSupportFivePoints(supportFive, roles),
    bestMove: const [],
    additionalPoints: [for (final s in seats) _num(s['additional'])],
    penaltyPoints: [for (final s in seats) _num(s['penalty'])],
    protocolAdditionalPoints: [for (final s in seats) _num(s['protocolAdditional'])],
    protocolPenaltyPoints: [for (final s in seats) _num(s['protocolPenalty'])],
    fouls: [for (final s in seats) (s['fouls'] as num?)?.toInt() ?? 0],
    protocol: protocol.isEmpty ? null : protocol,
    supportFive: supportFive.isEmpty ? null : supportFive,
    host: host == null || host.isEmpty ? null : host,
    date: date == null ? null : DateTime.utc(date.year, date.month, date.day),
  );
}

List<Game> gamesFromFirestoreSnapshot(int seasonId, Map<String, dynamic> snapshot) {
  final docs = ((snapshot['games'] as List?) ?? const []).cast<Map<String, dynamic>>().toList()
    ..sort((a, b) {
      final byDate = (a['date'] as String).compareTo(b['date'] as String);
      if (byDate != 0) return byDate;
      final byTable = (a['table'] as num).compareTo(b['table'] as num);
      if (byTable != 0) return byTable;
      return (a['gameNumber'] as num).compareTo(b['gameNumber'] as num);
    });
  final games = <Game>[];
  for (final d in docs) {
    // Firestore rules check only the outline of a game; one malformed document
    // must not stop the whole season (and the app) from loading.
    if (!_isWellFormed(d)) {
      developer.log('skipping malformed game ${d['id']}', name: 'firestore_games');
      continue;
    }
    games.add(gameFromFirestore(seasonId, d));
  }
  return games;
}

bool _isSlot(Object? v) => v is num && v == v.toInt() && v >= 1 && v <= 10;

bool _isWellFormed(Map<String, dynamic> d) {
  final seats = d['seats'];
  if (seats is! List || seats.length != 10) return false;
  for (final s in seats) {
    if (s is! Map) return false;
    final player = s['player'];
    if (player is! String || player.trim().isEmpty) return false;
    if (Role.findByValue(s['role'] as String? ?? '') == null) return false;
  }
  if (d['date'] is! String || d['table'] is! num || d['gameNumber'] is! num) return false;
  final firstKilled = d['firstKilled'] ?? 0;
  if (firstKilled != 0 && !_isSlot(firstKilled)) return false;
  final support = d['supportFive'] ?? const [];
  if (support is! List || support.any((g) => g is! num || !_isSlot(g.abs()))) return false;
  final protocol = d['protocol'] ?? const [];
  if (protocol is! List) return false;
  for (final p in protocol) {
    if (p is! Map || !_isSlot(p['slot'])) return false;
    if (p['version'] != null && !_isSlot(p['version'])) return false;
    final c = p['color'];
    if (c != null && (c is! Map || !_isSlot(c['slot']) || c['black'] is! bool)) return false;
  }
  return true;
}
