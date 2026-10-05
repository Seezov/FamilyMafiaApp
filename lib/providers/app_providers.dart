import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/club_config.dart';
import 'package:family_mafia_app/models/club_season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/asset_season_cache_service.dart';
import 'package:family_mafia_app/services/empty_seasons.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:family_mafia_app/services/io_season_cache_service.dart';
import 'package:family_mafia_app/services/season_cache_service.dart';
import 'package:family_mafia_app/services/season_data_service.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/services/sheets_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Optional overrides via --dart-define ──────────────────────────────────
const _dartDefineApiKey = String.fromEnvironment('SHEETS_API_KEY');
const _dartDefineConfigUrl = String.fromEnvironment('REMOTE_CONFIG_URL');

// ── Local .env.json (gitignored, never shipped in release) ───────────────

/// Loads `.env.json` from project root (bundled as asset in debug builds).
/// Returns an empty map if the file doesn't exist or fails to parse.
///
/// Always empty on the web, so a local `flutter build web` made with a real
/// `.env.json` still never uses keys. (That local build does still bundle the
/// file as an asset; CI writes `{}` to it and its grep guard checks the output.)
Future<Map<String, String>> _loadEnvJson() async {
  if (kIsWeb) return {};
  try {
    final json = await rootBundle.loadString('assets/.env.json');
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v.toString()));
  } catch (_) {
    return {};
  }
}

// ── Singletons ────────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) => Dio());

/// Null in the site export, which reads the prefetched snapshot instead.
final firestoreServiceProvider =
    Provider<FirestoreService?>((ref) => FirestoreService(dio: ref.read(dioProvider)));

final seasonCacheServiceProvider = Provider<SeasonCacheService>(
  (ref) => kIsWeb ? AssetSeasonCacheService(rootBundle) : IoSeasonCacheService(),
);

// ── Parsed config ─────────────────────────────────────────────────────────

class _ParsedConfig {
  final List<SeasonConfig> seasons;
  final List<Tournament> tournaments;

  /// The club seasons appended (validated), for the cache.
  final List<ClubSeason> clubSeasons;

  const _ParsedConfig(this.seasons, [this.tournaments = const [], this.clubSeasons = const []]);
}

/// The remote/cached config only carries tournaments when it explicitly has
/// a "tournaments" key; when it's missing entirely, fall back to the
/// tournaments bundled in [bundledJson] (parsed lazily so callers that don't
/// need it never pay for the asset read). Any parse failure of [bundledJson]
/// is swallowed, same as the other bundled-asset fallbacks in this file.
List<Tournament> tournamentsWithBundledFallback(
    Map<String, dynamic> remoteMap, String? bundledJson) {
  if (remoteMap.containsKey('tournaments')) return parseTournaments(remoteMap);
  if (bundledJson == null) return const [];
  try {
    return parseTournaments(jsonDecode(bundledJson) as Map<String, dynamic>);
  } catch (_) {
    return const [];
  }
}

_ParsedConfig _parseConfig(String json,
    {String? bundledJsonForTournamentsFallback, List<List<ClubSeason>> clubSeasons = const []}) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final jsonSeasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  final club = _validFor(jsonSeasons, clubSeasons);
  final seasons = appendClubSeasons(jsonSeasons, club);
  final tournaments = bundledJsonForTournamentsFallback == null
      ? parseTournaments(map)
      : tournamentsWithBundledFallback(map, bundledJsonForTournamentsFallback);
  return _ParsedConfig(
    seasons.map((e) => SeasonConfig.fromJson(e)).toList(),
    tournaments,
    club,
  );
}

/// The first candidate (live, then cached) that continues this JSON's ids; a
/// config with them already merged (the build's snapshot) keeps its own copy.
List<ClubSeason> _validFor(List<Map<String, dynamic>> jsonSeasons, List<List<ClubSeason>> candidates) {
  final last = lastSeasonId(jsonSeasons);
  for (final club in candidates) {
    if (club.isEmpty) return club;
    if (club.first.id <= last) return const []; // already in this config
    final errors = clubSeasonErrors(club, lastJsonId: last);
    if (errors.isEmpty) return club;
    debugPrint('config/seasons ignored: ${errors.join('; ')}');
  }
  return const [];
}

