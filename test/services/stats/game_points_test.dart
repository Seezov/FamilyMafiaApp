// test/services/stats/game_points_test.dart
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/services/stats/game_points.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:flutter_test/flutter_test.dart';

Game _g({List<double>? add, List<double>? pen, List<double>? auto}) => Game(
      seasonId: 10,
      players: List.generate(10, (i) => 'p$i'),
      roles: List.filled(10, 'Мирный'),
      cityWon: true,
      firstKilled: 0,
      bestMovePoints: 0,
      bestMove: const [],
      additionalPoints: add,
      penaltyPoints: pen,
      autoAdditionalPoints: auto,
    );

List<double> _row(Map<int, double> values) =>
    List.generate(10, (i) => values[i] ?? 0.0);

void main() {
  test('plus sums positive доп only', () {
    final g = _g(add: _row({0: 0.3, 1: 0.5, 2: -0.2}));
    expect(g.hostPlus, closeTo(0.8, 1e-9));
    expect(g.slotPlus(2), 0.0);
  });

  test('minus takes negative доп but skips the -2 disqualification', () {
    final g = _g(add: _row({0: -0.3, 1: -2.0}));
    expect(g.hostMinus, closeTo(-0.3, 1e-9));
    expect(g.slotMinus(1), 0.0);
  });

  test('minus adds the penalty column', () {
    final g = _g(add: _row({0: 0.4}), pen: _row({3: -0.5, 4: -1.0}));
    expect(g.hostMinus, closeTo(-1.5, 1e-9));
    expect(g.hostPlus, closeTo(0.4, 1e-9));
  });

  test('auto additional points are ignored', () {
    final g = _g(auto: _row({0: 0.3, 1: 0.3}));
    expect(g.hostPlus, 0.0);
  });

  test('games without point columns give zero', () {
    final g = _g();
    expect(g.hostPlus, 0.0);
    expect(g.hostMinus, 0.0);
  });

  test('periods split seasons 2-3 from 4+ and skip 0-1', () {
    expect(PointsPeriod.li.contains(2), isTrue);
    expect(PointsPeriod.li.contains(4), isFalse);
    expect(PointsPeriod.modern.contains(4), isTrue);
    expect(PointsPeriod.modern.contains(30), isTrue);
    expect(PointsPeriod.li.contains(1), isFalse);
    expect(PointsPeriod.modern.contains(0), isFalse);
  });
}
