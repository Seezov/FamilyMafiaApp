import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';

typedef NamedValue = ({String name, num value});

class SeasonRow {
  final int seasonId, games, players, mainLeague;
  final double cityWR, mafiaWR;
  final Map<TournamentType, int> tournaments;
  final NamedValue? mostGames, mvp, mostKilled, topKilledPct, mostHosted, hostAvgPlus;
  final NamedValue? bestDon, bestSheriff, bestCivilian, bestMafia;

  const SeasonRow({
    required this.seasonId, required this.games, required this.players, required this.mainLeague,
    required this.cityWR, required this.mafiaWR, required this.tournaments,
    this.mostGames, this.mvp, this.mostKilled, this.topKilledPct, this.mostHosted, this.hostAvgPlus,
    this.bestDon, this.bestSheriff, this.bestCivilian, this.bestMafia,
  });
}

double _roleWr(RatingPlayerStats p, Role role) {
  bool isRole(String v) => role.sheetValues.contains(v);
  final g = p.gamesForRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  final w = p.winByRole.where((e) => isRole(e.$1)).fold(0, (s, e) => s + e.$2);
  return g == 0 ? 0 : w / g;
}

List<SeasonRow> buildSeasonRows({
  required List<SeasonConfig> configs,
  required Map<int, SeasonStats> seasons,
  required List<Game> games,
  required List<Tournament> tournaments,
  required PlayerResolver resolver,
}) {
  final rows = <SeasonRow>[];
  for (final c in configs) {
    final stats = seasons[c.id];
    if (stats == null) continue;
    final seasonGames = games.where((g) => g.seasonId == c.id).toList();
    final byId = {for (final p in stats.playerStats) p.player.id: p};
    // id -1 means "unknown player" and is never a unique winner.
    RatingPlayerStats? winner(List<int> r) =>
        r.isEmpty || r.first == -1 ? null : byId[r.first];
    NamedValue? named(RatingPlayerStats? p, num Function(RatingPlayerStats) v) =>
        p == null ? null : (name: p.player.displayName, value: v(p));

    final main = stats.playerStats.where((p) => p.gamesPlayed >= c.gameLimit).toList();
    final extra = buildSeasonExtraStats(
      leaguePlayers: main,
      seasonGames: seasonGames,
      seasonTournaments: tournaments.where((t) => t.seasonId == c.id).toList(),
      resolver: resolver,
    );
    final city = seasonGames.where((g) => g.cityWon == true).length;
    final decided = seasonGames.where((g) => g.cityWon != null).length;

    rows.add(SeasonRow(
      seasonId: c.id,
      games: seasonGames.length,
      players: seasonGames.getPlayersList(c.id).length,
      mainLeague: leagueCounts(stats.playerStats, c).main,
      cityWR: decided == 0 ? 0 : city / decided,
      mafiaWR: decided == 0 ? 0 : (decided - city) / decided,
      tournaments: extra.tournaments,
      mostGames: extra.mostGames.isEmpty ? null : named(extra.mostGames.first, (p) => p.gamesPlayed),
      // Seasons 0-1 (kOldFormatMaxSeason) scored MVP on a different scale
      // (win points), so it isn't comparable and is shown/sorted as missing.
      mvp: c.id <= kOldFormatMaxSeason ? null : named(winner(stats.mvpRanking), (p) => p.mvp),
      mostKilled: named(winner(stats.mostKilledRanking), (p) => p.firstKilled),
      topKilledPct: extra.topFirstKilledPct.isEmpty ? null : named(extra.topFirstKilledPct.first, (p) => p.percentOfDeath),
      mostHosted: extra.mostHosted.isEmpty ? null : (name: extra.mostHosted.first.host.displayName, value: extra.mostHosted.first.hosted),
      hostAvgPlus: extra.hostAvgPlus.isEmpty ? null : (name: extra.hostAvgPlus.first.host.displayName, value: extra.hostAvgPlus.first.avgPlus),
      bestDon: named(winner(stats.bestDonRanking), (p) => _roleWr(p, Role.don)),
      bestSheriff: named(winner(stats.bestSheriffRanking), (p) => _roleWr(p, Role.sheriff)),
      bestCivilian: named(winner(stats.bestCivilianRanking), (p) => _roleWr(p, Role.civilian)),
      bestMafia: named(winner(stats.bestMafiaRanking), (p) => _roleWr(p, Role.mafia)),
    ));
  }
  return rows;
}
