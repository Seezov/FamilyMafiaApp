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
final _envJsonProvider = FutureProvider<Map<String, String>>(
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
  final env = await ref.watch(_envJsonProvider.future);

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
  final env = ref.watch(_envJsonProvider).valueOrNull ?? {};
  final envKey = env['SHEETS_API_KEY'] ?? '';
  return envKey.isNotEmpty ? envKey : null;
});

final seasonConfigsProvider = Provider<List<SeasonConfig>>((ref) {
  return ref.watch(parsedConfigProvider).valueOrNull?.seasons ?? [];
});

// ── App data ──────────────────────────────────────────────────────────────

/// Loads all season data. Watch this provider to know when the app data is ready.
final appDataProvider = FutureProvider<void>((ref) async {
  // Phase 1: get configs + API key
  final parsed = await ref.watch(parsedConfigProvider.future);
  final configs = parsed.seasons;
  final apiKey = ref.read(sheetsApiKeyProvider);

  // Phase 2: create sheets service (needs API key from config)
  final dio = ref.read(dioProvider);
  final cacheService = ref.read(seasonCacheServiceProvider);
  final sheetsService = apiKey != null && apiKey.isNotEmpty
      ? SheetsService(dio: dio, apiKey: apiKey)
      : null;
  final dataService = SeasonDataService(
    sheetsService: sheetsService,
    cacheService: cacheService,
  );

  // Phase 3: load all season JSONs (bundled or remote)
  final playersJson = await rootBundle.loadString('assets/raw/players.json');

  final seasonJsons = <String>[];
  final loadedConfigs = <SeasonConfig>[];
  for (final config in configs) {
    final json = await dataService.loadSeasonJson(config);
    if (json != null) {
      seasonJsons.add(json);
      loadedConfigs.add(config);
    }
  }

  // Phase 4: compute ratings in background isolate + populate repos
  final loader = SeasonLoaderService(
    ref.read(playersRepositoryProvider.notifier),
    ref.read(gamesRepositoryProvider.notifier),
    ref.read(ratingRepositoryProvider.notifier),
    ref.read(seasonRepositoryProvider.notifier),
    ref.read(rolePercentilesRepositoryProvider.notifier),
  );

  await loader.loadAll(
    metas: loadedConfigs
        .map((c) => SeasonMeta(c.id, c.gameLimit, c.gamesMultiplier))
        .toList(),
    playersJson: playersJson,
    seasonJsons: seasonJsons,
  );

  ref.read(loadedSeasonConfigsProvider.notifier).state = loadedConfigs;
});

/// Holds the list of successfully loaded season configs after appDataProvider resolves.
final loadedSeasonConfigsProvider = StateProvider<List<SeasonConfig>>(
  (ref) => [],
);
