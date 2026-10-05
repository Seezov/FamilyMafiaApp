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

SeasonStats _s(List<RatingPlayerStats> ranked, {List<int> mostKilled = const []}) => SeasonStats(
      playerStats: ranked,
      mvpRanking: const [],
      bestSheriffRanking: const [],
      bestDonRanking: const [],
      bestCivilianRanking: const [],
      bestMafiaRanking: const [],
      mostKilledRanking: mostKilled,
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
    expect(acc.where, {'main:1': ['S1'], 'small:1': ['S2']});
  });

  test('counts seasons as most killed, outside the nomination total', () {
    final acc = computeAccomplishments(
      me,
      {
        1: _s([r(me, 45)], mostKilled: [me.id, a.id]),
        2: _s([r(me, 45)], mostKilled: [a.id, me.id]), // runner-up: no award
        3: _s([r(me, 45)], mostKilled: [me.id]),
      },
      [_c(1), _c(2), _c(3)],
      const [],
      resolver,
    );
    expect(acc.mostKilled, 2);
    expect(acc.where['killed'], ['S1', 'S3']);
    expect(acc.sumOfNominations(), 3); // the three 1st places only
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
    expect(acc.where, {
      'minicap:0': ['x · S1'],
      'minicap:2': ['x · S1'],
      'bigcap:1': ['x · S1'],
    });
  });

  test('podium is parsed from config and optional', () {
    expect(Tournament.fromJson({'season': 1, 'type': 'bigcap', 'name': 'Big Ben', 'games': 8,
        'podium': ['A', 'B', 'C']}).podium, ['A', 'B', 'C']);
    expect(Tournament.fromJson({'season': 1, 'type': 'minicap', 'name': 'm', 'games': 4}).podium, isEmpty);
  });

  test('a season still in progress gives no places or awards', () {
    final acc = computeAccomplishments(
      me,
      {
        1: _s([r(me, 45)], mostKilled: [me.id]),
        2: _s([r(me, 45), r(a, 20)], mostKilled: [me.id]), // still being played
      },
      [_c(1), _c(2)],
      const [],
      resolver,
      inProgress: const {2},
    );
    expect(acc.firsts, 1);
    expect(acc.mostKilled, 1);
    expect(acc.where, {'main:0': ['S1'], 'killed': ['S1']});
  });

  group('seasonInProgress', () {
    DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);
    final s31 = [d(2026, 9, 1), d(2026, 9, 20), d(2026, 10, 3)];

    test('Sep–Nov season runs until 1 December', () {
      expect(seasonInProgress(s31, now: d(2026, 10, 5)), isTrue);
      expect(seasonInProgress(s31, now: d(2026, 11, 30)), isTrue);
      expect(seasonInProgress(s31, now: d(2026, 12, 1)), isFalse);
    });

    test('Dec–Feb season crosses the year', () {
      final winter = [d(2025, 12, 2), d(2026, 1, 15), d(2026, 2, 20)];
      expect(seasonInProgress(winter, now: d(2026, 2, 28)), isTrue);
      expect(seasonInProgress(winter, now: d(2026, 3, 1)), isFalse);
      // A season whose median game is in December.
      expect(seasonInProgress([d(2025, 12, 2), d(2025, 12, 9), d(2026, 1, 5)], now: d(2026, 2, 1)), isTrue);
    });

    test('a typo date does not end the season early', () {
      expect(seasonInProgress([d(1900, 1, 1), ...s31, d(2026, 10, 4)], now: d(2026, 10, 5)), isTrue);
    });

    test('a season without dates counts as finished', () {
      expect(seasonInProgress(const [], now: d(2026, 10, 5)), isFalse);
    });
  });
}
