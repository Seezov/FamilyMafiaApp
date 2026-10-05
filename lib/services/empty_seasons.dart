import 'dart:convert';

import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/firestore_rest.dart';

/// A season created on /seasons/edit/ before its first game: the app and the
/// site leave it out until a game is recorded.
bool isEmptyFirestoreSnapshot(String json) {
  try {
    final d = jsonDecode(json);
    return d is Map && d['format'] == firestoreSnapshotFormat && (d['games'] as List?)?.isEmpty == true;
  } catch (_) {
    return false;
  }
}

/// The newest season whose JSON loads and is not an empty Firestore season,
/// with that JSON; null when none loads.
Future<(SeasonConfig, String)?> latestWithGames(
    List<SeasonConfig> configs, Future<String?> Function(SeasonConfig) load) async {
  for (final c in configs.reversed) {
    final json = await load(c);
    if (json == null) return null; // as before: the newest season must load
    if (!isEmptyFirestoreSnapshot(json)) return (c, json);
  }
  return null;
}
