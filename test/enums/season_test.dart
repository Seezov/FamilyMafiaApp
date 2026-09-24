import 'package:family_mafia_app/enums/season.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Season.smallLeagueMinGames', () {
    test('season 0 uses 8 (short first season, gameLimit 17)', () {
      expect(Season.findById(0)!.smallLeagueMinGames, 8);
    });

    test('season 6 uses 30 (doubled season)', () {
      expect(Season.findById(6)!.smallLeagueMinGames, 30);
    });

    test('seasons 12, 14 and 15 use 20', () {
      for (final id in [12, 14, 15]) {
        expect(Season.findById(id)!.smallLeagueMinGames, 20,
            reason: 'season $id');
      }
    });

    test('every other season uses 15', () {
      const overridden = {0, 6, 12, 14, 15};
      for (final season in Season.values) {
        if (overridden.contains(season.id)) continue;
        expect(season.smallLeagueMinGames, 15, reason: 'season ${season.id}');
      }
    });

    test('the lower bound is always below the game limit', () {
      for (final season in Season.values) {
        expect(season.smallLeagueMinGames, lessThan(season.gameLimit),
            reason: 'season ${season.id}');
      }
    });

    test('toConfig carries the lower bound through', () {
      expect(Season.findById(6)!.toConfig().smallLeagueMinGames, 30);
    });
  });
}
