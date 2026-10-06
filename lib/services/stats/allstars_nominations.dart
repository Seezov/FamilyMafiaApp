import 'package:family_mafia_app/models/allstars.dart';

/// The federation's four nominations (emotion.games results page).
enum NominationKind { mvp, firstKilled, bestRed, bestMafia }

class NominationRow {
  const NominationRow(this.player, this.value);
  final String player;
  final double value;
}

/// Nominations of one all-star event computed from its games, the way the
/// federation counts them: MVP = Σ(additional + best move) — penalties are
/// negative additional points, first-kill compensation (Ci) is not counted;
/// best red / best mafia = the same sum in civilian+sheriff / mafia+don games;
/// first killed = times killed first (players never killed first are left out).
///
/// Each list is the top 3 plus every player tied with the 3rd; ties keep
/// [tableOrder] (the final table, matched ignoring case).
Map<NominationKind, List<NominationRow>> computeNominations(
    List<AllstarsGame> games, List<String> tableOrder) {
  final names = <String, String>{}; // lower-case key → name as first seen
  final sums = {for (final k in NominationKind.values) k: <String, double>{}};
  void add(NominationKind k, String key, double v) =>
      sums[k]![key] = (sums[k]![key] ?? 0) + v;

  for (final g in games) {
    for (var i = 0; i < g.seats.length; i++) {
      final s = g.seats[i];
      final key = s.player.toLowerCase();
      names.putIfAbsent(key, () => s.player);
      final points = s.add + s.bestMove;
      add(NominationKind.mvp, key, points);
      add(s.role.isRed ? NominationKind.bestRed : NominationKind.bestMafia, key, points);
      if (g.firstKilled == i + 1) add(NominationKind.firstKilled, key, 1);
    }
  }

  final rank = {
    for (var i = 0; i < tableOrder.length; i++) tableOrder[i].toLowerCase(): i
  };
  int place(String key) => rank[key] ?? tableOrder.length;

  return {
    for (final k in NominationKind.values) k: _top(sums[k]!, names, place),
  };
}

List<NominationRow> _top(Map<String, double> sums, Map<String, String> names,
    int Function(String) place) {
  final keys = sums.keys.toList()
    ..sort((a, b) {
      final c = _round(sums[b]!).compareTo(_round(sums[a]!));
      return c != 0 ? c : place(a).compareTo(place(b));
    });
  final out = <NominationRow>[];
  for (final key in keys) {
    final v = sums[key]!;
    if (out.length >= 3 && _round(v) != _round(out.last.value)) break;
    out.add(NominationRow(names[key]!, v));
  }
  return out;
}

/// Sums of 0.1-steps carry float noise; compare at 2 decimals, as shown.
int _round(double v) => (v * 100).round();
