import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/club_season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases = (jsonDecode(File('test/fixtures/club_season_cases.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  test('validity matches every shared case (same fixture as the TS test)', () {
    for (final c in cases) {
      final errors = clubSeasonErrors(parseClubSeasons(c['seasons']), lastJsonId: c['lastJsonId'] as int);
      expect(errors.isEmpty, c['valid'], reason: '${c['case']}: $errors');
    }
  });

  test('more than 100 seasons is invalid', () {
    final many = [
      for (var i = 0; i < kMaxClubSeasons + 1; i++)
        ClubSeason(id: 32 + i, title: 'S', smallLeagueMinGames: 15, startDate: '2026-12-01'),
    ];
    expect(clubSeasonErrors(many, lastJsonId: 31), isNotEmpty);
  });

  test('parseClubSeasons rejects wrong types', () {
    expect(() => parseClubSeasons('x'), throwsFormatException);
    expect(() => parseClubSeasons([{'id': '32', 'title': 'S', 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'}]), throwsFormatException);
    expect(() => parseClubSeasons([{'id': 32, 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'}]), throwsFormatException);
  });

  test('checkClubSeasons names the problem', () {
    expect(() => checkClubSeasons(parseClubSeasons(cases[3]['seasons']), lastJsonId: 31),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('33'))));
  });

  test('toConfigJson is a firestore SeasonConfig with the top3 rule', () {
    const s = ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 12, startDate: '2026-12-01');
    final config = SeasonConfig.fromJson(s.toConfigJson());
    expect(config.id, 32);
    expect(config.title, 'Season 32');
    expect(config.source, isA<FirestoreSource>());
    expect(s.toConfigJson(), containsPair('gameLimitRule', 'top3'));
    expect(s.toConfigJson(), containsPair('smallLeagueMinGames', 12));
    expect(s.toConfigJson().containsKey('startDate'), isFalse);
  });

  test('appendClubSeasons keeps the JSON first and drops a clashing id', () {
    final json = [{'id': 31, 'title': 'Season 31'}];
    final out = appendClubSeasons(json, const [
      ClubSeason(id: 31, title: 'Dup', smallLeagueMinGames: 15, startDate: '2026-12-01'),
      ClubSeason(id: 32, title: 'Season 32', smallLeagueMinGames: 15, startDate: '2026-12-01'),
    ]);
    expect(out.map((s) => s['title']), ['Season 31', 'Season 32']);
    expect(lastSeasonId(json), 31);
  });
}
