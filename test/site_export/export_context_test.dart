import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('slugs cover every listed player and name cells link to them', () async {
    final x = ExportContext(await fixtureContainer());
    expect(x.players, isNotEmpty);
    expect(x.slugs.keys.toSet(), x.players.map((p) => p.id).toSet());
    final cell = x.name(x.players.first);
    expect(cell.t, x.players.first.displayName);
    expect(cell.link, x.slugs[x.players.first.id]);
  });

  test('select switches season and league', () async {
    final x = ExportContext(await fixtureContainer());
    expect(x.seasons.map((s) => s.id), [17, 21]);
    x.select(x.seasons.last, League.small);
    expect(x.read(selectedSeasonProvider)!.id, 21);
    expect(x.read(selectedLeagueProvider), League.small);
  });
}
