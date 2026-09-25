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

  const Tournament({
    required this.seasonId,
    required this.type,
    required this.name,
    required this.games,
    this.date,
    this.podium = const [],
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
        seasonId: json['season'] as int,
        type: TournamentType.fromJson(json['type'] as String),
        name: json['name'] as String,
        games: json['games'] as int,
        date: json['date'] as String?,
        podium: (json['podium'] as List?)?.cast<String>() ?? const [],
      );
}

List<Tournament> parseTournaments(Map<String, dynamic> configJson) {
  final list = configJson['tournaments'] as List?;
  if (list == null) return const [];
  return list.cast<Map<String, dynamic>>().map(Tournament.fromJson).toList();
}
