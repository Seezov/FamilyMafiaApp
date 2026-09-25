// Where the web build's snapshot of remote data lives. Written by
// tool/prefetch_seasons.dart in CI, read by AssetSeasonCacheService.
// Pure Dart on purpose: the CI script imports it outside Flutter.

const String prefetchedDir = 'assets/prefetched';

const String prefetchedConfigFile = 'remote_config.json';

String prefetchedSeasonFile(int seasonId) => 'season$seasonId.json';
