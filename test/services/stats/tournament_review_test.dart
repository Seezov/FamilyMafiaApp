import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/tournament_review.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../site_export/fixture.dart';

Tournament _t(String? date, {int games = 4}) => Tournament(
    seasonId: 1, type: TournamentType.minicap, name: 'x', games: games, date: date);

List<String> _ten([String first = 'P']) => [for (var i = 1; i <= 10; i++) '$first$i'];

Game _game({
  required List<String> players,
  bool cityWon = true,
  int firstKilled = 1,
  double bestMove = 0,
  String? host = 'H',
  DateTime? date,
  int season = 5,
}) =>
    Game(
      seasonId: season,
      players: players,
      // Slots 1-7 civilians, 8-10 mafia.
      roles: [for (var i = 0; i < 10; i++) i < 7 ? 'Мирний' : 'Мафія'],
      cityWon: cityWon,
      firstKilled: firstKilled,
      bestMovePoints: bestMove,
      bestMove: const [],
      host: host,
      date: date,
    );

void main() {
  group('dateRange', () {
    DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);
    test('single days and every range shape', () {
      expect(_t('16.12.2023').dateRange, (start: d(2023, 12, 16), end: d(2023, 12, 16)));
      expect(_t('16–17.12.2023').dateRange, (start: d(2023, 12, 16), end: d(2023, 12, 17)));
      expect(_t('31.03–02.04.2024').dateRange, (start: d(2024, 3, 31), end: d(2024, 4, 2)));
      expect(_t('30.12.2023–01.01.2024').dateRange,
          (start: d(2023, 12, 30), end: d(2024, 1, 1)));
    });
    test('no year, free text or nothing gives null', () {
      expect(_t('10.10').dateRange, isNull);
      expect(_t('гру 2023').dateRange, isNull);
      expect(_t(null).dateRange, isNull);
    });
  });

  test('standings: wins, best move and the first-killed bonus', () {
    final resolver = PlayerResolver(const []);
    final p = _ten();
    final games = [
      // P1 killed first, city wins: 1 + 0.3 best move, no bonus (won).
      _game(players: p, firstKilled: 1, bestMove: 0.3),
      // P1 killed first, city loses: 0 + 0.5 best move; lost-first 1 of 2.
      _game(players: p, cityWon: false, firstKilled: 1, bestMove: 0.5),
    ];
    final s = tournamentStandings(games, resolver);
    final p1 = s.firstWhere((e) => e.player.displayName == 'P1');
    // 1.3 + 0.5 + min(1/2 → 0.4).
    expect(p1.points, closeTo(2.2, 1e-9));
    expect((p1.wins, p1.games), (1, 2));
    // Mafia (P8) won once: 1 point, ranked after P1.
    expect(s.indexWhere((e) => e.player.displayName == 'P8'),
        greaterThan(s.indexOf(p1)));
  });

  test('detection keeps closed tables under one host, drops mixed nights', () {
    final a = _ten();
    final b = [...a.take(8), 'X1', 'X2'];
    final other = _ten('Q');
    final day = DateTime.utc(2023, 11, 14);
    final games = [
      for (var i = 0; i < 4; i++) _game(players: i.isEven ? a : b, date: day),
      _game(players: other, date: day),
      // Same people but four hosts: a regular evening.
      for (final h in ['A', 'B', 'C', 'D']) _game(players: a, host: h, date: day),
    ];
    final found = detectEvenings(games);
    expect(found, hasLength(1));
    expect(found.single.games, hasLength(4));
    expect(found.single.id, 'S5-2023-11-14-H-4');
    expect(eveningMatches(found.single, _t('15.11.2023')), isTrue);
    expect(eveningMatches(found.single, _t('17.11.2023')), isFalse);
  });

  test('S21 minicaps: the computed top 3 is the config podium', () async {
    final c = await fixtureContainer();
    final games = c.read(gamesRepositoryProvider);
    final resolver = c.read(playerResolverProvider);
    final all = parseTournaments(
        jsonDecode(File('assets/raw/season_config.json').readAsStringSync())
            as Map<String, dynamic>);
    // 25.04.2024 is left out: the game list has 4 of its 5 games.
    for (final name in ['Мінікап 26.03.2024', 'Мінікап 03.04.2024']) {
      final t = all.firstWhere((t) => t.name == name);
      final gs = tournamentGames(t, games);
      expect(gs, hasLength(t.games), reason: name);
      String display(String raw) => resolver.resolve(raw).displayName;
      expect(
          tournamentStandings(gs, resolver).take(3).map((s) => s.player.displayName),
          t.podium.map(display),
          reason: name);
    }
  });

}
