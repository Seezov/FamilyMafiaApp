// lib/services/stats/records.dart
import 'dart:math';

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';

class RecordsInput {
  final Map<int, List<RatingPlayerStats>> ratings;
  final List<SeasonConfig> configs;
  final List<Game> games;
  final PlayerResolver resolver;

  const RecordsInput({required this.ratings, required this.configs, required this.games, required this.resolver});
}

class MvpRecord {
  final Player player; final int seasonId;
  final double addPerGame, maxSingleAdd, totalAdd, winRate;
  final int games;
  const MvpRecord(this.player, this.seasonId, this.addPerGame, this.maxSingleAdd, this.totalAdd, this.winRate, this.games);
}

class RoleRecord {
  final Player player; final int seasonId; final Role role;
  final double pointsPerGame; final int games; final double winRate;
  const RoleRecord(this.player, this.seasonId, this.role, this.pointsPerGame, this.games, this.winRate);
}

class GamesRecord {
  final Player player; final int? seasonId; final int games; final double winRate;
  const GamesRecord(this.player, this.seasonId, this.games, this.winRate);
}

class FirstKillRecord {
  final Player player; final int seasonId; final int count, redGames;
  final double pct;
  const FirstKillRecord(this.player, this.seasonId, this.count, this.redGames, this.pct);
}

class PenaltyRecord {
  final Player player; final int seasonId;
  final double minusPerGame, maxSingleMinus, totalMinus, winRate;
  final int games;
  const PenaltyRecord(this.player, this.seasonId, this.minusPerGame, this.maxSingleMinus, this.totalMinus, this.winRate, this.games);
}

class HostRecord {
  final Player host; final int? seasonId; final int hosted; final double avgPlus, avgMinus;
  /// Hosted games within the selected points period (0 when [period] wasn't
  /// requested or the host has none in it). Drives the Avg +/Avg − "—"
  /// eligibility threshold, independent of [hosted] which always counts
  /// every game the host ran.
  final int periodGames;
  const HostRecord(this.host, this.seasonId, this.hosted, this.avgPlus, this.avgMinus, this.periodGames);
}

/// Main-league rows (player reached the season's gameLimit) in [period].
Iterable<RatingPlayerStats> _mainLeague(RecordsInput i, {PointsPeriod? period}) sync* {
  final limits = {for (final c in i.configs) c.id: c.gameLimit};
  for (final MapEntry(key: season, value: list) in i.ratings.entries) {
    if (period != null && !period.contains(season)) continue;
    final limit = limits[season];
    if (limit == null) continue;
    yield* list.where((p) => p.gamesPlayed >= limit);
  }
}

/// Per (season, player key): max single plus, max single minus, total minus,
/// total plus, and the running max of the club MVP "game points" (доп +
/// протокол-доп + штраф + протокол-штраф, plus the кращий хід in the game
/// the player was first-killed). The last is `null` until the player's
/// first game, so a genuinely negative best game is never clamped to 0.
Map<(int, String), (double, double, double, double, double?)> _perGamePoints(RecordsInput i) {
  final out = <(int, String), (double, double, double, double, double?)>{};
  for (final g in i.games) {
    for (var s = 0; s < g.players.length; s++) {
      final key = (g.seasonId, personKey(i.resolver.resolve(g.players[s])));
      final (maxPlus, maxMinus, totalMinus, totalPlus, mvpMax) =
          out[key] ?? (0.0, 0.0, 0.0, 0.0, null);
      final minus = g.slotMinus(s);
      final plus = g.slotPlus(s);
      final mvpGamePoints = (g.additionalPoints?[s] ?? 0.0) +
          (g.protocolAdditionalPoints?[s] ?? 0.0) +
          (g.penaltyPoints?[s] ?? 0.0) +
          (g.protocolPenaltyPoints?[s] ?? 0.0) +
          (g.firstKilled == s + 1 ? g.bestMovePoints : 0.0) -
          g.slotRemoval(s);
      out[key] = (
        max(maxPlus, plus),
        min(maxMinus, minus),
        totalMinus + minus,
        totalPlus + plus,
        mvpMax == null ? mvpGamePoints : max(mvpMax, mvpGamePoints),
      );
    }
  }
  return out;
}

int _byName(Player a, Player b) => a.displayName.compareTo(b.displayName);

/// Sorts by [v] (direction per [desc]), then by fewer [games] first, then by
/// name, then by [season] (when given). Product-owner decision: a value tie
/// favors the player/host who reached it in fewer games, since that's the
/// more impressive number, before falling back to name.
List<T> _sorted<T>(List<T> l, double Function(T) v, Player Function(T) p,
        {bool desc = true, int? Function(T)? season, required int Function(T) games}) =>
    l..sort((a, b) {
      final c = desc ? v(b).compareTo(v(a)) : v(a).compareTo(v(b));
      if (c != 0) return c;
      final g = games(a).compareTo(games(b));
      if (g != 0) return g;
      final n = _byName(p(a), p(b));
      if (n != 0) return n;
      if (season == null) return 0;
      final sa = season(a), sb = season(b);
      if (sa == null || sb == null) return 0;
      return sa.compareTo(sb);
    });

