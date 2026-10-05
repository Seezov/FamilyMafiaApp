import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:family_mafia_app/site_export/season_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('season and player JSON carry the live threshold', () async {
    final c = await fixtureContainer(seasonIds: [21]);
    final cfg = c.read(loadedSeasonConfigsProvider).single;
    c.read(loadedSeasonConfigsProvider.notifier).state =
        [cfg.withThreshold((gameLimit: 16, formula: 15.4, live: true))];
    final x = ExportContext(c);
    final j = seasonJson(x, x.seasons.single);
    expect((j['gameLimit'], j['thresholdFormula'], j['thresholdLive']), (16, 15.4, true));

    Map timeline(p) => (playerJson(x, p)['timeline'] as List).cast<Map>().single;
    final chasing = x.players.firstWhere((p) {
      final g = timeline(p)['games'] as int;
      return g > 0 && g < 16;
    });
    expect(timeline(chasing)['needed'], 16 - (timeline(chasing)['games'] as int));
    final main = x.players.firstWhere((p) => (timeline(p)['games'] as int) >= 16);
    expect(timeline(main).containsKey('needed'), isFalse);
  });

  test('a finished season has no live threshold and no "needed"', () async {
    final c = await fixtureContainer(seasonIds: [21]);
    final x = ExportContext(c);
    final j = seasonJson(x, x.seasons.single);
    expect((j['thresholdFormula'], j['thresholdLive']), (null, false));
    for (final p in x.players.take(40)) {
      expect((playerJson(x, p)['timeline'] as List).cast<Map>().single.containsKey('needed'), isFalse);
    }
  });
}
