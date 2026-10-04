import 'dart:convert';

import 'package:family_mafia_app/site_export/site_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cells drop non-finite sort keys so jsonEncode never throws', () {
    final table = SiteTable(
      columns: const [SiteColumn('Player', numeric: false), SiteColumn('WR')],
      rows: [
        [const SiteCell('Sasha', link: 'sasha'), const SiteCell('–', s: 0 / 0)],
        [const SiteCell('Olya'), const SiteCell('–', s: 1 / 0)],
      ],
    );
    final json = jsonDecode(jsonEncode(table.toJson())) as Map<String, dynamic>;
    final rows = json['rows'] as List;
    expect((rows[0] as List)[1], {'t': '–'});
    expect((rows[1] as List)[1], {'t': '–'});
    expect((rows[0] as List)[0], {'t': 'Sasha', 'link': 'sasha'});
    expect(json['desc'], true);
    expect(json['showRank'], false);
  });

  test('a row with the wrong number of cells is rejected', () {
    expect(
      () => const SiteTable(columns: [SiteColumn('A')], rows: [[]]).toJson(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('columns only serialise what is set', () {
    expect(const SiteColumn('W/G', group: 'Don', phone: false).toJson(),
        {'label': 'W/G', 'numeric': true, 'group': 'Don', 'phone': false});
  });
}