/// Firestore `config/seasons` candidates in order of preference: the live
/// list (when it parses), then the cached copy. Validated by [_validFor],
/// where the JSON's last id is known.
Future<List<List<ClubSeason>>> _clubSeasons(Ref ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  final out = <List<ClubSeason>>[];
  if (firestore != null) {
    try {
      final live = await firestore.fetchClubSeasons(kFirebaseProjectId);
      if (live != null) out.add(live);
    } catch (e) {
      debugPrint('Club seasons fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedClubSeasons();
    if (cached != null) out.add(parseClubSeasons(jsonDecode(cached)));
  } catch (e) {
    debugPrint('Cached club seasons unavailable: $e');
  }
  return out;
}

/// Best-effort read of the bundled season config, for the tournaments
/// fallback only. Never throws.
Future<String?> _tryLoadBundledConfigJson() async {
  try {
    return await rootBundle.loadString('assets/raw/season_config.json');
  } catch (_) {
    return null;
  }
}

/// Loads .env.json once and caches the result.
final envJsonProvider = FutureProvider<Map<String, String>>(
  (ref) => _loadEnvJson(),
);

/// Loads season configs. Priority:
/// 1. Remote URL (if REMOTE_CONFIG_URL is set) → cache it
/// 2. Cached remote config (mobile: last fetch; web: build-time snapshot)
/// 3. Bundled asset `assets/raw/season_config.json`
/// 4. Hardcoded `Season.allConfigs()` (ultimate fallback)
final parsedConfigProvider = FutureProvider<_ParsedConfig>((ref) async {
  final cacheService = ref.read(seasonCacheServiceProvider);
  final dio = ref.read(dioProvider);
  final env = await ref.watch(envJsonProvider.future);
  final club = await _clubSeasons(ref);

  final configUrl = _dartDefineConfigUrl.isNotEmpty
      ? _dartDefineConfigUrl
      : (env['REMOTE_CONFIG_URL'] ?? '');

  if (configUrl.isNotEmpty) {
    try {
      final response = await dio.get<String>(configUrl);
      final json = response.data!;
      await cacheService.cacheRemoteConfig(json);
      final parsed = _parseConfig(json, bundledJsonForTournamentsFallback: await _tryLoadBundledConfigJson(), clubSeasons: club);
      if (parsed.clubSeasons.isNotEmpty) {
        await cacheService.cacheClubSeasons(jsonEncode([for (final s in parsed.clubSeasons) s.toJson()]));
      }
      return parsed;
    } catch (e) {
      debugPrint('Remote config fetch failed: $e');
    }
  }

  // The last fetched remote config on mobile; the build-time snapshot on the
  // web (which has no config URL, so config and season snapshots always match).
  // Guarded as a whole: this now also runs when no URL is set, and a cache
  // that can't be read must fall through to the bundled config, not fail.
  try {
    final cached = await cacheService.getCachedRemoteConfig();
    if (cached != null) {
      final parsed = _parseConfig(cached, bundledJsonForTournamentsFallback: await _tryLoadBundledConfigJson(), clubSeasons: club);
      if (parsed.clubSeasons.isNotEmpty) {
        await cacheService.cacheClubSeasons(jsonEncode([for (final s in parsed.clubSeasons) s.toJson()]));
      }
      return parsed;
    }
  } catch (e) {
    debugPrint('Cached remote config unavailable: $e');
  }

  try {
    final json = await rootBundle.loadString('assets/raw/season_config.json');
    final parsed = _parseConfig(json, clubSeasons: club);
    if (parsed.clubSeasons.isNotEmpty) {
      await cacheService.cacheClubSeasons(jsonEncode([for (final s in parsed.clubSeasons) s.toJson()]));
    }
    return parsed;
  } catch (e) {
    debugPrint('Bundled season_config.json load failed: $e');
  }

  return _ParsedConfig(Season.allConfigs());
});

/// The resolved API key. Priority: --dart-define → .env.json → null.
final sheetsApiKeyProvider = Provider<String?>((ref) {
  if (_dartDefineApiKey.isNotEmpty) return _dartDefineApiKey;
  final env = ref.watch(envJsonProvider).valueOrNull ?? {};
  final envKey = env['SHEETS_API_KEY'] ?? '';
  return envKey.isNotEmpty ? envKey : null;
});

final seasonConfigsProvider = Provider<List<SeasonConfig>>((ref) {
  return ref.watch(parsedConfigProvider).valueOrNull?.seasons ?? [];
});

/// Every tournament held in any season, from the season config JSON.
/// The clock the in-progress checks read; overridden in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Firestore `config/club` (see [ClubConfig]): live, else the cached copy
/// (the build's snapshot on the web and in the site export), else null —
/// then the JSON config's tournaments still apply.
final clubConfigProvider = FutureProvider<ClubConfig?>((ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  if (firestore != null) {
    try {
      final json = await firestore.fetchClubConfig(kFirebaseProjectId);
      if (json != null) {
        // Parsed first: a document Dart can't read must not replace the cache.
        final club = ClubConfig.fromJson(jsonDecode(json) as Map<String, dynamic>);
        await cache.cacheClubConfig(json);
        return club;
      }
    } catch (e) {
      debugPrint('Club config fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedClubConfig();
    if (cached != null) {
      return ClubConfig.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }
  } catch (e) {
    debugPrint('Cached club config unavailable: $e');
  }
  return null;
});

/// The roster for the loader (app players.json shape): Firestore
/// `config/players` live, else the cached copy (the build's snapshot on the
/// web and in the site export), else the bundled `assets/raw/players.json`.
final playersJsonProvider = FutureProvider<String>((ref) async {
  final cache = ref.read(seasonCacheServiceProvider);
  final firestore = ref.read(firestoreServiceProvider);
  if (firestore != null) {
    try {
      // fetchPlayers validates, so a document Dart can't use never reaches the cache.
      final json = await firestore.fetchPlayers(kFirebaseProjectId);
      if (json != null) {
        await cache.cachePlayers(json);
        return json;
      }
    } catch (e) {
      debugPrint('Players fetch failed: $e');
    }
  }
  try {
    final cached = await cache.getCachedPlayers();
    if (cached != null) return cached;
  } catch (e) {
    debugPrint('Cached players unavailable: $e');
  }
  return rootBundle.loadString('assets/raw/players.json');
});

final tournamentsProvider = Provider<List<Tournament>>((ref) =>
    ref.watch(clubConfigProvider).valueOrNull?.tournaments ??
    ref.watch(parsedConfigProvider).valueOrNull?.tournaments ??
    const []);

// ── Loading phase ─────────────────────────────────────────────────────────

enum LoadingPhase { initial, latestLoaded, allLoaded }

final loadingPhaseProvider = StateProvider<LoadingPhase>(
  (ref) => LoadingPhase.initial,
);

// ── Shared state between initial and background load ─────────────────────

class _InitialLoadResult {
  final String playersJson;
  final SeasonDataService dataService;
  final List<SeasonConfig> allConfigs;
  final List<SeasonConfig> loadedConfigs;

  const _InitialLoadResult({
    required this.playersJson,
    required this.dataService,
    required this.allConfigs,
    required this.loadedConfigs,
  });
}

final _initialLoadResultProvider = StateProvider<_InitialLoadResult?>(
  (ref) => null,
);

// ── App data ──────────────────────────────────────────────────────────────

SeasonLoaderService _createLoader(Ref ref) => SeasonLoaderService(
      ref.read(playersRepositoryProvider.notifier),
      ref.read(gamesRepositoryProvider.notifier),
      ref.read(ratingRepositoryProvider.notifier),
      ref.read(seasonRepositoryProvider.notifier),
      ref.read(rolePercentilesRepositoryProvider.notifier),
    );

/// Loads the latest season only, making the HomeScreen usable quickly.
final initialLoadProvider = FutureProvider<void>((ref) async {
  // Phase 1: get configs + API key
  final parsed = await ref.watch(parsedConfigProvider.future);
  // Admins' final thresholds (config/club) apply before any season loads.
  final club = await ref.read(clubConfigProvider.future);
  final configs = applyAdminLimits(parsed.seasons, club?.gameLimits ?? const {});
  final now = ref.read(clockProvider)();
  final apiKey = ref.read(sheetsApiKeyProvider);

  // Phase 2: create sheets service
  final dio = ref.read(dioProvider);
  final cacheService = ref.read(seasonCacheServiceProvider);
  final sheetsService = apiKey != null && apiKey.isNotEmpty
      ? SheetsService(dio: dio, apiKey: apiKey)
      : null;
  final dataService = SeasonDataService(
    sheetsService: sheetsService,
    firestoreService: ref.read(firestoreServiceProvider),
    cacheService: cacheService,
  );

  // Phase 3: load players + latest season only
  final playersJson = await ref.read(playersJsonProvider.future);
  // The newest season with games: one just created on /seasons/edit/ has none yet.
  final latestLoad = await latestWithGames(configs, dataService.loadSeasonJson);
  if (latestLoad == null) {
    throw Exception('Failed to load latest season: ${configs.last.title}');
  }
  final (latestConfig, latestJson) = latestLoad;

  final loader = _createLoader(ref);
  await loader.loadSeasons(
    metas: [seasonMetaFor(latestConfig, now)],
    playersJson: playersJson,
    seasonJsons: [latestJson],
  );

  final latest = loader.applyThresholds([latestConfig]).single;
  ref.read(loadedSeasonConfigsProvider.notifier).state = [latest];
  ref.read(selectedSeasonProvider.notifier).state = latest;
  ref.read(loadingPhaseProvider.notifier).state = LoadingPhase.latestLoaded;

  // Store shared resources for background load
  ref.read(_initialLoadResultProvider.notifier).state = _InitialLoadResult(
    playersJson: playersJson,
    dataService: dataService,
    allConfigs: configs,
    loadedConfigs: [latest],
  );
});

/// Returns to the event loop so the browser can paint a frame between two
/// pieces of heavy work.
Future<void> _yieldToUi() => Future<void>.delayed(Duration.zero);

/// Loads remaining seasons in the background after the initial load completes.
/// On the web the seasons are loaded one by one (see
/// [SeasonLoaderService.loadSeasonsOneByOne]); the last season is followed by
/// a yield too, so the page also paints before the percentile pass.
final backgroundLoadProvider = FutureProvider<void>((ref) async {
  // Wait for initial load
  await ref.watch(initialLoadProvider.future);

  final shared = ref.read(_initialLoadResultProvider);
  if (shared == null) return;

  // Load remaining season JSONs (all except the latest)
  final remainingConfigs = shared.allConfigs
      .where((c) => c.id != shared.loadedConfigs.first.id)
      .toList();

  final remainingJsons = <String>[];
  final loadedRemainingConfigs = <SeasonConfig>[];

  // Load bundled seasons in parallel, remote sequentially
  final bundled = remainingConfigs.where((c) => c.source is BundledSource).toList();
  final remote = remainingConfigs.where((c) => c.source is! BundledSource).toList();

  final bundledResults = await Future.wait(
    bundled.map((c) => shared.dataService.loadSeasonJson(c)),
  );
  for (var i = 0; i < bundled.length; i++) {
    if (bundledResults[i] != null) {
      remainingJsons.add(bundledResults[i]!);
      loadedRemainingConfigs.add(bundled[i]);
    }
  }

  for (final config in remote) {
    final json = await shared.dataService.loadSeasonJson(config);
    if (json != null && !isEmptyFirestoreSnapshot(json)) {
      remainingJsons.add(json);
      loadedRemainingConfigs.add(config);
    }
  }

  if (remainingJsons.isNotEmpty) {
    final loader = _createLoader(ref);
    final now = ref.read(clockProvider)();
    if (kIsWeb) {
      // compute() runs on the UI thread on the web: load one season at a
      // time and let a frame through in between, so the page stays usable.
      await loader.loadSeasonsOneByOne(
        metas: loadedRemainingConfigs
            .map((c) => seasonMetaFor(c, now))
            .toList(),
        playersJson: shared.playersJson,
        seasonJsons: remainingJsons,
        yieldBetween: _yieldToUi,
      );
    } else {
      await loader.loadSeasons(
        metas: loadedRemainingConfigs
            .map((c) => seasonMetaFor(c, now))
            .toList(),
        playersJson: shared.playersJson,
        seasonJsons: remainingJsons,
      );
    }

    // Recompute percentiles with ALL seasons, from the games already parsed
    // into the repositories.
    await loader.recomputePercentiles(
      players: ref.read(playersRepositoryProvider),
      games: ref.read(gamesRepositoryProvider),
    );

    // Update loaded configs (sorted by id)
    final allLoaded = [
      ...shared.loadedConfigs,
      ...loader.applyThresholds(loadedRemainingConfigs),
    ]
      ..sort((a, b) => a.id.compareTo(b.id));
    ref.read(loadedSeasonConfigsProvider.notifier).state = allLoaded;
  }

  ref.read(loadingPhaseProvider.notifier).state = LoadingPhase.allLoaded;
});

/// Backward-compat wrapper: resolves when both phases are complete.
final appDataProvider = FutureProvider<void>((ref) async {
  await ref.watch(backgroundLoadProvider.future);
});

/// Holds the list of successfully loaded season configs.
final loadedSeasonConfigsProvider = StateProvider<List<SeasonConfig>>(
  (ref) => [],
);

/// Provider for the selected season (set by initial load, user can change).
final selectedSeasonProvider = StateProvider<SeasonConfig?>((ref) => null);

/// Selected bottom-nav tab, an index into [appTabsFor] (0 Season, 1 Players, 2 Dashboard, 3 Records; mobile adds 4 Chat, 5 Debug).
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Invalidates cache for a remote season and reloads all data.
Future<void> refreshSeason(WidgetRef ref, SeasonConfig config) async {
  if (config.source is! BundledSource) {
    final cacheService = ref.read(seasonCacheServiceProvider);
    await cacheService.invalidateSeasonCache(config.id);
  }
  // Clear repos before reload
  ref.read(gamesRepositoryProvider.notifier).clear();
  ref.read(playersRepositoryProvider.notifier).clear();
  ref.read(loadingPhaseProvider.notifier).state = LoadingPhase.initial;
  ref.read(_initialLoadResultProvider.notifier).state = null;
  ref.invalidate(initialLoadProvider);
  ref.invalidate(backgroundLoadProvider);
  await ref.read(backgroundLoadProvider.future);
}
