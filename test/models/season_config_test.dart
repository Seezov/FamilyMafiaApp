import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SeasonConfig.fromJson smallLeagueMinGames', () {
    test('reads the field when present', () {
      final config = SeasonConfig.fromJson({
        'id': 30,
        'title': 'Season 30',
        'gameLimit': 40,
        'gamesMultiplier': 0.0,
        'smallLeagueMinGames': 20,
        'source': 'remote',
        'spreadsheetId': 'abc',
        'sheetName': 'Ігри',
        'range': 'A2:Q',
      });

      expect(config.smallLeagueMinGames, 20);
    });

    test('defaults to 15 when the field is absent', () {
      final config = SeasonConfig.fromJson({
        'id': 28,
        'title': 'Season 28',
        'gameLimit': 55,
        'gamesMultiplier': 0.0,
        'source': 'bundled',
        'jsonFile': 'season28.json',
      });

      expect(config.smallLeagueMinGames, 15);
    });

    test('round-trips through toJson', () {
      const config = SeasonConfig(
        id: 6,
        title: 'Season 6',
        gameLimit: 70,
        gamesMultiplier: 0.004,
        smallLeagueMinGames: 30,
        source: BundledSource(jsonFile: 'season6.json'),
      );

      expect(SeasonConfig.fromJson(config.toJson()).smallLeagueMinGames, 30);
    });
  });
}
