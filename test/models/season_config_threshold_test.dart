import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> json(Map<String, dynamic> extra) => {
        'id': 31, 'title': 'Season 31', 'gamesMultiplier': 0.0,
        'source': 'bundled', 'jsonFile': 'x.json', ...extra,
      };

  test('top3 without gameLimit', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}));
    expect(c.gameLimitRule, GameLimitRule.top3);
    expect(c.gameLimitSet, isFalse);
    expect(c.toJson().containsKey('gameLimit'), isFalse);
    expect(c.toJson()['gameLimitRule'], 'top3');
  });

  test('top3 with the admin value', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3', 'gameLimit': 41}));
    expect((c.gameLimit, c.gameLimitSet), (41, true));
  });

  test('fixed is the default and needs gameLimit', () {
    final c = SeasonConfig.fromJson(json({'gameLimit': 40}));
    expect(c.gameLimitRule, GameLimitRule.fixed);
    expect(c.toJson().containsKey('gameLimitRule'), isFalse);
    expect(() => SeasonConfig.fromJson(json({})), throwsFormatException);
  });

  test('admin limits from config/club apply to top3 seasons only', () {
    final top3 = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}));
    final fixed = SeasonConfig.fromJson(json({'id': 30, 'gameLimit': 40}));
    final out = applyAdminLimits([top3, fixed], {31: 41, 30: 99});
    expect((out[0].gameLimit, out[0].gameLimitSet), (41, true));
    expect(out[1].gameLimit, 40);
    expect(applyAdminLimits([top3], {}).single.gameLimitSet, isFalse);
  });

  test('withThreshold', () {
    final c = SeasonConfig.fromJson(json({'gameLimitRule': 'top3'}))
        .withThreshold((gameLimit: 16, formula: 15.4, live: true));
    expect((c.gameLimit, c.thresholdFormula, c.thresholdLive, c.gameLimitSet), (16, 15.4, true, false));
    expect(c.title, 'Season 31');
  });
}
