import 'package:dio/dio.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemCache implements SeasonCacheService {
  String? players;
  @override Future<String?> getCachedSeasonData(int id) async => null;
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async {}
  @override Future<void> invalidateSeasonCache(int id) async {}
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => null;
  @override Future<void> cacheClubConfig(String json) async {}
  @override Future<String?> getCachedPlayers() async => players;
  @override Future<void> cachePlayers(String json) async => players = json;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore(this.result) : super(dio: Dio());
  final Future<String?> Function() result;
  @override
  Future<String?> fetchPlayers(String projectId) => result();
}

const _live = '[{"id":0,"displayName":"Live"}]';
const _cached = '[{"id":0,"displayName":"Cached"}]';

ProviderContainer _container(_MemCache cache, FirestoreService? firestore) {
  final c = ProviderContainer(overrides: [
    seasonCacheServiceProvider.overrideWithValue(cache),
    firestoreServiceProvider.overrideWithValue(firestore),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the live roster wins and is cached', () async {
    final cache = _MemCache();
    final json = await _container(cache, _FakeFirestore(() async => _live)).read(playersJsonProvider.future);
    expect(json, _live);
    expect(cache.players, _live);
  });

  test('a failed or malformed fetch falls back to the cached copy', () async {
    final cache = _MemCache()..players = _cached;
    final c = _container(cache, _FakeFirestore(() async => throw const FormatException('roster: bad')));
    expect(await c.read(playersJsonProvider.future), _cached);
    expect(cache.players, _cached);
  });

  test('no live document and no cache: the bundled players.json', () async {
    final c = _container(_MemCache(), _FakeFirestore(() async => null));
    expect(await c.read(playersJsonProvider.future), contains('"displayName": "Anatolich"'));
  });
}
