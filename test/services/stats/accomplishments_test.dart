import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/accomplishments.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _c(int id) => SeasonConfig(id: id, title: 'S$id', gameLimit: 40, smallLeagueMinGames: 15,
    gamesMultiplier: 0, source: const BundledSource(jsonFile: 'x'));

SeasonStats _s(List<RatingPlayerStats> ranked) => SeasonStats(
      playerStats: ranked,
      mvpRanking: const [],
      bestSheriffRanking: const [],
      bestDonRanking: const [],
      bestCivilianRanking: const [],
      bestMafiaRanking: const [],
      mostKilledRanking: const [],
    );

void main() {
  const me = Player(id: 3, displayName: 'Braun', nicknames: ['Braun', 'Браун']);
  const a = Player(id: 1, displayName: 'A');
  const b = Player(id: 2, displayName: 'B');
  RatingPlayerStats r(Player p, int g) => RatingPlayerStats(seasonId: 1, player: p, gamesPlayed: g);
  final resolver = PlayerResolver([me, a, b]);

  test('counts main and small league places separately', () {
    final acc = computeAccomplishments(
      me,
      {
        // Main: A, me → 2nd. Small ranking starts after them.
        1: _s([r(a, 50), r(me, 45), r(b, 20)]),
        // Me is small league: B (main) doesn't count, A is 1st small → me 2nd small.
        2: _s([r(b, 60), r(a, 30), r(me, 20)]),
        // Below small league: nothing.
        3: _s([r(me, 10)]),
      },
      [_c(1), _c(2), _c(3)],
      const [],
      resolver,
    );
    expect((acc.firsts, acc.seconds, acc.thirds), (0, 1, 0));
    expect((acc.smallFirsts, acc.smallSeconds, acc.smallThirds), (0, 1, 0));
  });

  test('tournament podiums resolve nicknames and group by type', () {
    Tournament t(TournamentType type, List<String> podium) =>
        Tournament(seasonId: 1, type: type, name: 'x', games: 4, podium: podium);
    final acc = computeAccomplishments(
      me,
      const {},
      const [],
      [
        t(TournamentType.minicap, ['Браун', 'A', 'B']),
        t(TournamentType.minicap, ['A', 'B', 'Braun']),
        t(TournamentType.bigcap, ['A', 'Braun']),
        t(TournamentType.maxicap, ['A', 'B', 'C', 'Braun']), // 4th: no prize
        t(TournamentType.marathon, const []),
      ],
      resolver,
    );
    expect(acc.tournamentPlaces, {
      TournamentType.minicap: [1, 0, 1],
      TournamentType.bigcap: [0, 1, 0],
    });
    expect(acc.sumOfNominations(), 3);
  });

  test('podium is parsed from config and optional', () {
    expect(Tournament.fromJson({'season': 1, 'type': 'bigcap', 'name': 'Big Ben', 'games': 8,
        'podium': ['A', 'B', 'C']}).podium, ['A', 'B', 'C']);
    expect(Tournament.fromJson({'season': 1, 'type': 'minicap', 'name': 'm', 'games': 4}).podium, isEmpty);
  });
}
