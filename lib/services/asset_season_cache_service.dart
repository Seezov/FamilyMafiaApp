import 'package:family_mafia_app/services/prefetch_paths.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:flutter/services.dart';

/// Read-only cache over the build-time snapshot in `assets/prefetched/`.
/// Used on the web: there is no API key and no file system there, so the
/// snapshot written by `tool/prefetch_seasons.dart` stands in for the cache.
class AssetSeasonCacheService implements SeasonCacheService {
  final AssetBundle _bundle;

  AssetSeasonCacheService(this._bundle);

  Future<String?> _tryLoad(String file) async {
    try {
      return await _bundle.loadString('$prefetchedDir/$file', cache: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> getCachedSeasonData(int seasonId) =>
      _tryLoad(prefetchedSeasonFile(seasonId));

  @override
  Future<int?> getCachedRowCount(int seasonId) async => null;

  @override
  Future<void> cacheSeasonData(int seasonId, String jsonData, int rowCount) async {}

  @override
  Future<void> invalidateSeasonCache(int seasonId) async {}

  @override
  Future<String?> getCachedRemoteConfig() => _tryLoad(prefetchedConfigFile);

  @override
  Future<void> cacheRemoteConfig(String jsonData) async {}
}
