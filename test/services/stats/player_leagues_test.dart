import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_leagues.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _c(int id) => SeasonConfig(id: id, title: 'S$id', gameLimit: 40, smallLeagueMinGames: 15,
    gamesMultiplier: 0, source: const BundledSource(jsonFile: 'x'));

void main() {
  const me = Player(id: 3, displayName: 'Braun');
  RatingPlayerStats r(int s, int g) => RatingPlayerStats(seasonId: s, player: me, gamesPlayed: g);

  test('classifies every configured season', () {
    final leagues = leaguesForPlayer(
      me,
      {1: [r(1, 40)], 2: [r(2, 39)], 3: [r(3, 14)]},
      [_c(1), _c(2), _c(3), _c(4)],
    );
    expect(leagues, {
      1: SeasonLeague.main,
      2: SeasonLeague.small,
      3: SeasonLeague.below,
      4: SeasonLeague.none,
    });
  });
}
