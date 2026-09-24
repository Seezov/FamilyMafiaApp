import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// Same cap the season awards use: winner plus three runners-up.
const kSeasonStatsRankingSize = 4;

int redGames(RatingPlayerStats p) => p.gamesForRole
    .where((e) =>
        Role.civilian.sheetValues.contains(e.$1) ||
        Role.sheriff.sheetValues.contains(e.$1))
    .fold(0, (s, e) => s + e.$2);

class SeasonExtraStats {
  final List<RatingPlayerStats> mostGames;
  final List<RatingPlayerStats> topFirstKilledPct;
  final List<HostStat> mostHosted;
  final List<HostStat> hostAvgPlus;
  final List<HostStat> hostAvgMinus;

  /// Null when the season has no host data at all (seasons 0-1).
  final int? gamesWithoutHost;
  final int seasonGames;
  final Map<TournamentType, int> tournaments;

  const SeasonExtraStats({
    required this.mostGames,
    required this.topFirstKilledPct,
    required this.mostHosted,
    required this.hostAvgPlus,
    required this.hostAvgMinus,
    required this.gamesWithoutHost,
    required this.seasonGames,
    required this.tournaments,
  });
}

List<T> _top<T>(List<T> list, int Function(T, T) compare) =>
    ([...list]..sort(compare)).take(kSeasonStatsRankingSize).toList();

SeasonExtraStats buildSeasonExtraStats({
  required List<RatingPlayerStats> leaguePlayers,
  required List<Game> seasonGames,
  required List<Tournament> seasonTournaments,
  required PlayerResolver resolver,
}) {
  int byName(RatingPlayerStats a, RatingPlayerStats b) =>
      a.player.displayName.compareTo(b.player.displayName);

  final hosts = hostStats(seasonGames, resolver);
  final tournaments = <TournamentType, int>{};
  for (final t in seasonTournaments) {
    tournaments[t.type] = (tournaments[t.type] ?? 0) + 1;
  }

  return SeasonExtraStats(
    mostGames: _top(leaguePlayers, (a, b) {
      final c = b.gamesPlayed.compareTo(a.gamesPlayed);
      return c != 0 ? c : byName(a, b);
    }),
    topFirstKilledPct: _top(
      leaguePlayers.where((p) => redGames(p) > 0).toList(),
      (a, b) {
        final c = b.percentOfDeath.compareTo(a.percentOfDeath);
        if (c != 0) return c;
        // Product-owner decision: a tied % favors fewer red games (the more
        // impressive number), before falling back to name.
        final r = redGames(a).compareTo(redGames(b));
        return r != 0 ? r : byName(a, b);
      },
    ),
    mostHosted: hosts.take(kSeasonStatsRankingSize).toList(),
    hostAvgPlus: rankHostsByAvgPlus(hosts).take(kSeasonStatsRankingSize).toList(),
    hostAvgMinus: rankHostsByAvgMinus(hosts).take(kSeasonStatsRankingSize).toList(),
    gamesWithoutHost: gamesWithoutHost(seasonGames),
    seasonGames: seasonGames.length,
    tournaments: tournaments,
  );
}

({int main, int small}) leagueCounts(
    List<RatingPlayerStats> all, SeasonConfig season) {
  final main = all.where((p) => p.gamesPlayed >= season.gameLimit).length;
  final small = all
      .where((p) =>
          p.gamesPlayed >= season.smallLeagueMinGames &&
          p.gamesPlayed < season.gameLimit)
      .length;
  return (main: main, small: small);
}
