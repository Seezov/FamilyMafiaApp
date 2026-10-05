import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/services/stats/threshold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formulaThreshold', () {
    test('matches the sheets', () {
      expect(formulaThreshold([122, 91, 87, 54]), 55.0); // S28
      expect(formulaThreshold([102, 87, 87]), closeTo(50.2, 1e-9)); // S29
      expect(formulaThreshold([93, 70, 65, 12]), closeTo(40.6, 1e-9)); // S30
      expect(formulaThreshold([40, 38, 24, 17, 3]), closeTo(15.4, 1e-9)); // S31
    });
    test('fewer than 3 players count as 0', () {
      expect(formulaThreshold([10]), closeTo(-3.0, 1e-9));
      expect(formulaThreshold([]), -5.0);
    });
  });

  group('effectiveThreshold', () {
    final oct = DateTime.utc(2026, 10, 5);
    final s31Dates = [DateTime.utc(2026, 9, 1), DateTime.utc(2026, 9, 15), DateTime.utc(2026, 10, 3)];
    SeasonThreshold eff({GameLimitRule rule = GameLimitRule.top3, int? configured, List<int> games = const [40, 38, 24], List<DateTime>? dates, DateTime? now}) =>
        effectiveThreshold(rule: rule, configured: configured, ratingGames: games, gameDates: dates ?? s31Dates, now: now ?? oct);

    test('in progress: formula, rounded up, live', () {
      final t = eff(configured: 40);
      expect(t.gameLimit, 16);
      expect(t.formula, closeTo(15.4, 1e-9));
      expect(t.live, isTrue);
    });
    test('exact integer is not pushed up by float noise', () {
      expect(eff(games: [122, 91, 87]).gameLimit, 55);
    });
    test('ended without a configured value: ceil(formula)', () {
      final t = eff(now: DateTime.utc(2026, 12, 1));
      expect((t.gameLimit, t.live), (16, false));
      expect(t.formula, closeTo(15.4, 1e-9));
    });
    test('ended with the admin value', () {
      expect(eff(configured: 15, now: DateTime.utc(2026, 12, 1)).gameLimit, 15);
    });
    test('negative formula is 0', () {
      expect(eff(games: [1, 1]).gameLimit, 0);
    });
    test('no dated games: not in progress', () {
      final t = eff(dates: const []);
      expect(t.live, isFalse);
      expect(t.gameLimit, 16);
    });
    test('fixed rule ignores the formula', () {
      final t = eff(rule: GameLimitRule.fixed, configured: 40);
      expect((t.gameLimit, t.formula, t.live), (40, null, false));
    });
  });

  test('GameLimitRule.parse', () {
    expect(GameLimitRule.parse('top3'), GameLimitRule.top3);
    expect(GameLimitRule.parse(null), GameLimitRule.fixed);
    expect(GameLimitRule.parse('other'), GameLimitRule.fixed);
  });
}
