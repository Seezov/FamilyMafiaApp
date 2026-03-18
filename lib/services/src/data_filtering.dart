part of '../season_loader.dart';

// ── Raw data filtering ────────────────────────────────────────────────────

bool _filterRawData(GamesDataSeason d, int seasonId) {
  if (seasonId <= kLegacyMaxSeason) return int.tryParse(d.a) != null;
  return d.a.isNotEmpty && d.c.isNotEmpty;
}

/// Replace blank player names with unique placeholders so they don't
/// collide in uniqueness checks or set-based lookups.
List<String> _fillBlanks(List<String> names) {
  var blankIdx = 0;
  return names.map((n) => n.trim().isEmpty ? '_blank_${blankIdx++}' : n).toList();
}
