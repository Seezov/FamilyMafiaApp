import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/asset_season_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/map_asset_bundle.dart';

const _snapshotConfig = '{"seasons": [{"id": 99, "title": "Season 99", '
    '"gameLimit": 60, "gamesMultiplier": 0.0, "source": "remote", '
    '"spreadsheetId": "sheet", "sheetName": "Sheet1", "range": "A:J"}]}';

ProviderContainer _container(Map<String, String> snapshot) {
  final container = ProviderContainer(overrides: [
    envJsonProvider.overrideWith((ref) async => const <String, String>{}),
    seasonCacheServiceProvider
        .overrideWithValue(AssetSeasonCacheService(MapAssetBundle(snapshot))),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('with no config URL, the snapshot remote config wins over the bundled one', () async {
    final container = _container({'assets/prefetched/remote_config.json': _snapshotConfig});
    await container.read(parsedConfigProvider.future);
    expect(container.read(seasonConfigsProvider).map((c) => c.id), [99]);
  });

  test('with no config URL and no snapshot, the bundled season_config.json is used', () async {
    final container = _container({});
    await container.read(parsedConfigProvider.future);
    final ids = container.read(seasonConfigsProvider).map((c) => c.id).toList();
    expect(ids, isNotEmpty);
    expect(ids, isNot(contains(99)));
    expect(ids.first, 0);
  });

  test('a cache that throws falls through to the bundled config instead of failing', () async {
    final container = ProviderContainer(overrides: [
      envJsonProvider.overrideWith((ref) async => const <String, String>{}),
      seasonCacheServiceProvider.overrideWithValue(_ThrowingCache()),
    ]);
    addTearDown(container.dispose);
    await container.read(parsedConfigProvider.future);
    expect(container.read(seasonConfigsProvider).first.id, 0);
  });
}

class _ThrowingCache extends AssetSeasonCacheService {
  _ThrowingCache() : super(MapAssetBundle({}));

  @override
  Future<String?> getCachedRemoteConfig() => throw StateError('no file system');
}
