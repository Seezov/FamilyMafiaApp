import 'package:family_mafia_app/services/asset_season_cache_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/map_asset_bundle.dart';

void main() {
  final bundle = MapAssetBundle({
    'assets/prefetched/season29.json': '[{"A":"1"}]',
    'assets/prefetched/remote_config.json': '{"seasons":[]}',
  });
  final cache = AssetSeasonCacheService(bundle);

  test('returns the snapshot of a prefetched season', () async {
    expect(await cache.getCachedSeasonData(29), '[{"A":"1"}]');
  });

  test('returns null for a season that is not in the snapshot', () async {
    expect(await cache.getCachedSeasonData(30), isNull);
  });

  test('returns the snapshot remote config', () async {
    expect(await cache.getCachedRemoteConfig(), '{"seasons":[]}');
  });

  test('returns null config when there is no snapshot (e.g. local run)', () async {
    expect(await AssetSeasonCacheService(MapAssetBundle({})).getCachedRemoteConfig(), isNull);
  });

  test('never reports a row count, so nothing asks it to compare freshness', () async {
    expect(await cache.getCachedRowCount(29), isNull);
  });

  test('writes and invalidation are no-ops and leave the snapshot readable', () async {
    await cache.cacheSeasonData(29, '[]', 0);
    await cache.cacheRemoteConfig('{}');
    await cache.invalidateSeasonCache(29);
    expect(await cache.getCachedSeasonData(29), '[{"A":"1"}]');
    expect(await cache.getCachedRemoteConfig(), '{"seasons":[]}');
  });
}
