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
  const MvpRecord(this.player, this.seasonId, this.addPerGame, this.maxSingleAdd, this.totalAdd, this.winRate);
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
  const PenaltyRecord(this.player, this.seasonId, this.minusPerGame, this.maxSingleMinus, this.totalMinus, this.winRate);
}

class HostRecord {
  final Player host; final int? seasonId; final int hosted; final double avgPlus, avgMinus;
  const HostRecord(this.host, this.seasonId, this.hosted, this.avgPlus, this.avgMinus);
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
/// total plus.
Map<(int, String), (double, double, double, double)> _perGamePoints(RecordsInput i) {
  final out = <(int, String), (double, double, double, double)>{};
  for (final g in i.games) {
    for (var s = 0; s < g.players.length; s++) {
      final key = (g.seasonId, personKey(i.resolver.resolve(g.players[s])));
      final (maxPlus, maxMinus, totalMinus, totalPlus) = out[key] ?? (0.0, 0.0, 0.0, 0.0);
      final minus = g.slotMinus(s);
      final plus = g.slotPlus(s);
      out[key] = (max(maxPlus, plus), min(maxMinus, minus), totalMinus + minus, totalPlus + plus);
    }
  }
  return out;
}

int _byName(Player a, Player b) => a.displayName.compareTo(b.displayName);

List<T> _sorted<T>(List<T> l, double Function(T) v, Player Function(T) p,
        {bool desc = true, int? Function(T)? season}) =>
    l..sort((a, b) {
      final c = desc ? v(b).compareTo(v(a)) : v(a).compareTo(v(b));
      if (c != 0) return c;
      final n = _byName(p(a), p(b));
      if (n != 0) return n;
      if (season == null) return 0;
      final sa = season(a), sb = season(b);
      if (sa == null || sb == null) return 0;
      return sa.compareTo(sb);
    });

/// Uses positive доп summed from games (no protocol points, no minuses) —
/// this differs from the Season Awards MVP score input, which uses the
/// rating's net `additionalPoints`.
List<MvpRecord> mvpRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final rows = [
    for (final p in _mainLeague(i, period: period))
      () {
        final (maxPlus, _, _, totalPlus) =
            pts[(p.seasonId, personKey(p.player))] ?? (0.0, 0.0, 0.0, 0.0);
        return MvpRecord(p.player, p.seasonId, totalPlus / p.gamesPlayed, maxPlus, totalPlus, p.winRate);
      }(),
  ];
  return _sorted(rows, (r) => r.addPerGame, (r) => r.player, season: (r) => r.seasonId);
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
  return _sorted(rows, (r) => r.pointsPerGame, (r) => r.player, season: (r) => r.seasonId);
}

List<GamesRecord> gamesRecords(RecordsInput i, {required bool allTime}) {
  if (!allTime) {
    return _sorted([
      for (final p in _mainLeague(i)) GamesRecord(p.player, p.seasonId, p.gamesPlayed, p.winRate),
    ], (r) => r.games.toDouble(), (r) => r.player, season: (r) => r.seasonId);
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
  ], (r) => r.games.toDouble(), (r) => r.player);
}

List<FirstKillRecord> firstKillRecords(RecordsInput i) => _sorted([
      for (final p in _mainLeague(i))
        if (redGames(p) > 0)
          FirstKillRecord(p.player, p.seasonId, p.firstKilled, redGames(p), p.percentOfDeath),
    ], (r) => r.count.toDouble(), (r) => r.player, season: (r) => r.seasonId);

List<PenaltyRecord> penaltyRecords(RecordsInput i, PointsPeriod period) {
  final pts = _perGamePoints(i);
  final rows = [
    for (final p in _mainLeague(i, period: period))
      () {
        final (_, maxMinus, total, _) =
            pts[(p.seasonId, personKey(p.player))] ?? (0.0, 0.0, 0.0, 0.0);
        return PenaltyRecord(p.player, p.seasonId, total / p.gamesPlayed, maxMinus, total, p.winRate);
      }(),
  ];
  return _sorted(rows, (r) => r.minusPerGame, (r) => r.player, desc: false, season: (r) => r.seasonId);
}

List<HostRecord> hostRecords(RecordsInput i, {required bool allTime, PointsPeriod? period}) {
  Iterable<Game> inPeriod(Iterable<Game> g) =>
      period == null ? g : g.where((x) => period.contains(x.seasonId));
  final rows = <HostRecord>[];
  if (allTime) {
    for (final h in hostStats(inPeriod(i.games), i.resolver)) {
      rows.add(HostRecord(h.host, null, h.hosted, h.avgPlus, h.avgMinus));
    }
  } else {
    final seasons = i.games.map((g) => g.seasonId).toSet();
    for (final s in seasons) {
      if (period != null && !period.contains(s)) continue;
      for (final h in hostStats(i.games.where((g) => g.seasonId == s), i.resolver)) {
        rows.add(HostRecord(h.host, s, h.hosted, h.avgPlus, h.avgMinus));
      }
    }
  }
  return _sorted(rows, (r) => r.hosted.toDouble(), (r) => r.host, season: (r) => r.seasonId);
}
