import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const json = {
    'id': 32, 'title': 'Season 32', 'gameLimit': 40, 'gamesMultiplier': 0.0,
    'smallLeagueMinGames': 15, 'source': 'firestore', 'projectId': 'family-mafia-club',
  };

  test('parses a firestore source', () {
    final c = SeasonConfig.fromJson(json);
    expect(c.source, isA<FirestoreSource>());
    expect((c.source as FirestoreSource).projectId, 'family-mafia-club');
  });

  test('round-trips through toJson', () {
    expect(SeasonConfig.fromJson(json).toJson(), json);
  });
}
