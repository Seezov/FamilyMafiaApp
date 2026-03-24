import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
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
Future<Map<String, String>> _loadEnvJson() async {
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

final seasonCacheServiceProvider = Provider<SeasonCacheService>(
  (ref) => SeasonCacheService(),
);

// ── Parsed config ─────────────────────────────────────────────────────────

class _ParsedConfig {
  final List<SeasonConfig> seasons;

  const _ParsedConfig(this.seasons);
}

_ParsedConfig _parseConfig(String json) {
  final map = jsonDecode(json) as Map<String, dynamic>;
  final seasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  return _ParsedConfig(
    seasons.map((e) => SeasonConfig.fromJson(e)).toList(),
  );
}

/// Loads .env.json once and caches the result.
final envJsonProvider = FutureProvider<Map<String, String>>(
  (ref) => _loadEnvJson(),
);

/// Loads season configs. Priority:
/// 1. Remote URL (if REMOTE_CONFIG_URL is set) → cache it
/// 2. Cached remote config (if remote fetch fails)
/// 3. Bundled asset `assets/raw/season_config.json`
/// 4. Hardcoded `Season.allConfigs()` (ultimate fallback)
final parsedConfigProvider = FutureProvider<_ParsedConfig>((ref) async {
  final cacheService = ref.read(seasonCacheServiceProvider);
  final dio = ref.read(dioProvider);
  final env = await ref.watch(envJsonProvider.future);

  final configUrl = _dartDefineConfigUrl.isNotEmpty
      ? _dartDefineConfigUrl
      : (env['REMOTE_CONFIG_URL'] ?? '');

  if (configUrl.isNotEmpty) {
    try {
      final response = await dio.get<String>(configUrl);
      final json = response.data!;
      await cacheService.cacheRemoteConfig(json);
      return _parseConfig(json);
    } catch (e) {
      debugPrint('Remote config fetch failed: $e');
    }

    final cached = await cacheService.getCachedRemoteConfig();
    if (cached != null) {
      try {
        return _parseConfig(cached);
      } catch (e) {
        debugPrint('Cached remote config parse failed: $e');
      }
    }
  }

  try {
    final json = await rootBundle.loadString('assets/raw/season_config.json');
    return _parseConfig(json);
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
  final List<String> loadedSeasonJsons;
  final List<SeasonMeta> loadedMetas;

  const _InitialLoadResult({
    required this.playersJson,
    required this.dataService,
    required this.allConfigs,
    required this.loadedConfigs,
    required this.loadedSeasonJsons,
    required this.loadedMetas,
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
  final configs = parsed.seasons;
  final apiKey = ref.read(sheetsApiKeyProvider);

  // Phase 2: create sheets service
  final dio = ref.read(dioProvider);
  final cacheService = ref.read(seasonCacheServiceProvider);
  final sheetsService = apiKey != null && apiKey.isNotEmpty
      ? SheetsService(dio: dio, apiKey: apiKey)
      : null;
  final dataService = SeasonDataService(
    sheetsService: sheetsService,
    cacheService: cacheService,
  );

  // Phase 3: load players + latest season only
  final playersJson = await rootBundle.loadString('assets/raw/players.json');
  final latestConfig = configs.last;
  final latestJson = await dataService.loadSeasonJson(latestConfig);

  if (latestJson == null) {
    throw Exception('Failed to load latest season: ${latestConfig.title}');
  }

  final loader = _createLoader(ref);
  await loader.loadSeasons(
    metas: [SeasonMeta(latestConfig.id, latestConfig.gameLimit, latestConfig.gamesMultiplier)],
    playersJson: playersJson,
    seasonJsons: [latestJson],
  );

  ref.read(loadedSeasonConfigsProvider.notifier).state = [latestConfig];
  ref.read(selectedSeasonProvider.notifier).state = latestConfig;
  ref.read(loadingPhaseProvider.notifier).state = LoadingPhase.latestLoaded;

  // Store shared resources for background load
  ref.read(_initialLoadResultProvider.notifier).state = _InitialLoadResult(
    playersJson: playersJson,
    dataService: dataService,
    allConfigs: configs,
    loadedConfigs: [latestConfig],
    loadedSeasonJsons: [latestJson],
    loadedMetas: [SeasonMeta(latestConfig.id, latestConfig.gameLimit, latestConfig.gamesMultiplier)],
  );
});

/// Loads remaining seasons in the background after the initial load completes.
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
  final remote = remainingConfigs.where((c) => c.source is RemoteSource).toList();

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
    if (json != null) {
      remainingJsons.add(json);
      loadedRemainingConfigs.add(config);
    }
  }

  if (remainingJsons.isNotEmpty) {
    final loader = _createLoader(ref);
    await loader.loadSeasons(
      metas: loadedRemainingConfigs
          .map((c) => SeasonMeta(c.id, c.gameLimit, c.gamesMultiplier))
          .toList(),
      playersJson: shared.playersJson,
      seasonJsons: remainingJsons,
    );

    // Recompute percentiles with ALL seasons
    final allJsons = [...shared.loadedSeasonJsons, ...remainingJsons];
    final allMetas = [
      ...shared.loadedMetas,
      ...loadedRemainingConfigs
          .map((c) => SeasonMeta(c.id, c.gameLimit, c.gamesMultiplier)),
    ];
    await loader.recomputePercentiles(
      playersJson: shared.playersJson,
      allSeasonJsons: allJsons,
      allMetas: allMetas,
    );

    // Update loaded configs (sorted by id)
    final allLoaded = [...shared.loadedConfigs, ...loadedRemainingConfigs]
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

/// Invalidates cache for a remote season and reloads all data.
Future<void> refreshSeason(WidgetRef ref, SeasonConfig config) async {
  if (config.source is RemoteSource) {
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
