// Pure Dart on purpose: tool/prefetch_seasons.dart uses it outside Flutter.

/// Throws [FormatException] unless [json] (Firestore `config/club`, decoded)
/// has the shape `ClubConfig.fromJson` reads, so a bad document fails the
/// build instead of silently dropping the tournaments.
void checkClubConfigJson(Map<String, dynamic> json) {
  Never bad(String what) => throw FormatException('config/club: $what');
  final tournaments = json['tournaments'] ?? const [];
  if (tournaments is! List) bad('tournaments is not a list');
  for (final (i, t) in tournaments.indexed) {
    if (t is! Map ||
        t['season'] is! int ||
        t['type'] is! String ||
        t['name'] is! String ||
        t['games'] is! int ||
        (t['date'] != null && t['date'] is! String) ||
        (t['status'] != null && t['status'] is! String) ||
        (t['podium'] != null &&
            (t['podium'] is! List || (t['podium'] as List).any((p) => p is! String)))) {
      bad('tournament #$i is malformed');
    }
  }
  final rejected = json['rejectedCandidates'] ?? const [];
  if (rejected is! List || rejected.any((r) => r is! String)) {
    bad('rejectedCandidates is not a list of strings');
  }
  final limits = json['gameLimits'] ?? const {};
  if (limits is! Map ||
      limits.entries.any((e) => int.tryParse('${e.key}') == null || e.value is! int)) {
    bad('gameLimits is not a map of season id to int');
  }
}
