import 'dart:convert';

import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_rest.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:family_mafia_app/services/sheets_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How far before the last sync a Firestore season re-reads changed games:
/// `updatedAt` is the request time, which can precede the commit.
const firestoreSyncMargin = Duration(minutes: 5);

class SeasonDataService {
  final SheetsService? _sheetsService;
  final FirestoreService? _firestoreService;
  final SeasonCacheService _cacheService;

  SeasonDataService({
    required SheetsService? sheetsService,
    FirestoreService? firestoreService,
    required SeasonCacheService cacheService,
  })  : _sheetsService = sheetsService,
        _firestoreService = firestoreService,
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

      case FirestoreSource() when _firestoreService == null:
        // Site export: read the build-time snapshot only.
        return _cacheService.getCachedSeasonData(config.id);

      case final FirestoreSource firestore:
        return _loadFirestoreSeason(config.id, firestore);
    }
  }

  Future<String?> _loadFirestoreSeason(int seasonId, FirestoreSource source) async {
    try {
      final cached = await _cacheService.getCachedSeasonData(seasonId);
      final json = await _syncFirestoreSeason(seasonId, source, cached) ??
          await _firestoreService!.fetchSeasonGames(source, seasonId);
      await _cacheService.cacheSeasonData(seasonId, json, 0);
      return json;
    } catch (e) {
      debugPrint('Season $seasonId: Firestore fetch failed ($e), trying cache');
      return _cacheService.getCachedSeasonData(seasonId);
    }
  }

  /// Brings a cached season up to date by reading only the games written since
  /// its last sync, plus a count to catch deletions — a couple of reads instead
  /// of the whole season. Null when it has to be fetched in full: nothing
  /// cached, a cache from before syncs, or a count that doesn't match.
  Future<String?> _syncFirestoreSeason(int seasonId, FirestoreSource source, String? cachedJson) async {
    if (cachedJson == null) return null;
    final cached = jsonDecode(cachedJson);
    final syncedAt = cached is Map ? DateTime.tryParse('${cached['syncedAt']}') : null;
    if (syncedAt == null) return null;
    final firestore = _firestoreService!;
    // A write stamped just before the last read can commit just after it.
    final since = syncedAt.subtract(firestoreSyncMargin).toUtc().toIso8601String();
    final (changed, readTime) = await firestore.fetchGamesUpdatedSince(source, since);
    final games = {
      for (final g in (cached['games'] as List).cast<Map<String, dynamic>>()) g['id'] as String: g,
    };
    for (final g in changed) {
      // A game moved to another season leaves this one.
      if (g['season'] == seasonId) {
        games[g['id'] as String] = g;
      } else {
        games.remove(g['id']);
      }
    }
    if (await firestore.countSeasonGames(source, seasonId) != games.length) return null;
    debugPrint('Season $seasonId: synced ${changed.length} changed game(s)');
    return jsonEncode({
      'format': firestoreSnapshotFormat,
      'games': games.values.toList(),
      'syncedAt': readTime ?? cached['syncedAt'],
    });
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
