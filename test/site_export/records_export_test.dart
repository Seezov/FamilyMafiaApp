import 'dart:convert';

import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/records_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

String keyFor(Map cat, Map<String, String> f) => [
      cat['slug'],
      for (final name in ['role', 'scope', 'period'])
        if ((cat['filters'] as List).contains(name)) f[name],
    ].join('/');

void main() {
  test('every category × filter combination has a table', () async {
    final x = ExportContext(await fixtureContainer());
    final json = jsonDecode(jsonEncode(recordsJson(x))) as Map;
    final tables = json['tables'] as Map;

    var expected = 0;
    for (final cat in (json['categories'] as List).cast<Map>()) {
      final filters = (cat['filters'] as List).cast<String>();
      final roles = filters.contains('role') ? (json['roles'] as List).map((r) => r['key'] as String) : [''];
      final scopes = filters.contains('scope') ? (json['scopes'] as List).map((r) => r['key'] as String) : [''];
      final periods = filters.contains('period') ? (json['periods'] as List).map((r) => r['key'] as String) : [''];
      for (final role in roles) {
        for (final scope in scopes) {
          for (final period in periods) {
            final key = keyFor(cat, {'role': role, 'scope': scope, 'period': period});
            expect(tables.containsKey(key), isTrue, reason: key);
            expected++;
          }
        }
      }
    }
    expect(tables.length, expected);
    expect(tables['penalties']['scope'], startsWith('Main league · Seasons '));
    expect(tables['streaks']['table']['rows'], isNotEmpty);
  });
}
