// Where the web build's snapshot of remote data lives. Written by
// tool/prefetch_seasons.dart in CI, read by AssetSeasonCacheService.
// Pure Dart on purpose: the CI script imports it outside Flutter.

const String prefetchedDir = 'assets/prefetched';

const String prefetchedConfigFile = 'remote_config.json';

/// Firestore `config/club` (tournaments, final thresholds).
const String prefetchedClubConfigFile = 'club_config.json';

/// Firestore `events` (the annual rating's tournaments, series, marathons).
const String prefetchedAnnualEventsFile = 'annual_events.json';

String prefetchedSeasonFile(int seasonId) => 'season$seasonId.json';

/// Firestore `config/players` (the roster), in the app's players.json shape.
const String prefetchedPlayersFile = 'players.json';
