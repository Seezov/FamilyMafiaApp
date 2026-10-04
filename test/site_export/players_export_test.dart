import 'dart:convert';

import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixture.dart';

void main() {
  late ExportContext x;
  setUp(() async => x = ExportContext(await fixtureContainer()));

  test('directory lists every player once, with slugs', () {
    final json = jsonDecode(jsonEncode(playersJson(x))) as Map;
    final players = json['players'] as List;
    expect(players.map((p) => p['id']), x.players.map((p) => p.id));
    expect(players.map((p) => p['slug']).toSet(), hasLength(players.length));
    expect(players.any((p) => ['/', '.', '..', ''].contains(p['name'])), isFalse);
    expect((json['table']['rows'] as List), hasLength(players.length));
  });

  test('profile numbers come from the profile providers', () {
    final p = x.players.first; // most games
    final json = jsonDecode(jsonEncode(playerJson(x, p))) as Map;
    final stats = x.read(playerStatsMapProvider)[p.displayName]!;
    expect(json['games'], stats.games);
    expect(json['slug'], x.slugs[p.id]);
    expect((json['timeline'] as List).map((t) => t['seasonId']), [17, 21]);
    final roleGames = (json['roles'] as List).fold<int>(0, (s, r) => s + (r['games'] as int));
    expect(roleGames, greaterThan(0));
    final bm = json['bestMoves'] as Map;
    expect(bm['zero'] + bm['one'] + bm['two'] + bm['three'], bm['firstKilled']);
  });
}
