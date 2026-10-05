import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/club_season.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemCache implements SeasonCacheService {
  String? seasons;
  @override Future<String?> getCachedSeasonData(int id) async => null;
  @override Future<int?> getCachedRowCount(int id) async => null;
  @override Future<void> cacheSeasonData(int id, String json, int rows) async {}
  @override Future<void> invalidateSeasonCache(int id) async {}
  @override Future<String?> getCachedRemoteConfig() async => null;
  @override Future<void> cacheRemoteConfig(String json) async {}
  @override Future<String?> getCachedClubConfig() async => null;
  @override Future<void> cacheClubConfig(String json) async {}
  @override Future<String?> getCachedPlayers() async => null;
  @override Future<void> cachePlayers(String json) async {}
  @override Future<String?> getCachedClubSeasons() async => seasons;
  @override Future<void> cacheClubSeasons(String json) async => seasons = json;
}

class _FakeFirestore extends FirestoreService {
  _FakeFirestore(this.result) : super(dio: Dio());
  final Future<List<ClubSeason>?> Function() result;
  @override
  Future<List<ClubSeason>?> fetchClubSeasons(String projectId) => result();
}

const _s32 = ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 12, startDate: '2026-12-01');

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

  test('live club seasons are appended to the bundled config and cached', () async {
    final cache = _MemCache();
    final c = _container(cache, _FakeFirestore(() async => [_s32]));
    await c.read(parsedConfigProvider.future);
    final last = c.read(seasonConfigsProvider).last;
    expect(last.id, 32);
    expect(last.smallLeagueMinGames, 12);
    expect(jsonDecode(cache.seasons!), [_s32.toJson()]);
  });

  test('a failed fetch falls back to the cached seasons', () async {
    final cache = _MemCache()..seasons = jsonEncode([_s32.toJson()]);
    final c = _container(cache, _FakeFirestore(() async => throw DioException(requestOptions: RequestOptions())));
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 32);
  });

  test('invalid live seasons are ignored and not cached', () async {
    final cache = _MemCache();
    final c = _container(cache, _FakeFirestore(() async => const [
          ClubSeason(id: 40, title: 'Gap', smallLeagueMinGames: 15, startDate: '2026-12-01'),
        ]));
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 31);
    expect(cache.seasons, isNull);
  });

  test('no firestore and no cache: the JSON seasons only', () async {
    final c = _container(_MemCache(), null);
    await c.read(parsedConfigProvider.future);
    expect(c.read(seasonConfigsProvider).last.id, 31);
  });
}
