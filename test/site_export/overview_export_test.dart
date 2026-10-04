import 'dart:convert';

import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/overview_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('overview mirrors the dashboard providers', () async {
    final x = ExportContext(await fixtureContainer());
    final json = jsonDecode(jsonEncode(overviewJson(x))) as Map;

    expect(json['latestSeasonId'], 21);
    expect((json['seasons'] as List).map((s) => s['id']), [17, 21]);
    expect(json['club']['games'], x.read(clubOverviewProvider).games);
    expect((json['roleWR'] as Map).keys,
        containsAll(['civilian', 'sheriff', 'mafia', 'don']));
    expect((json['leaderboards'] as List).map((l) => l['role']),
        ['civilian', 'sheriff', 'mafia', 'don']);

    final seasons = json['seasonsTable'] as Map;
    expect((seasons['rows'] as List), hasLength(2));
    expect((seasons['columns'] as List).first['label'], 'Season');
    for (final row in seasons['rows'] as List) {
      expect((row as List).length, (seasons['columns'] as List).length);
    }
  });
}
