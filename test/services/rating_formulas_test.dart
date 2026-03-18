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
  });
}
