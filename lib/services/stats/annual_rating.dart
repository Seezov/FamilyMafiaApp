// Pure Dart: the annual rating as the sheet's «Річний рейтинг» tab computes it.
import 'package:family_mafia_app/models/annual_event.dart';

export 'package:family_mafia_app/models/annual_event.dart';

/// Points for one result, as the «Турніри» tab's «Бали» column.
double eventPoints(AnnualKind kind, int place, {int? stars, int? participants}) {
  switch (kind) {
    case AnnualKind.season:
      const fixed = {1: 18, 2: 15, 3: 12, 4: 9, 5: 6, 101: 5, 102: 4, 103: 3, 104: 2, 105: 1};
      return (fixed[place] ?? (place > 10 ? 2 : place > 5 ? 4 : 0)).toDouble();
    case AnnualKind.series:
      const fixed = {1: 10, 2: 8, 3: 6, 4: 4, 5: 3, 6: 2, 7: 2};
      return (fixed[place] ?? 1).toDouble();
    case AnnualKind.marathon:
      const fixed = {1: 6, 2: 4, 3: 3, 4: 2, 5: 2};
      return (fixed[place] ?? 1).toDouble();
    case AnnualKind.tournament:
      final b = 1 + (stars ?? 0) / 3;
      final n = participants ?? 0;
      if (place < 1) return 0;
      if (place < 11) return b + (n - place) * b / 4;
      if (place < n / 2) return b + (n - place) * b / 5;
      return b + (n - place) * b / 10;
  }
}

class AnnualEntry {
  AnnualEntry(this.event, this.place, this.points);

  final AnnualEvent event;
  final int place;
  final double points;

  /// One of the player's 12 best results, the ones the score sums.
  bool counted = false;
}

class AnnualStanding {
  AnnualStanding(this.key, this.name, this.entries)
      : score = _score(entries),
        wins = entries.where((e) => e.place == 1).length,
        top3 = entries.where((e) => e.place < 4).length,
        top10 = entries.where((e) => e.place < 11).length,
        participations = entries.where((e) => e.place > 0).length;

  final String key;
  final String name;

  /// Best points first.
  final List<AnnualEntry> entries;
  final double score;
  final int wins, top3, top10, participations;
  int rank = 0;

  static double _score(List<AnnualEntry> entries) {
    var sum = 0.0;
    for (final e in entries.take(kAnnualCountedEvents)) {
      e.counted = true;
      sum += e.points;
    }
    return (sum * 100).round() / 100;
  }
}

/// How many of a player's best results the annual score sums.
const kAnnualCountedEvents = 12;

/// Standings for [events] (one year), grouped by [keyOf] of each result's
/// name; [nameOf] gives the shown name (default: the first name seen).
List<AnnualStanding> annualStandings(Iterable<AnnualEvent> events,
    {required String Function(String player) keyOf, String Function(String player)? nameOf}) {
  final byKey = <String, (String, List<AnnualEntry>)>{};
  for (final e in events) {
    for (final r in e.results) {
      final key = keyOf(r.player);
      final slot = byKey[key] ??= (nameOf?.call(r.player) ?? r.player, []);
      slot.$2.add(AnnualEntry(e, r.place,
          eventPoints(e.kind, r.place, stars: e.stars, participants: e.participants)));
    }
  }
  final out = [
    for (final MapEntry(key: k, value: (name, entries)) in byKey.entries)
      AnnualStanding(k, name, entries..sort((a, b) => b.points.compareTo(a.points)))
  ]..sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
  for (var i = 0; i < out.length; i++) {
    out[i].rank = i > 0 && out[i].score == out[i - 1].score ? out[i - 1].rank : i + 1;
  }
  return out;
}

/// The year of a season's last month: the quarter of its median game
/// (as `seasonInProgress`); a December quarter ends in the next year.
int seasonYear(List<DateTime> gameDates) {
  final sorted = [...gameDates]..sort();
  final median = sorted[sorted.length ~/ 2];
  return median.month == 12 ? median.year + 1 : median.year;
}
