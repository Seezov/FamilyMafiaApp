import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:flutter_test/flutter_test.dart';

/// A game where [name] sits in slot 0 as a civilian; city wins when [won].
Game _g(int season, String name, bool won) => Game(
      seasonId: season,
      players: [name, ...List.generate(9, (i) => 'x$i')],
      roles: ['Мирный', 'Мафия', 'Мафия', 'Дон', 'Шериф', ...List.filled(5, 'Мирный')],
      cityWon: won,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
    );

final _r = PlayerResolver(const [
  Player(id: 1, displayName: 'Seezov', nicknames: ['Сізов']),
]);

String? _best(List<WinStreak> s, String name) =>
    s.where((w) => w.player.displayName == name).map((w) => '${w.length} ${w.seasonsLabel}').firstOrNull;

void main() {
  test('a loss breaks the streak', () {
    final s = bestWinStreaks([_g(19, 'A', true), _g(19, 'A', true), _g(19, 'A', false), _g(19, 'A', true)], _r);
    expect(_best(s, 'A'), '2 S19');
  });

  test('streaks continue across seasons', () {
    final s = bestWinStreaks([_g(18, 'A', true), _g(19, 'A', true), _g(19, 'A', true)], _r);
    expect(_best(s, 'A'), '3 S18–S19');
  });

  test('games are ordered by season even if loaded out of order', () {
    final s = bestWinStreaks([_g(19, 'A', true), _g(18, 'A', false), _g(20, 'A', true)], _r);
    expect(_best(s, 'A'), '2 S19–S20');
  });

  test('nicknames merge into one streak', () {
    final s = bestWinStreaks([_g(18, 'Seezov', true), _g(19, 'Сізов', true)], _r);
    expect(_best(s, 'Seezov'), '2 S18–S19');
  });

  test('blank slots are ignored', () {
    final s = bestWinStreaks([_g(18, '_blank_0', true)], _r);
    expect(s.where((w) => w.player.displayName.startsWith('_blank_')), isEmpty);
  });

  test('ties on streak length break by fewer all-time rating games, then name', () {
    // A: streak of 2, then 1 more rating game (loss) => 3 total games.
    // B: streak of 2 only => 2 total games. Both tie at length 2.
    final games = [
      _g(18, 'A', true), _g(18, 'A', true), _g(18, 'A', false),
      _g(18, 'B', true), _g(18, 'B', true),
    ];
    final s = bestWinStreaks(games, _r);
    final byName = {for (final w in s) w.player.displayName: w};
    expect(byName['A']!.length, 2);
    expect(byName['B']!.length, 2);
    final order = s.map((w) => w.player.displayName).toList();
    expect(order.indexOf('B'), lessThan(order.indexOf('A')));
  });
}