/// Follows the club MVP formula (доп + протокол + кращий хід + мінуси, without
/// removal deductions — see `slotRemoval`), the
/// same as `calculateMvp` in rating_formulas.dart for seasons 2+:
/// `(additionalPoints + bestMovePoints + penaltyPoints) / gamesPlayed`.
/// `RatingPlayerStats.additionalPoints`/`penaltyPoints` already fold in the
/// protocol additional/penalty points (see `_computePlayerRating`), so they
/// aren't added again here. `maxSingleAdd` is the same components' best
/// single game, computed directly from the games.
List<MvpRecord> mvpRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final removals = <(int, String), double>{};
  for (final g in i.games) {
    for (var s = 0; s < g.players.length; s++) {
      final key = (g.seasonId, personKey(i.resolver.resolve(g.players[s])));
      removals[key] = (removals[key] ?? 0.0) + g.slotRemoval(s);
    }
  }
  final rows = [
    for (final p in _mainLeague(i, period: period))
      () {
        final totalAdd = p.additionalPoints + p.bestMovePoints + p.penaltyPoints -
            (removals[(p.seasonId, personKey(p.player))] ?? 0.0);
        final maxSingleAdd = pts[(p.seasonId, personKey(p.player))]?.$5 ?? 0.0;
        return MvpRecord(p.player, p.seasonId, totalAdd / p.gamesPlayed, maxSingleAdd, totalAdd, p.winRate, p.gamesPlayed);
      }(),
  ];
  return _sorted(rows, (r) => r.addPerGame, (r) => r.player, season: (r) => r.seasonId, games: (r) => r.games);
}

(int, int, double) _role(RatingPlayerStats p, Role role) {
  bool isRole(String v) => role.sheetValues.contains(v);
  final games = p.gamesForRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final wins = p.winByRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final points = p.bestMoveAndAdditionalPointsByRole.where((e) => isRole(e.$1)).fold(0.0, (s, e) => s + e.$2);
  return (games, wins, points);
}

List<RoleRecord> roleRecords(RecordsInput i, Role role, PointsPeriod period) {
  final limits = {for (final c in i.configs) c.id: c.gameLimit};
  final rows = <RoleRecord>[];
  for (final p in _mainLeague(i, period: period)) {
    final (games, wins, points) = _role(p, role);
    if (games == 0 || games < (limits[p.seasonId] ?? 0) * role.chanceToDraw) continue;
    rows.add(RoleRecord(p.player, p.seasonId, role, points / games, games, wins / games));
  }
  return _sorted(rows, (r) => r.pointsPerGame, (r) => r.player, season: (r) => r.seasonId, games: (r) => r.games);
}

List<GamesRecord> gamesRecords(RecordsInput i, {required bool allTime}) {
  if (!allTime) {
    return _sorted([
      for (final p in _mainLeague(i)) GamesRecord(p.player, p.seasonId, p.gamesPlayed, p.winRate),
    ], (r) => r.games.toDouble(), (r) => r.player, season: (r) => r.seasonId, games: (r) => r.games);
  }
  final acc = <String, (Player, int, int)>{};
  for (final list in i.ratings.values) {
    for (final p in list) {
      final key = personKey(p.player);
      final (pl, g, w) = acc[key] ?? (p.player, 0, 0);
      acc[key] = (pl, g + p.gamesPlayed, w + p.wins);
    }
  }
  return _sorted([
    for (final (p, g, w) in acc.values) GamesRecord(p, null, g, g == 0 ? 0 : w / g),
  ], (r) => r.games.toDouble(), (r) => r.player, games: (r) => r.games);
}

List<FirstKillRecord> firstKillRecords(RecordsInput i) => _sorted([
      for (final p in _mainLeague(i))
        if (redGames(p) > 0)
          FirstKillRecord(p.player, p.seasonId, p.firstKilled, redGames(p), p.percentOfDeath),
    ], (r) => r.count.toDouble(), (r) => r.player, season: (r) => r.seasonId, games: (r) => r.redGames);

List<PenaltyRecord> penaltyRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final rows = [
    for (final p in _mainLeague(i, period: period))
      () {
        final (_, maxMinus, total, _, _) =
            pts[(p.seasonId, personKey(p.player))] ?? (0.0, 0.0, 0.0, 0.0, null);
        return PenaltyRecord(p.player, p.seasonId, total / p.gamesPlayed, maxMinus, total, p.winRate, p.gamesPlayed);
      }(),
  ];
  return _sorted(rows, (r) => r.minusPerGame, (r) => r.player, desc: false, season: (r) => r.seasonId, games: (r) => r.games);
}

/// [hosted] always counts every game the host ran in scope (the season for
/// per-season rows, all seasons for all-time); [period] only narrows the
/// games behind avgPlus/avgMinus (and [HostRecord.periodGames]), so the
/// points period never hides a host's hosted count.
List<HostRecord> hostRecords(RecordsInput i, {required bool allTime, PointsPeriod? period}) {
  Iterable<Game> inPeriod(Iterable<Game> g) =>
      period == null ? g : g.where((x) => period.contains(x.seasonId));

  List<HostRecord> forGames(Iterable<Game> games, int? seasonId) {
    final periodStats = {
      for (final h in hostStats(inPeriod(games), i.resolver)) personKey(h.host): h,
    };
    return [
      for (final h in hostStats(games, i.resolver))
        () {
          final p = periodStats[personKey(h.host)];
          return HostRecord(h.host, seasonId, h.hosted, p?.avgPlus ?? 0, p?.avgMinus ?? 0, p?.hosted ?? 0);
        }(),
    ];
  }

  final rows = <HostRecord>[];
  if (allTime) {
    rows.addAll(forGames(i.games, null));
  } else {
    final seasons = i.games.map((g) => g.seasonId).toSet();
    for (final s in seasons) {
      rows.addAll(forGames(i.games.where((g) => g.seasonId == s), s));
    }
  }
  return _sorted(rows, (r) => r.hosted.toDouble(), (r) => r.host, season: (r) => r.seasonId, games: (r) => r.hosted);
}
