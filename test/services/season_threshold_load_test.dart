import 'dart:io';

import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<SeasonLoaderService> load(SeasonMeta meta) async {
    final loader = SeasonLoaderService(PlayersRepository(), GamesRepository(),
        RatingRepository(), SeasonRepository(), RolePercentilesRepository());
    await loader.loadSeasons(
      metas: [meta],
      playersJson: File('assets/raw/players.json').readAsStringSync(),
      seasonJsons: [File('assets/raw/season28.json').readAsStringSync()],
    );
    return loader;
  }

  test('top3 season in progress: live formula', () async {
    final l = await load(SeasonMeta(28, 0, 0.0,
        rule: GameLimitRule.top3, gameLimitSet: false, now: DateTime.utc(2026, 2, 1)));
    final t = l.thresholds[28]!;
    expect((t.gameLimit, t.formula, t.live), (55, 55.0, true));
  });

  test('top3 season ended with the admin value', () async {
    final l = await load(SeasonMeta(28, 54, 0.0,
        rule: GameLimitRule.top3, now: DateTime.utc(2026, 10, 5)));
    final t = l.thresholds[28]!;
    expect((t.gameLimit, t.live), (54, false));
  });

  test('the effective limit drives the main league', () async {
    final loader = SeasonLoaderService(PlayersRepository(), GamesRepository(),
        RatingRepository(), SeasonRepository(), RolePercentilesRepository());
    final players = File('assets/raw/players.json').readAsStringSync();
    final json = File('assets/raw/season28.json').readAsStringSync();
    final fixed = seasonStandingsForTest(const SeasonMeta(28, 55, 0.0), players, json);
    final top3 = seasonStandingsForTest(
        SeasonMeta(28, 0, 0.0, rule: GameLimitRule.top3, gameLimitSet: false, now: DateTime.utc(2026, 10, 5)),
        players, json);
    expect(top3.map((p) => p.player.displayName), fixed.map((p) => p.player.displayName));
    expect(loader.thresholds, isEmpty);
  });

  test('fixed seasons record their configured limit', () async {
    final l = await load(const SeasonMeta(28, 55, 0.0));
    expect(l.thresholds[28], (gameLimit: 55, formula: null, live: false));
  });
}
