import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

/// All-time placements and awards for [player]: top 3 of the main and small
/// league in each season, season awards, and tournament prize places.
///
/// [seasons] player stats must already be sorted by rating, best first.
PlayerAccomplishments computeAccomplishments(
  Player player,
  Map<int, SeasonStats> seasons,
  List<SeasonConfig> configs,
  List<Tournament> tournaments,
  PlayerResolver resolver,
) {
  final key = personKey(player);
  final configById = {for (final c in configs) c.id: c};
  final acc = PlayerAccomplishments(player);

  // 0-based place of the player within [league], or -1 outside the top 3.
  int place(Iterable<Player> league) =>
      league.take(3).toList().indexWhere((p) => personKey(p) == key);

  for (final MapEntry(key: seasonId, value: stats) in seasons.entries) {
    final config = configById[seasonId];
    if (config == null) continue;

    final main = stats.playerStats
        .where((p) => p.gamesPlayed >= config.gameLimit)
        .map((p) => p.player);
    switch (place(main)) {
      case 0: acc.firsts++;
      case 1: acc.seconds++;
      case 2: acc.thirds++;
    }

    final small = stats.playerStats
        .where((p) =>
            p.gamesPlayed >= config.smallLeagueMinGames &&
            p.gamesPlayed < config.gameLimit)
        .map((p) => p.player);
    switch (place(small)) {
      case 0: acc.smallFirsts++;
      case 1: acc.smallSeconds++;
      case 2: acc.smallThirds++;
    }

    if (stats.mvpPlayerId == player.id) acc.mvp++;
    if (stats.bestSheriffPlayerId == player.id) acc.bestSheriff++;
    if (stats.bestDonPlayerId == player.id) acc.bestDon++;
    if (stats.bestCivilianPlayerId == player.id) acc.bestCivilian++;
    if (stats.bestMafiaPlayerId == player.id) acc.bestMafia++;
  }

  for (final t in tournaments) {
    final i = place(t.podium.map(resolver.resolve));
    if (i < 0) continue;
    (acc.tournamentPlaces[t.type] ??= [0, 0, 0])[i]++;
  }

  return acc;
}
