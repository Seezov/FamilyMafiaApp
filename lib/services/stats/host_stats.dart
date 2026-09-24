import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// Hosts need this many games before their averages are ranked.
const kHostMinGamesForAverage = 20;

class HostStat {
  final Player host;
  final int hosted;

  /// Sum of plus / minus (≤ 0) handed out across [hosted] games.
  final double plus;
  final double minus;

  const HostStat({
    required this.host,
    required this.hosted,
    required this.plus,
    required this.minus,
  });

  double get avgPlus => hosted == 0 ? 0 : plus / hosted;
  double get avgMinus => hosted == 0 ? 0 : minus / hosted;
}

List<HostStat> hostStats(Iterable<Game> games, PlayerResolver resolver) {
  final acc = <String, (Player, int, double, double)>{};
  for (final g in games) {
    final raw = g.host;
    if (raw == null) continue;
    final host = resolver.resolve(raw);
    final key = personKey(host);
    final (p, n, plus, minus) = acc[key] ?? (host, 0, 0.0, 0.0);
    acc[key] = (p, n + 1, plus + g.hostPlus, minus + g.hostMinus);
  }
  final list = [
    for (final (p, n, plus, minus) in acc.values)
      HostStat(host: p, hosted: n, plus: plus, minus: minus),
  ];
  list.sort((a, b) {
    final c = b.hosted.compareTo(a.hosted);
    return c != 0 ? c : a.host.displayName.compareTo(b.host.displayName);
  });
  return list;
}

int? gamesWithoutHost(Iterable<Game> games) {
  if (!games.any((g) => g.host != null)) return null;
  return games.where((g) => g.host == null).length;
}

List<HostStat> _rankAvg(List<HostStat> stats, double Function(HostStat) v,
    {required bool descending}) {
  final eligible =
      stats.where((h) => h.hosted >= kHostMinGamesForAverage).toList();
  eligible.sort((a, b) {
    final c = descending ? v(b).compareTo(v(a)) : v(a).compareTo(v(b));
    if (c != 0) return c;
    // Product-owner decision: a tied average favors the host who reached it
    // in fewer hosted games, before falling back to name.
    final h = a.hosted.compareTo(b.hosted);
    return h != 0 ? h : a.host.displayName.compareTo(b.host.displayName);
  });
  return eligible;
}

List<HostStat> rankHostsByAvgPlus(List<HostStat> stats) =>
    _rankAvg(stats, (h) => h.avgPlus, descending: true);

List<HostStat> rankHostsByAvgMinus(List<HostStat> stats) =>
    _rankAvg(stats, (h) => h.avgMinus, descending: false);
