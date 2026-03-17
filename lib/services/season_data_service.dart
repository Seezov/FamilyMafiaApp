import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:family_mafia_app/services/sheets_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SeasonDataService {
  final SheetsService? _sheetsService;
  final SeasonCacheService _cacheService;

  SeasonDataService({
    required SheetsService? sheetsService,
    required SeasonCacheService cacheService,
  })  : _sheetsService = sheetsService,
        _cacheService = cacheService;

  /// Loads the JSON string for a single season.
  /// Returns null if the season could not be loaded (remote with no cache).
  Future<String?> loadSeasonJson(SeasonConfig config) async {
    switch (config.source) {
      case BundledSource(:final assetPath):
        return rootBundle.loadString(assetPath);

      case RemoteSource() when _sheetsService == null:
        // No API key → try cache only
        final cached = await _cacheService.getCachedSeasonData(config.id);
        if (cached != null) {
          debugPrint('Season ${config.id}: using cached data (no API key)');
          return cached;
        }
        debugPrint('Season ${config.id}: skipped (no API key, no cache)');
        return null;

      case final RemoteSource remote:
        return _loadRemoteSeason(config.id, remote);
    }
  }

  Future<String?> _loadRemoteSeason(int seasonId, RemoteSource remote) async {
    try {
      // Lightweight freshness check: compare row counts
      final remoteRowCount = await _sheetsService!.getDataRowCount(remote);
      final cachedRowCount = await _cacheService.getCachedRowCount(seasonId);

      if (cachedRowCount != null && cachedRowCount == remoteRowCount) {
        final cached = await _cacheService.getCachedSeasonData(seasonId);
        if (cached != null) {
          debugPrint('Season $seasonId: cache fresh ($remoteRowCount rows)');
          return cached;
        }
      }

      // Fetch full data
      debugPrint('Season $seasonId: fetching from Sheets ($remoteRowCount rows)');
      final json = await _sheetsService.fetchSeasonData(remote);
      await _cacheService.cacheSeasonData(seasonId, json, remoteRowCount);
      return json;
    } catch (e) {
      debugPrint('Season $seasonId: fetch failed ($e), trying cache');
      final cached = await _cacheService.getCachedSeasonData(seasonId);
      if (cached != null) return cached;
      debugPrint('Season $seasonId: no cache available, skipping');
      return null;
    }
  }
}
