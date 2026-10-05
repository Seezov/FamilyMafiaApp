import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_rest.dart';

/// The Firebase project behind /host/ and config/club.
const kFirebaseProjectId = 'familymafiaapp';

/// Reads a season's games from Firestore over REST. Games are publicly
/// readable (firestore.rules), so no key or sign-in is needed.
class FirestoreService {
  final Dio _dio;

  FirestoreService({required Dio dio}) : _dio = dio;

  /// Returns the season snapshot JSON: {"format": "firestore", "games": [...]}.
  Future<String> fetchSeasonGames(FirestoreSource source, int seasonId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '${source.projectId}/databases/(default)/documents:runQuery');
    final response = await _dio.postUri<List<dynamic>>(uri, data: {
      'structuredQuery': {
        'from': [{'collectionId': 'games'}],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'season'},
            'op': 'EQUAL',
            'value': {'integerValue': '$seasonId'},
          },
        },
      },
    });
    final games = <Map<String, dynamic>>[];
    for (final row in response.data ?? const []) {
      final document = (row as Map<String, dynamic>)['document'] as Map<String, dynamic>?;
      if (document == null) continue;
      final fields = document['fields'] as Map<String, dynamic>? ?? const {};
      games.add({
        'id': (document['name'] as String).split('/').last,
        ...decodeFirestoreFields(fields),
      });
    }
    return jsonEncode({'format': firestoreSnapshotFormat, 'games': games});
  }

  /// `config/club` as JSON (tournaments, rejectedCandidates, gameLimits), or
  /// null when the document doesn't exist yet. Public read, no key.
  Future<String?> fetchClubConfig(String projectId) async {
    final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
        '$projectId/databases/(default)/documents/config/club');
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      final fields = decodeFirestoreFields(
          response.data?['fields'] as Map<String, dynamic>? ?? const {});
      return jsonEncode({
        'tournaments': fields['tournaments'] ?? const [],
        'rejectedCandidates': fields['rejectedCandidates'] ?? const [],
        'gameLimits': fields['gameLimits'] ?? const {},
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
