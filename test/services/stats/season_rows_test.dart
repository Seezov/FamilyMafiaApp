import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g(bool city) => Game(
      seasonId: 26, players: ['A', 'B', ...List.generate(8, (i) => 'x$i')],
      roles: List.filled(10, 'Мирный'), cityWon: city, firstKilled: 0,
      bestMovePoints: 0, bestMove: const [], host: 'H',
    );

void main() {
  test('builds one row per loaded season, skipping seasons without stats', () {
    final a = RatingPlayerStats(seasonId: 26, player: const Player(id: 1, displayName: 'A'), gamesPlayed: 3, mvp: 0.4);
    final rows = buildSeasonRows(
      configs: const [
        SeasonConfig(id: 26, title: 'S26', gameLimit: 2, smallLeagueMinGames: 1, gamesMultiplier: 0, source: BundledSource(jsonFile: 'x')),
        SeasonConfig(id: 27, title: 'S27', gameLimit: 2, smallLeagueMinGames: 1, gamesMultiplier: 0, source: BundledSource(jsonFile: 'y')),
      ],
      seasons: {
        26: SeasonStats(playerStats: [a], mvpRanking: const [1], bestSheriffRanking: const [], bestDonRanking: const [],
            bestCivilianRanking: const [], bestMafiaRanking: const [], mostKilledRanking: const []),
      },
      games: [_g(true), _g(true), _g(false)],
      tournaments: const [Tournament(seasonId: 26, type: TournamentType.minicap, name: 'm', games: 4)],
      resolver: PlayerResolver(const []),
    );
    expect(rows.single.seasonId, 26);
    expect(rows.single.games, 3);
    expect(rows.single.cityWR, closeTo(2 / 3, 1e-9));
    expect(rows.single.mvp?.name, 'A');
    expect(rows.single.mostHosted?.name, 'H');
    expect(rows.single.tournaments[TournamentType.minicap], 1);
  });
}
