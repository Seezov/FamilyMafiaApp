import 'package:family_mafia_app/models/tournament.dart';

/// Firestore `config/club`: the club's tournament list, candidates the Debug
/// page rejected, and admins' final thresholds by season id.
class ClubConfig {
  final List<Tournament> tournaments;
  final List<String> rejectedCandidates;
  final Map<int, int> gameLimits;

  const ClubConfig({
    this.tournaments = const [],
    this.rejectedCandidates = const [],
    this.gameLimits = const {},
  });

  /// From the document's decoded fields or the prefetched snapshot (same shape).
  factory ClubConfig.fromJson(Map<String, dynamic> json) => ClubConfig(
        tournaments: parseTournaments(json),
        rejectedCandidates:
            (json['rejectedCandidates'] as List?)?.cast<String>() ?? const [],
        gameLimits: {
          for (final e in ((json['gameLimits'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as int,
        },
      );
}
