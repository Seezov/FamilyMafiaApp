import 'package:flutter/material.dart';

enum TournamentType {
  minicap('Minicap', Color(0xFF1F7A6D), Color(0xFFE3F2EF)),
  maxicap('Maxicap', Color(0xFFB36B00), Color(0xFFFBEEDB)),
  bigcap('Bigcap', Color(0xFF8E3B46), Color(0xFFF6E4E6)),
  marathon('Marathon', Color(0xFF4C55A8), Color(0xFFE7E8F6)),
  tournament('Tournament', Color(0xFF6F6A70), Color(0xFFEEECEE));

  const TournamentType(this.label, this.color, this.lightColor);

  final String label;
  final Color color;
  final Color lightColor;

  static TournamentType fromJson(String v) =>
      values.firstWhere((t) => t.name == v, orElse: () => tournament);
}

/// One tournament (minicap, maxicap, marathon or other) held during a season.
class Tournament {
  final int seasonId;
  final TournamentType type;
  final String name;
  final int games;

  /// Free-form day or range as written in the sheet, e.g. `16–17.12.2023`.
  final String? date;

  /// Prize places as written in the sheet: index 0 is 1st place. Filled in by
  /// hand in the config; empty when nobody has entered the results yet.
  final List<String> podium;

  /// Where the entry came from: null for a sheet's tournament tab,
  /// `detected` when found in the game lists without a tab, `confirmed` once
  /// a person checked a detected one on the site's Debug page.
  final String? status;

  const Tournament({
    required this.seasonId,
    required this.type,
    required this.name,
    required this.games,
    this.date,
    this.podium = const [],
    this.status,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        seasonId: json['season'] as int,
        type: TournamentType.fromJson(json['type'] as String),
        name: json['name'] as String,
        games: json['games'] as int,
        date: json['date'] as String?,
        podium: (json['podium'] as List?)?.cast<String>() ?? const [],
        status: json['status'] as String?,
      );

  /// The days [date] covers, or null when it has no full day-month-year.
  /// Accepts `16.12.2023`, `16–17.12.2023`, `31.03–02.04.2024` and
  /// `30.12.2023–01.01.2024`.
  ({DateTime start, DateTime end})? get dateRange {
    final m = RegExp(r'^(\d{1,2})(?:\.(\d{1,2}))?(?:\.(\d{4}))?'
            r'(?:\s*[–—-]\s*(\d{1,2})(?:\.(\d{1,2}))?(?:\.(\d{4}))?)?$')
        .firstMatch(date?.trim() ?? '');
    if (m == null) return null;
    int? g(int i) => m.group(i) == null ? null : int.parse(m.group(i)!);
    final (d1, m1, y1, d2, m2, y2) = (g(1)!, g(2), g(3), g(4), g(5), g(6));
    if (d2 == null) {
      if (m1 == null || y1 == null) return null;
      final day = DateTime.utc(y1, m1, d1);
      return (start: day, end: day);
    }
    final endMonth = m2 ?? m1;
    final endYear = y2 ?? y1;
    if (endMonth == null || endYear == null) return null;
    return (
      start: DateTime.utc(y1 ?? endYear, m1 ?? endMonth, d1),
      end: DateTime.utc(endYear, endMonth, d2),
    );
  }
}

List<Tournament> parseTournaments(Map<String, dynamic> configJson) {
  final list = configJson['tournaments'] as List?;
  if (list == null) return const [];
  return list.cast<Map<String, dynamic>>().map(Tournament.fromJson).toList();
}
