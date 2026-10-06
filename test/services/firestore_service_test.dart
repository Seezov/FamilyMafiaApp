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
  @override Future<String?> getCachedClubSeasons() async => null;
  @override Future<void> cacheClubSeasons(String json) async {}
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
      'syncedAt': '2026-12-03T20:00:00Z',
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
    expect(jsonDecode(first!), {'format': 'firestore', 'games': [], 'syncedAt': null});

    fail = true;
    expect(await service.loadSeasonJson(_config), first);
  });

  test('without a service (site export) only the cache/snapshot is used', () async {
    final cache = _MemCache()..data[32] = '{"format":"firestore","games":[]}';
    final service = SeasonDataService(sheetsService: null, cacheService: cache);
    expect(await service.loadSeasonJson(_config), cache.data[32]);
  });

  group('syncing a cached season', () {
    Map<String, dynamic> doc(String id, int season, String host) => {
          'name': 'projects/p1/databases/(default)/documents/games/$id',
          'fields': {'season': {'integerValue': '$season'}, 'host': {'stringValue': host}},
        };
    String cached(List<Map<String, dynamic>> games, String? syncedAt) =>
        jsonEncode({'format': 'firestore', 'games': games, 'syncedAt': syncedAt});

    // Routes runQuery / runAggregationQuery; [delta] answers the updatedAt query,
    // [full] the whole-season one, [count] the aggregation.
    ({_FakeAdapter adapter, List<Map> queries}) server({
      List<Map<String, dynamic>> delta = const [],
      List<Map<String, dynamic>> full = const [],
      required int count,
    }) {
      final queries = <Map>[];
      final adapter = _FakeAdapter((o) {
        final body = o.data as Map;
        queries.add(body);
        if (o.uri.path.endsWith(':runAggregationQuery')) {
          return _json([{'result': {'aggregateFields': {'n': {'integerValue': '$count'}}},
              'readTime': '2026-12-05T10:00:01Z'}]);
        }
        final field = body['structuredQuery']['where']['fieldFilter']['field']['fieldPath'];
        final docs = field == 'updatedAt' ? delta : full;
        return _json([
          for (final d in docs) {'document': d, 'readTime': '2026-12-05T10:00:00Z'},
          if (docs.isEmpty) {'readTime': '2026-12-05T10:00:00Z'},
        ]);
      });
      return (adapter: adapter, queries: queries);
    }

    SeasonDataService serviceFor(_FakeAdapter adapter, _MemCache cache) => SeasonDataService(
        sheetsService: null,
        firestoreService: FirestoreService(dio: Dio()..httpClientAdapter = adapter),
        cacheService: cache);

    test('reads only games changed since the last sync (minus a margin) and merges them', () async {
      final cache = _MemCache()
        ..data[32] = cached([
          {'id': 'a', 'season': 32, 'host': 'Old'},
          {'id': 'b', 'season': 32, 'host': 'B'},
          {'id': 'm', 'season': 32, 'host': 'Moved'},
        ], '2026-12-04T12:00:00.000Z');
      final s = server(delta: [doc('a', 32, 'New'), doc('c', 32, 'C'), doc('m', 33, 'Moved'), doc('z', 33, 'Other')],
          count: 3);

      final json = jsonDecode((await serviceFor(s.adapter, cache).loadSeasonJson(_config))!);

      final where = s.queries.first['structuredQuery']['where']['fieldFilter'];
      expect(where['field']['fieldPath'], 'updatedAt');
      expect(where['op'], 'GREATER_THAN');
      expect(where['value'], {'timestampValue': '2026-12-04T11:55:00.000Z'});
      final countWhere = s.queries.last['structuredAggregationQuery']['structuredQuery']['where']['fieldFilter'];
      expect(countWhere['value'], {'integerValue': '32'});
      expect(s.queries, hasLength(2)); // no full season query
      expect(json['syncedAt'], '2026-12-05T10:00:00Z');
      expect({for (final g in json['games'] as List) g['id']: g['host']}, {'a': 'New', 'b': 'B', 'c': 'C'});
      expect(cache.data[32], jsonEncode(json));
    });

    test('a count that differs from the merged cache (a deleted game) refetches the season', () async {
      final cache = _MemCache()
        ..data[32] = cached([{'id': 'a', 'season': 32}, {'id': 'gone', 'season': 32}], '2026-12-04T12:00:00Z');
      final s = server(full: [doc('a', 32, 'A')], count: 1);

      final json = jsonDecode((await serviceFor(s.adapter, cache).loadSeasonJson(_config))!);

      expect(s.queries, hasLength(3));
      expect(s.queries.last['structuredQuery']['where']['fieldFilter']['field']['fieldPath'], 'season');
      expect(json['games'], [{'id': 'a', 'season': 32, 'host': 'A'}]);
    });

    test('a cache without syncedAt is fetched in full', () async {
      final cache = _MemCache()..data[32] = '{"format":"firestore","games":[]}';
      final s = server(full: [doc('a', 32, 'A')], count: 1);

      final json = jsonDecode((await serviceFor(s.adapter, cache).loadSeasonJson(_config))!);

      expect(s.queries, hasLength(1));
      expect(json['games'], [{'id': 'a', 'season': 32, 'host': 'A'}]);
      expect(json['syncedAt'], '2026-12-05T10:00:00Z');
    });

    test('a failed sync falls back to the cache', () async {
      final cache = _MemCache()..data[32] = cached([{'id': 'a', 'season': 32}], '2026-12-04T12:00:00Z');
      final adapter = _FakeAdapter((o) => _json({'error': 'x'}, 503));

      expect(await serviceFor(adapter, cache).loadSeasonJson(_config), cache.data[32]);
    });
  });
}
