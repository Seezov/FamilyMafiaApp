import 'package:family_mafia_app/models/club_config.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the document', () {
    final c = ClubConfig.fromJson({
      'tournaments': [
        {'season': 31, 'type': 'minicap', 'name': 'Cup', 'games': 4, 'date': '01.09.2026', 'podium': ['A', 'B']},
      ],
      'rejectedCandidates': ['31|2026-09-08'],
      'gameLimits': {'31': 41},
    });
    expect(c.tournaments.single.type, TournamentType.minicap);
    expect(c.tournaments.single.podium, ['A', 'B']);
    expect(c.rejectedCandidates, ['31|2026-09-08']);
    expect(c.gameLimits, {31: 41});
  });

  test('missing fields are empty', () {
    final c = ClubConfig.fromJson({});
    expect(c.tournaments, isEmpty);
    expect(c.rejectedCandidates, isEmpty);
    expect(c.gameLimits, isEmpty);
  });
}
