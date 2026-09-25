/// Where remote season data and the remote config are kept between runs.
/// Mobile: [IoSeasonCacheService] (file system). Web: [AssetSeasonCacheService]
/// (read-only build-time snapshot).
abstract interface class SeasonCacheService {
  Future<String?> getCachedSeasonData(int seasonId);

  Future<int?> getCachedRowCount(int seasonId);

  Future<void> cacheSeasonData(int seasonId, String jsonData, int rowCount);

  Future<void> invalidateSeasonCache(int seasonId);

  Future<String?> getCachedRemoteConfig();

  Future<void> cacheRemoteConfig(String jsonData);
}
