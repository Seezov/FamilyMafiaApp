import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class SeasonCacheService {
  String? _cacheDir;

  Future<String> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = '${appDir.path}/cache/seasons';
    await Directory(_cacheDir!).create(recursive: true);
    return _cacheDir!;
  }

  // ── Season data cache ───────────────────────────────────────────────────

  Future<String?> getCachedSeasonData(int seasonId) async {
    final dir = await _getCacheDir();
    final file = File('$dir/season$seasonId.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  Future<int?> getCachedRowCount(int seasonId) async {
    final dir = await _getCacheDir();
    final file = File('$dir/season$seasonId.meta.json');
    if (!await file.exists()) return null;
    final meta = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return meta['rowCount'] as int?;
  }

  Future<void> cacheSeasonData(int seasonId, String jsonData, int rowCount) async {
    final dir = await _getCacheDir();
    await File('$dir/season$seasonId.json').writeAsString(jsonData);
    await File('$dir/season$seasonId.meta.json').writeAsString(
      jsonEncode({'rowCount': rowCount, 'fetchedAt': DateTime.now().toIso8601String()}),
    );
  }

  Future<void> invalidateSeasonCache(int seasonId) async {
    final dir = await _getCacheDir();
    final data = File('$dir/season$seasonId.json');
    final meta = File('$dir/season$seasonId.meta.json');
    if (await data.exists()) await data.delete();
    if (await meta.exists()) await meta.delete();
  }

  // ── Remote config cache ─────────────────────────────────────────────────

  Future<String?> getCachedRemoteConfig() async {
    final dir = await _getCacheDir();
    final file = File('$dir/remote_config.json');
    if (await file.exists()) return file.readAsString();
    return null;
  }

  Future<void> cacheRemoteConfig(String jsonData) async {
    final dir = await _getCacheDir();
    await File('$dir/remote_config.json').writeAsString(jsonData);
  }
}
