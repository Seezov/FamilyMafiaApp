// Snapshots the remote config and every remote (Google Sheets) season into
// assets/prefetched/ so the web build can show them without an API key.
//
// Usage (CI):  SHEETS_API_KEY=... REMOTE_CONFIG_URL=... dart run tool/prefetch_seasons.dart

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/prefetch_paths.dart';
import 'package:family_mafia_app/services/sheets_service.dart';

Future<void> main() async {
  final apiKey = Platform.environment['SHEETS_API_KEY'] ?? '';
  final configUrl = Platform.environment['REMOTE_CONFIG_URL'] ?? '';
  if (apiKey.isEmpty || configUrl.isEmpty) {
    stderr.writeln('SHEETS_API_KEY and REMOTE_CONFIG_URL must be set');
    exit(2);
  }
  try {
    final ids = await prefetchSeasons(
      dio: Dio(),
      apiKey: apiKey,
      configUrl: configUrl,
      outDir: Directory(prefetchedDir),
    );
    stdout.writeln('Prefetched ${ids.length} remote season(s): ${ids.join(', ')}');
  } on DioException catch (e) {
    // Never print e itself: its message carries the request URL with the key.
    stderr.writeln('Prefetch failed: HTTP ${e.response?.statusCode} (${e.type.name})');
    exit(1);
  } on SheetsException catch (e) {
    // Built from sheet names only, never the key.
    stderr.writeln('Prefetch failed: $e');
    exit(1);
  } on FormatException catch (e) {
    // Bad JSON in the config or a sheet response; the key is only in URLs.
    stderr.writeln('Prefetch failed: $e');
    exit(1);
  } catch (e) {
    stderr.writeln('Prefetch failed: ${e.runtimeType}');
    exit(1);
  }
}

/// Downloads the remote config and every remote season, then writes them to
/// [outDir]. Everything is fetched before anything is written, so a failure
/// throws and leaves [outDir] untouched: CI never deploys a partial snapshot.
/// Returns the ids of the remote seasons written.
Future<List<int>> prefetchSeasons({
  required Dio dio,
  required String apiKey,
  required String configUrl,
  required Directory outDir,
}) async {
  final configResponse = await dio.get<String>(
    configUrl,
    options: Options(responseType: ResponseType.plain),
  );
  final configJson = configResponse.data!;
  final seasons = ((jsonDecode(configJson) as Map<String, dynamic>)['seasons'] as List)
      .cast<Map<String, dynamic>>()
      .map(SeasonConfig.fromJson);

  final sheets = SheetsService(dio: dio, apiKey: apiKey);
  final fetched = <int, String>{};
  for (final season in seasons) {
    if (season.source case final RemoteSource remote) {
      fetched[season.id] = await sheets.fetchSeasonData(remote);
    }
  }

  await outDir.create(recursive: true);
  await File('${outDir.path}/$prefetchedConfigFile').writeAsString(configJson);
  for (final MapEntry(key: id, value: json) in fetched.entries) {
    await File('${outDir.path}/${prefetchedSeasonFile(id)}').writeAsString(json);
  }
  return fetched.keys.toList();
}
