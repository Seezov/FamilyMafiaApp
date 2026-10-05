import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/annual_event.dart';
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

  /// Every `events` document as a JSON list of `{id, year, kind, …}` — only
  /// the event fields, never who saved it. Throws [FormatException] naming
  /// the document when one is malformed, so the build fails loudly.
  Future<String> fetchAnnualEvents(String projectId) async {
    final events = <Map<String, Object?>>[];
    String? token;
    do {
      final uri = Uri.parse('https://firestore.googleapis.com/v1/projects/'
              '$projectId/databases/(default)/documents/events')
          .replace(queryParameters: {'pageSize': '300', 'pageToken': ?token});
      final response = await _dio.getUri<Map<String, dynamic>>(uri);
      for (final d in (response.data?['documents'] as List?) ?? const []) {
        final doc = d as Map<String, dynamic>;
        final id = (doc['name'] as String).split('/').last;
        final fields = decodeFirestoreFields(doc['fields'] as Map<String, dynamic>? ?? const {});
        events.add(AnnualEvent.fromJson(fields, id: id).toJson());
      }
      token = response.data?['nextPageToken'] as String?;
    } while (token != null);
    return jsonEncode(events);
  }
}
