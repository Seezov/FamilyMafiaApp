import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';
import 'package:flutter_test/flutter_test.dart';

RatingPlayerStats _p(int id, int games, {int killed = 0, int civ = 0, int sher = 0}) =>
    RatingPlayerStats(
      seasonId: 26,
      player: Player(id: id, displayName: 'P$id'),
      gamesPlayed: games,
      firstKilled: killed,
      percentOfDeath: (civ + sher) == 0 ? 0 : killed / (civ + sher),
      gamesForRole: [('Мирний', civ), ('Шериф', sher)],
    );

const _season = SeasonConfig(
  id: 26, title: 'Season 26', gameLimit: 40, smallLeagueMinGames: 15,
  gamesMultiplier: 0, source: BundledSource(jsonFile: 'x.json'),
);

void main() {
  final resolver = PlayerResolver(const []);

  test('most games ranks by games, top 4', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: [for (var i = 1; i <= 6; i++) _p(i, i * 10)],
      seasonGames: const [], seasonTournaments: const [], resolver: resolver,
    );
    expect(s.mostGames.map((p) => p.player.id), [6, 5, 4, 3]);
  });

  test('top ПУ % skips players without red games', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: [_p(1, 40, killed: 5, civ: 20), _p(2, 40, killed: 0)],
      seasonGames: const [], seasonTournaments: const [], resolver: resolver,
    );
    expect(s.topFirstKilledPct.map((p) => p.player.id), [1]);
  });

  test('tournaments are counted by type', () {
    final s = buildSeasonExtraStats(
      leaguePlayers: const [], seasonGames: const [], resolver: resolver,
      seasonTournaments: const [
        Tournament(seasonId: 26, type: TournamentType.minicap, name: 'a', games: 4),
        Tournament(seasonId: 26, type: TournamentType.minicap, name: 'b', games: 5),
        Tournament(seasonId: 26, type: TournamentType.maxicap, name: 'c', games: 8),
      ],
    );
    expect(s.tournaments, {TournamentType.minicap: 2, TournamentType.maxicap: 1});
  });

  test('league counts use gameLimit and smallLeagueMinGames', () {
    final counts = leagueCounts([_p(1, 14), _p(2, 15), _p(3, 39), _p(4, 40)], _season);
    expect(counts, (main: 1, small: 2));
  });
}
