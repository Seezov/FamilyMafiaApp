import 'package:family_mafia_app/services/rating_formulas.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── isDonOrSheriff ───────────────────────────────────────────────────────

  group('isDonOrSheriff', () {
    test('Дон is don', () => expect(isDonOrSheriff('Дон'), true));
    test('Шериф is sheriff', () => expect(isDonOrSheriff('Шериф'), true));
    test('Мирный is not', () => expect(isDonOrSheriff('Мирный'), false));
    test('Мафия is not', () => expect(isDonOrSheriff('Мафия'), false));
  });

  // ── calculateWinByRole ───────────────────────────────────────────────────

  group('calculateWinByRole', () {
    test('season 0-1: don/sheriff gets 4x multiplier', () {
      expect(calculateWinByRole(0, 'Дон', 5), 20);
      expect(calculateWinByRole(1, 'Шериф', 3), 12);
    });

    test('season 0-1: civilian/mafia gets 3x multiplier', () {
      expect(calculateWinByRole(0, 'Мирный', 5), 15);
      expect(calculateWinByRole(1, 'Мафия', 4), 12);
    });

    test('season 2-3: all roles get 2x multiplier', () {
      expect(calculateWinByRole(2, 'Дон', 5), 10);
      expect(calculateWinByRole(3, 'Мирный', 5), 10);
    });

    test('season 4-16: all roles get 1x multiplier', () {
      expect(calculateWinByRole(4, 'Дон', 7), 7);
      expect(calculateWinByRole(16, 'Мафия', 3), 3);
    });

    test('season 17+: returns 0', () {
      expect(calculateWinByRole(17, 'Дон', 10), 0);
      expect(calculateWinByRole(29, 'Мирный', 5), 0);
    });
  });

  // ── calculateWinPoints ───────────────────────────────────────────────────

  group('calculateWinPoints', () {
    test('season 0-1: winByRoleSum - loseByRoleSum + penalty + bestMove', () {
      final result = calculateWinPoints(1, 2.0, 1.5, -0.5, 0.0, 0.0, 10, 3);
      expect(result, 10 - 3 + (-0.5) + 1.5); // 8.0
    });

    test('season 2-3: winByRoleSum + additional + bestMove + penalty', () {
      final result = calculateWinPoints(3, 2.0, 1.0, -1.0, 0.0, 0.0, 8, 0);
      expect(result, 8 + 2.0 + 1.0 + (-1.0)); // 10.0
    });

    test('season 4-16: winByRoleSum + additional + bestMove', () {
      final result = calculateWinPoints(10, 3.0, 2.0, -1.0, 0.0, 0.0, 5, 0);
      expect(result, 5 + 3.0 + 2.0); // 10.0
    });

    test('season 17+: additional + autoAdditional + penalty + bestMove + ci', () {
      final result = calculateWinPoints(21, 3.0, 2.0, -1.0, 0.5, 1.5, 0, 0);
      expect(result, 3.0 + 1.5 + (-1.0) + 2.0 + 0.5); // 6.0
    });
  });

  // ── calculateCiForGame ───────────────────────────────────────────────────

  group('calculateCiForGame', () {
    test('season <= 16: always 0.0', () {
      expect(calculateCiForGame(5, 10, 50, 16), 0.0);
      expect(calculateCiForGame(5, 10, 50, 0), 0.0);
    });

    test('season 17-18: always 0.1', () {
      expect(calculateCiForGame(5, 10, 50, 17), 0.1);
      expect(calculateCiForGame(5, 10, 50, 18), 0.1);
    });

    test('season 19-20: low first-kill rate uses proportional formula', () {
      // r = 5/50 = 0.1, which is <= 0.399
      // result = 0.1 * 5/2 * 0.4 = 0.1
      final result = calculateCiForGame(3, 5, 50, 19);
      expect(result, closeTo(0.1, 1e-9));
    });

    test('season 19-20: high first-kill rate uses max factor', () {
      // r = 25/50 = 0.5, which is > 0.399
      // result = 0.4 * firstKilledCityLost = 0.4 * 10 = 4.0
      final result = calculateCiForGame(10, 25, 50, 20);
      expect(result, closeTo(4.0, 1e-9));
    });

    test('season 21+: low first-kill rate uses r * 1.25', () {
      // r = 5/50 = 0.1, which is <= 0.399
      // result = 0.1 * 1.25 = 0.125
      final result = calculateCiForGame(3, 5, 50, 21);
      expect(result, closeTo(0.125, 1e-9));
    });

    test('season 21+: high first-kill rate returns 0.5', () {
      // r = 25/50 = 0.5, which is > 0.399
      final result = calculateCiForGame(10, 25, 50, 25);
      expect(result, 0.5);
    });
  });

  // ── calculateAvgRedGamePoints (season 30+, "CI/I" in the spreadsheet) ─────

  group('calculateAvgRedGamePoints', () {
    test('no red games returns 0', () {
      expect(calculateAvgRedGamePoints(const []), 0.0);
    });

    test('averages the points scored in red games', () {
      // (0.3 + 0.0 + 0.6) / 3 = 0.3
      expect(calculateAvgRedGamePoints(const [0.3, 0.0, 0.6]),
          closeTo(0.3, 1e-9));
    });

    test('includes negative games in the average', () {
      // (0.4 + (-0.2)) / 2 = 0.1
      expect(calculateAvgRedGamePoints(const [0.4, -0.2]), closeTo(0.1, 1e-9));
    });
  });

  // ── calculateCiTopUp (season 30+, "СІ" in the spreadsheet) ───────────────

  group('calculateCiTopUp', () {
    test('no first-kill losses returns 0', () {
      expect(calculateCiTopUp(0.26, const []), 0.0);
    });

    test('tops a scoreless first-kill loss up to the average', () {
      expect(calculateCiTopUp(0.26, const [0.0]), closeTo(0.26, 1e-9));
    });

    test('pays nothing when the player already beat their average', () {
      expect(calculateCiTopUp(0.26, const [0.4]), 0.0);
    });

    test('never returns a negative top-up for a single game', () {
      // 0.09 - 0.4 is negative for the first game but must not cancel the second
      expect(calculateCiTopUp(0.09, const [0.4, 0.0]), closeTo(0.09, 1e-9));
    });

    test('treats a negative game score as zero, not as a bonus', () {
      // sheet uses (S > 0) * S, so a penalty game still tops up by the full avg
      expect(calculateCiTopUp(0.26, const [-0.3]), closeTo(0.26, 1e-9));
    });

    test('rounds the average to 2 decimals before topping up', () {
      // 0.2592 → 0.26, so two scoreless losses pay 0.52 (not 0.5184)
      expect(calculateCiTopUp(0.25918367346938775, const [0.0, 0.0]),
          closeTo(0.52, 1e-9));
    });

    test('rounds a binary-noisy .xx5 average half away from zero', () {
      // Seezov's clubmate Залізний: avg 0.07499999999999998 → 0.08, not 0.07
      expect(calculateCiTopUp(0.07499999999999998, const [0.0, 0.0, 0.4, 0.4]),
          closeTo(0.16, 1e-9));
    });

    test('reproduces Seezov season 30', () {
      const s = [0.3, 0.0, 0.3, 0.4, 0.3, 0.3, 0.0, 0.4, 0.0, 0.0, 0.4, 0.0];
      expect(calculateCiTopUp(0.25918367346938775, s), closeTo(1.30, 1e-9));
    });

    test('reproduces Braun season 30', () {
      const s = [0.4, 0.3, 0.0, 0.3, 0.0, 0.0];
      expect(calculateCiTopUp(0.09285714285714285, s), closeTo(0.27, 1e-9));
    });

    test('reproduces Хоттабич season 30', () {
      expect(calculateCiTopUp(0.28529411764705875, const [0.0, 0.0, 0.0]),
          closeTo(0.87, 1e-9));
    });
  });

  // ── calculateMvp ─────────────────────────────────────────────────────────

  group('calculateMvp', () {
    test('season 0-1: winPoints / gamesPlayed rounded to 3', () {
      // 10.0 / 3 = 3.33333... → roundTo(3) = 3.333
      final result = calculateMvp(1, 3, 2.0, 1.0, -0.5, 10.0);
      expect(result, closeTo(3.333, 1e-9));
    });

    test('season 2+: (additional + bestMove + penalty) / gamesPlayed rounded to 4', () {
      // (2.0 + 1.5 + (-0.3)) / 10 = 0.32 → roundTo(4) = 0.32
      final result = calculateMvp(5, 10, 2.0, 1.5, -0.3, 50.0);
      expect(result, closeTo(0.32, 1e-9));
    });
  });

  // ── calculateRatingCoefficient ───────────────────────────────────────────

  group('calculateRatingCoefficient', () {
    SeasonMeta meta(int id, {double mult = 0.0}) =>
        SeasonMeta(id, 60, mult);

    test('season 0-1: avgWinPoints * 100 + games * multiplier', () {
      // winPoints=10, games=5, mult=0.5
      // (10/5).roundTo(2) * 100 + 5 * 0.5 = 2.0*100 + 2.5 = 202.5
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 10.0,
        gamesPlayed: 5,
        winRate: 0.6,
        ci: 0.0,
        bestMovePoints: 0.0,
        additionalPoints: 0.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 0.0,
        season: meta(1, mult: 0.5),
      );
      expect(result, closeTo(202.5, 1e-3));
    });

    test('season 2-3: winPoints/games + games * multiplier', () {
      // 10/5 + 5*0.2 = 2.0 + 1.0 = 3.0
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 10.0,
        gamesPlayed: 5,
        winRate: 0.6,
        ci: 0.0,
        bestMovePoints: 0.0,
        additionalPoints: 0.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 0.0,
        season: meta(2, mult: 0.2),
      );
      expect(result, closeTo(3.0, 1e-3));
    });

    test('season 4: (winPoints/games + games*mult) * 100', () {
      // (10/5 + 5*0.1) * 100 = (2.0 + 0.5) * 100 = 250.0
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 10.0,
        gamesPlayed: 5,
        winRate: 0.6,
        ci: 0.0,
        bestMovePoints: 0.0,
        additionalPoints: 0.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 0.0,
        season: meta(4, mult: 0.1),
      );
      expect(result, closeTo(250.0, 1e-3));
    });

    test('season 5-16: winRate-weighted formula * 100', () {
      // winRate=0.6, games=10, winPoints=15, mult=0.05
      // ((15/10).roundTo(2) + 10*(0.6*100).roundTo(2)/100*0.05).roundTo(3)*100
      // = (1.5 + 10*60.0/100*0.05).roundTo(3)*100
      // = (1.5 + 0.3).roundTo(3)*100
      // = 1.8*100 = 180.0
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 15.0,
        gamesPlayed: 10,
        winRate: 0.6,
        ci: 0.0,
        bestMovePoints: 0.0,
        additionalPoints: 0.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 0.0,
        season: meta(10, mult: 0.05),
      );
      expect(result, closeTo(180.0, 1e-3));
    });

    test('season 17: includes Iron Man correction', () {
      // winRate*100 + winPoints/games + ci + bestMove + autoAdd + add + bonus
      // 0.5*100 + 20/10 + 0.3 + 1.0 + 0.9 + 2.0 + 1 = 50+2+0.3+1+0.9+2+1 = 57.2
      final result = calculateRatingCoefficient(
        player: 'Железный',
        winPoints: 20.0,
        gamesPlayed: 10,
        winRate: 0.5,
        ci: 0.3,
        bestMovePoints: 1.0,
        additionalPoints: 2.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 0.9,
        season: meta(17),
      );
      expect(result, closeTo(57.2, 1e-3));
    });

    test('season 18-20: deducts games without auto points * 0.3', () {
      // autoAdd=3.0, games=20 → autoGames = (3.0/0.3).round() = 10
      // gamesWithoutAuto = 20 - 10 = 10
      // winRate*100 + winPoints/games + ci + bestMove + add - 10*0.3
      // 0.5*100 + 30/20 + 0.2 + 1.0 + 2.0 - 3.0
      // = 50 + 1.5 + 0.2 + 1.0 + 2.0 - 3.0 = 51.7
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 30.0,
        gamesPlayed: 20,
        winRate: 0.5,
        ci: 0.2,
        bestMovePoints: 1.0,
        additionalPoints: 2.0,
        penaltyPoints: 0.0,
        autoAdditionalPoints: 3.0,
        season: meta(19),
      );
      expect(result, closeTo(51.7, 1e-3));
    });

    test('season 21+: standard new formula', () {
      // winRate*100 + winPoints/games + ci + bestMove + add + penalty
      // 0.6*100 + 20/10 + 0.5 + 1.0 + 2.0 + (-0.5)
      // = 60 + 2 + 0.5 + 1.0 + 2.0 - 0.5 = 65.0
      final result = calculateRatingCoefficient(
        player: 'Test',
        winPoints: 20.0,
        gamesPlayed: 10,
        winRate: 0.6,
        ci: 0.5,
        bestMovePoints: 1.0,
        additionalPoints: 2.0,
        penaltyPoints: -0.5,
        autoAdditionalPoints: 0.0,
        season: meta(25),
      );
      expect(result, closeTo(65.0, 1e-3));
    });
    test('season 30+: rounds winRate to 2 decimals and result to 4', () {
      // Seezov season 30: 48/93 wins, ДБ 27.1, штраф -3.4, ОП 4.0, СІ 1.30
      // winPoints = 27.1 - 3.4 + 4.0 + 1.30 = 29.0
      // ROUND(48/93*100, 2) = 51.61  (not 51.612903...)
      // 51.61 + 29.0/93 + 1.30 + 4.0 + 27.1 - 3.4 = 80.92182795...
      final result = calculateRatingCoefficient(
        player: 'Seezov',
        winPoints: 29.0,
        gamesPlayed: 93,
        winRate: 48 / 93,
        ci: 1.30,
        bestMovePoints: 4.0,
        additionalPoints: 27.1,
        penaltyPoints: -3.4,
        autoAdditionalPoints: 0.0,
        season: meta(30),
      );
      expect(result, 80.9218);
    });

    test('season 29 keeps full-precision winRate and 3-decimal rounding', () {
      // same inputs on season 29: 51.612903... + 29/93 + 29.0 = 80.924731...
      final result = calculateRatingCoefficient(
        player: 'Seezov',
        winPoints: 29.0,
        gamesPlayed: 93,
        winRate: 48 / 93,
        ci: 1.30,
        bestMovePoints: 4.0,
        additionalPoints: 27.1,
        penaltyPoints: -3.4,
        autoAdditionalPoints: 0.0,
        season: meta(29),
      );
      expect(result, 80.925);
    });
  });
}
