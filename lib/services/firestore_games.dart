import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/services/rating_formulas.dart';

// Games recorded on the site's /host/ page (Firestore, season 32+).
// The season JSON for a firestore season is {"format": "firestore", "games": [...]},
// each game a plain map in the shape documented in the game-hosting spec.

const firestoreSnapshotFormat = 'firestore';

/// Firestore REST typed values (`{"integerValue": "3"}` …) → plain JSON.
Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields) =>
    fields.map((k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)));

Object? _decodeValue(Map<String, dynamic> v) {
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('arrayValue')) {
    final values = (v['arrayValue'] as Map)['values'] as List? ?? const [];
    return values.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
  }
  if (v.containsKey('mapValue')) {
    final f = (v['mapValue'] as Map)['fields'] as Map<String, dynamic>? ?? const {};
    return decodeFirestoreFields(f);
  }
  return null; // nullValue and anything unknown
}

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
  return [for (final d in docs) gameFromFirestore(seasonId, d)];
}
