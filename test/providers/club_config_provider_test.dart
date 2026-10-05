import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemCache implements SeasonCacheService {
  String? club;
  @override Future<String?> getCachedSeasonData(int id) async => null;
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async {}
  @override Future<void> invalidateSeasonCache(int id) async {}
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => club;
  @override Future<String?> getCachedPlayers() async => null;
  @override Future<void> cachePlayers(String json) async {}
  @override Future<void> cacheClubConfig(String json) async => club = json;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore(this.result) : super(dio: Dio());
  final Future<String?> Function() result;
  @override
  Future<String?> fetchClubConfig(String projectId) => result();
}

String _club(String name) => jsonEncode({
      'tournaments': [
        {'season': 31, 'type': 'minicap', 'name': name, 'games': 4, 'podium': []},
      ],
      'rejectedCandidates': [],
      'gameLimits': {},
    });

ProviderContainer _container(_MemCache cache, FirestoreService? firestore) {
  final c = ProviderContainer(overrides: [
    envJsonProvider.overrideWith((ref) async => const <String, String>{}),
    seasonCacheServiceProvider.overrideWithValue(cache),
    firestoreServiceProvider.overrideWithValue(firestore),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('live config/club wins and is cached', () async {
    final cache = _MemCache();
    final c = _container(cache, _FakeFirestore(() async => _club('Live cup')));
    await c.read(parsedConfigProvider.future);
    await c.read(clubConfigProvider.future);
    expect(c.read(tournamentsProvider).map((t) => t.name), ['Live cup']);
    expect(cache.club, _club('Live cup'));
  });

  test('a failed fetch falls back to the cached copy', () async {
    final cache = _MemCache()..club = _club('Cached cup');
    final c = _container(cache, _FakeFirestore(() async => throw DioException(requestOptions: RequestOptions())));
    await c.read(parsedConfigProvider.future);
    await c.read(clubConfigProvider.future);
    expect(c.read(tournamentsProvider).map((t) => t.name), ['Cached cup']);
  });

  test('no club config: no tournaments (the JSON config no longer has them)', () async {
    final c = _container(_MemCache(), null);
    await c.read(parsedConfigProvider.future);
    expect(await c.read(clubConfigProvider.future), isNull);
    expect(c.read(tournamentsProvider), isEmpty);
  });

  test('an unparsable live document is not cached; the cached copy wins', () async {
    final cache = _MemCache()..club = _club('Cached cup');
    final bad = jsonEncode({'tournaments': [], 'rejectedCandidates': [], 'gameLimits': {'31': 'x'}});
    final c = _container(cache, _FakeFirestore(() async => bad));
    await c.read(parsedConfigProvider.future);
    await c.read(clubConfigProvider.future);
    expect(c.read(tournamentsProvider).map((t) => t.name), ['Cached cup']);
    expect(cache.club, _club('Cached cup'));
  });
}
