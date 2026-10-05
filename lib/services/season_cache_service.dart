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

  /// The last fetched Firestore `config/club` (see ClubConfig).
  Future<String?> getCachedClubConfig();

  Future<void> cacheClubConfig(String jsonData);

  /// The last fetched Firestore `config/players`, app players.json shape.
  Future<String?> getCachedPlayers();

  Future<void> cachePlayers(String jsonData);

  /// The last fetched Firestore `config/seasons` list (ClubSeason JSON).
  Future<String?> getCachedClubSeasons();

  Future<void> cacheClubSeasons(String jsonData);
}
