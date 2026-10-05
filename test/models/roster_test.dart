import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/roster.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

List<RosterEntry> _fromCase(List<dynamic> r) => parseRoster(r);

void main() {
  final cases = (jsonDecode(File('test/fixtures/roster_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('clashes match every shared case (same fixture as the TS test)', () {
    for (final c in cases) {
      expect(rosterClashes(_fromCase(c['roster'] as List)), c['clashes'], reason: c['case'] as String);
    }
  });

  test('parseRoster rejects malformed entries', () {
    expect(() => parseRoster('x'), throwsFormatException);
    expect(() => parseRoster([{'nicknames': []}]), throwsFormatException);
    expect(() => parseRoster([{'name': 'A', 'nicknames': [1]}]), throwsFormatException);
    expect(parseRoster([{'name': 'A'}]).single.nicknames, isEmpty);
  });

  test('checkRoster: clashes and limits', () {
    expect(() => checkRoster(_fromCase(cases[1]['roster'] as List)), throwsA(isA<FormatException>()
        .having((e) => e.message, 'message', contains('bee'))));
    expect(() => checkRoster(List.generate(kMaxRosterEntries + 1, (i) => RosterEntry('p$i'))), throwsFormatException);
    expect(() => checkRoster([RosterEntry('A', List.generate(kMaxNicknames + 1, (i) => 'n$i'))]), throwsFormatException);
    checkRoster(_fromCase(cases[0]['roster'] as List));
  });

  test('rosterAppJson omits empty nicknames and keeps order', () {
    final json = rosterAppJson([const RosterEntry('A'), const RosterEntry('B', ['b2'])]);
    expect(jsonDecode(json), [
      {'id': 0, 'displayName': 'A'},
      {'id': 0, 'displayName': 'B', 'nicknames': ['b2']},
    ]);
  });

  group('the real assets/raw/players.json', () {
    final raw = File('assets/raw/players.json').readAsStringSync();
    final roster = rosterFromAppJson(raw);

    test('only Night and Volus clash, and dedupe removes exactly their second entries', () {
      expect(rosterClashes(roster), ['night', 'volus']);
      final deduped = dedupeRoster(roster);
      expect(roster.length - deduped.length, 2);
      expect(rosterClashes(deduped), isEmpty);
      checkRoster(deduped);
    });

    test('the deduped roster resolves every name exactly like the file', () {
      List<Player> players(String json) => [
            for (final (i, m) in (jsonDecode(json) as List).cast<Map<String, dynamic>>().indexed)
              Player.fromJson(m).copyWith(id: i)
          ];
      final before = PlayerResolver(players(raw));
      final after = PlayerResolver(players(rosterAppJson(dedupeRoster(roster))));
      for (final e in roster) {
        for (final n in e.names) {
          expect(after.resolve(n).displayName, before.resolve(n).displayName, reason: n);
        }
      }
    });
  });
}
