import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

enum SeasonLeague { main, small, below, none }

Map<int, SeasonLeague> leaguesForPlayer(
  Player player,
  Map<int, List<RatingPlayerStats>> ratings,
  List<SeasonConfig> configs,
) {
  final key = personKey(player);
  return {
    for (final c in configs)
      c.id: () {
        final games = (ratings[c.id] ?? const [])
            .where((p) => personKey(p.player) == key)
            .fold(0, (s, p) => s + p.gamesPlayed);
        if (games == 0) return SeasonLeague.none;
        if (games >= c.gameLimit) return SeasonLeague.main;
        if (games >= c.smallLeagueMinGames) return SeasonLeague.small;
        return SeasonLeague.below;
      }(),
  };
}
