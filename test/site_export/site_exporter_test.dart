import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/site_export/site_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  test('writes every file, one page per player, and clears stale ones', () async {
    final out = Directory.systemTemp.createTempSync('site_data');
    addTearDown(() => out.deleteSync(recursive: true));
    File('${out.path}/player/stale.json').createSync(recursive: true);

    await writeSiteData(await fixtureContainer(), out);

    for (final f in ['index.json', 'players.json', 'records.json', 'tournaments.json', 'season/17.json', 'season/21.json']) {
      expect(File('${out.path}/$f').existsSync(), isTrue, reason: f);
    }
    expect(File('${out.path}/player/stale.json').existsSync(), isFalse);
    final players = (jsonDecode(File('${out.path}/players.json').readAsStringSync()) as Map)['players'] as List;
    for (final p in players) {
      expect(File('${out.path}/player/${p['slug']}.json').existsSync(), isTrue);
    }
  });
}
