import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:family_mafia_app/services/season_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions o) respond;
  RequestOptions? last;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? s, Future<void>? c) async {
    last = options;
    return respond(options);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
    jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

class _MemCache implements SeasonCacheService {
  final data = <int, String>{};
  @override Future<String?> getCachedSeasonData(int id) async => data[id];
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async => data[id] = json;
  @override Future<void> invalidateSeasonCache(int id) async => data.remove(id);
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => null;
  @override Future<String?> getCachedPlayers() async => null;
  @override Future<void> cachePlayers(String json) async {}
  @override Future<void> cacheClubConfig(String json) async {}
}

const _src = FirestoreSource(projectId: 'p1');
const _config = SeasonConfig(id: 32, title: 'S32', gameLimit: 40,
    smallLeagueMinGames: 15, gamesMultiplier: 0, source: _src);

void main() {
  group('fetchClubConfig', () {
    test('decodes config/club, dropping the author fields', () async {
      final adapter = _FakeAdapter((o) => _json({
            'name': 'projects/p1/databases/(default)/documents/config/club',
            'fields': {
              'tournaments': {'arrayValue': {'values': [
                {'mapValue': {'fields': {
                  'season': {'integerValue': '31'}, 'type': {'stringValue': 'minicap'},
                  'name': {'stringValue': 'Cup'}, 'games': {'integerValue': '4'},
                  'podium': {'arrayValue': {'values': [{'stringValue': 'A'}]}},
                }}},
              ]}},
              'gameLimits': {'mapValue': {'fields': {'31': {'integerValue': '41'}}}},
              'updatedAt': {'timestampValue': '2026-10-05T10:00:00Z'},
              'updatedBy': {'stringValue': 'u'},
            },
          }));
      final service = FirestoreService(dio: Dio()..httpClientAdapter = adapter);

      final json = await service.fetchClubConfig('p1');

      expect(adapter.last!.method, 'GET');
      expect(adapter.last!.uri.toString(),
          'https://firestore.googleapis.com/v1/projects/p1/databases/(default)/documents/config/club');
      expect(jsonDecode(json!), {
        'tournaments': [
          {'season': 31, 'type': 'minicap', 'name': 'Cup', 'games': 4, 'podium': ['A']},
        ],
        'rejectedCandidates': [],
        'gameLimits': {'31': 41},
      });
    });

    test('a missing document is null', () async {
      final service = FirestoreService(
          dio: Dio()..httpClientAdapter = _FakeAdapter((o) => _json({'error': {'code': 404}}, 404)));
      expect(await service.fetchClubConfig('p1'), isNull);
    });

    test('other errors throw', () async {
      final service = FirestoreService(
          dio: Dio()..httpClientAdapter = _FakeAdapter((o) => _json({'error': 'x'}, 503)));
      await expectLater(service.fetchClubConfig('p1'), throwsA(isA<DioException>()));
    });
  });

  test('runQuery filters by season and decodes documents', () async {
    final adapter = _FakeAdapter((o) => _json([
          {'document': {
            'name': 'projects/p1/databases/(default)/documents/games/abc',
            'fields': {'season': {'integerValue': '32'}, 'host': {'stringValue': 'Серпень'}},
          }},
          {'readTime': '2026-12-03T20:00:00Z'}, // trailing element without a document
        ]));
    final service = FirestoreService(dio: Dio()..httpClientAdapter = adapter);

    final snapshot = jsonDecode(await service.fetchSeasonGames(_src, 32));

    expect(adapter.last!.method, 'POST');
    expect(adapter.last!.uri.toString(),
        'https://firestore.googleapis.com/v1/projects/p1/databases/(default)/documents:runQuery');
    final where = (adapter.last!.data as Map)['structuredQuery']['where']['fieldFilter'];
    expect(where['value'], {'integerValue': '32'});
    expect(snapshot, {
      'format': 'firestore',
      'games': [{'id': 'abc', 'season': 32, 'host': 'Серпень'}],
    });
  });

  test('data service caches a fetch and falls back to the cache on failure', () async {
    final cache = _MemCache();
    var fail = false;
    final dio = Dio()..httpClientAdapter = _FakeAdapter(
        (o) => fail ? _json({'error': 'x'}, 503) : _json([]));
    final service = SeasonDataService(
        sheetsService: null, firestoreService: FirestoreService(dio: dio), cacheService: cache);

    final first = await service.loadSeasonJson(_config);
    expect(jsonDecode(first!), {'format': 'firestore', 'games': []});

    fail = true;
    expect(await service.loadSeasonJson(_config), first);
  });

  test('without a service (site export) only the cache/snapshot is used', () async {
    final cache = _MemCache()..data[32] = '{"format":"firestore","games":[]}';
    final service = SeasonDataService(sheetsService: null, cacheService: cache);
    expect(await service.loadSeasonJson(_config), cache.data[32]);
  });
}
