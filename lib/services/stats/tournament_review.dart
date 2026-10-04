import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// One player's line in a tournament table.
class TournamentStanding {
  const TournamentStanding({
    required this.player,
    required this.points,
    required this.wins,
    required this.games,
  });

  final Player player;
  final double points;
  final int wins;
  final int games;
}

/// The table the club's minicap tabs compute for [games]: wins + extra points
/// (penalties are stored negative) + auto extra + best move + the first-killed bonus, which
/// is the share of games lost after being killed first, capped at 0.4.
/// Best first; ties keep the order players first appear in.
List<TournamentStanding> tournamentStandings(
  Iterable<Game> games,
  PlayerResolver resolver,
) {
  final acc = <String, ({Player p, double pts, int w, int g, int lostFirst})>{};
  for (final game in games) {
    for (final raw in game.players) {
      final p = resolver.resolve(raw);
      final key = personKey(p);
      final won = game.hasPlayerWon(raw);
      final first = game.isFirstKilled(raw);
      final points =
          (won ? 1 : 0) +
          game.getPlayerAdditionalPoints(raw) +
          game.getPlayerPenaltyPoints(raw) +
          game.getPlayerAutoAdditionalPoints(raw) +
          (first ? game.bestMovePoints : 0);
      final a = acc[key] ?? (p: p, pts: 0.0, w: 0, g: 0, lostFirst: 0);
      acc[key] = (
        p: a.p,
        pts: a.pts + points,
        w: a.w + (won ? 1 : 0),
        g: a.g + 1,
        lostFirst: a.lostFirst + (first && !won ? 1 : 0),
      );
    }
  }
  final list = [
    for (final a in acc.values)
      TournamentStanding(
        player: a.p,
        points: a.pts + _firstKilledBonus(a.lostFirst / a.g),
        wins: a.w,
        games: a.g,
      ),
  ];
  // List.sort is not stable; sort by index on ties to keep appearance order.
  final order = {for (final (i, s) in list.indexed) s: i};
  list.sort((a, b) {
    final c = b.points.compareTo(a.points);
    return c != 0 ? c : order[a]!.compareTo(order[b]!);
  });
  return list;
}

double _firstKilledBonus(double share) => share > 0.399 ? 0.4 : share;

/// Consecutive games of one season played by (nearly) the same ten people
/// under one host: what a minicap or marathon looks like in the game list.
class DetectedEvening {
  const DetectedEvening(this.seasonId, this.games);

  final int seasonId;
  final List<Game> games;

  List<DateTime> get dates => {
    for (final g in games)
      if (g.date != null) g.date!,
  }.toList()..sort();

  Map<String, int> get hosts {
    final m = <String, int>{};
    for (final g in games) {
      m[g.host ?? '—'] = (m[g.host ?? '—'] ?? 0) + 1;
    }
    return m;
  }

  /// Stable across rebuilds while the sheet rows stay the same.
  String get id {
    final d = dates.isEmpty ? 'nodate' : _iso(dates.first);
    final host =
        (hosts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    return 'S$seasonId-$d-$host-${games.length}';
  }
}

String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

/// Runs of at least [minGames] games where every game shares 8+ players with
/// the first one, with at most two distinct tables and one host for all but
/// one game. [games] must be in sheet order.
List<DetectedEvening> detectEvenings(List<Game> games, {int minGames = 4}) {
  final out = <DetectedEvening>[];
  var i = 0;
  while (i < games.length) {
    final first = games[i];
    final base = first.players.toSet();
    var j = i + 1;
    while (j < games.length &&
        games[j].seasonId == first.seasonId &&
        games[j].players.toSet().intersection(base).length >= 8) {
      j++;
    }
    final run = games.sublist(i, j);
    if (first.seasonId >= 2 && run.length >= minGames) {
      final tables = {
        for (final g in run) (g.players.toList()..sort()).join('|'),
      };
      final evening = DetectedEvening(first.seasonId, run);
      final topHost = evening.hosts.values.reduce((a, b) => a > b ? a : b);
      if (tables.length <= 2 && topHost >= run.length - 1) out.add(evening);
    }
    i = j;
  }
  return out;
}

/// True when [evening] was played on a day [t] covers, give or take a day.
bool eveningMatches(DetectedEvening evening, Tournament t) {
  final r = t.dateRange;
  if (r == null) return false;
  final from = r.start.subtract(const Duration(days: 1));
  final to = r.end.add(const Duration(days: 1));
  return evening.dates.any((d) => !d.isBefore(from) && !d.isAfter(to));
}

/// The games behind [t]: of the closed tables detected on its dates and all
/// its season's games on those dates, the set whose size is closest to its
/// game count (the bigger one on a tie).
List<Game> tournamentGames(Tournament t, List<Game> games) {
  final r = t.dateRange;
  if (r == null) return const [];
  final onDates = [for (final g in games) if (_within(g, r)) g];
  final options = [
    for (final e in detectEvenings(onDates, minGames: 3)) e.games,
    [for (final g in onDates) if (g.seasonId == t.seasonId) g],
  ].where((o) => o.isNotEmpty).toList();
  if (options.isEmpty) return const [];
  int miss(List<Game> o) => (o.length - t.games).abs();
  options.sort((a, b) {
    final c = miss(a).compareTo(miss(b));
    return c != 0 ? c : b.length.compareTo(a.length);
  });
  return options.first;
}

bool _within(Game g, ({DateTime start, DateTime end}) r) =>
    g.date != null && !g.date!.isBefore(r.start) && !g.date!.isAfter(r.end);
