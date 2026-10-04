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

  void at(String key, String source) => (acc.where[key] ??= []).add(source);

  for (final seasonId in seasons.keys.toList()..sort()) {
    final stats = seasons[seasonId]!;
    final config = configById[seasonId];
    if (config == null) continue;
    final s = 'S$seasonId';

    final main = stats.playerStats
        .where((p) => p.gamesPlayed >= config.gameLimit)
        .map((p) => p.player);
    final mainPlace = place(main);
    switch (mainPlace) {
      case 0:
        acc.firsts++;
      case 1:
        acc.seconds++;
      case 2:
        acc.thirds++;
    }
    if (mainPlace >= 0) at('main:$mainPlace', s);

    final small = stats.playerStats
        .where(
          (p) =>
              p.gamesPlayed >= config.smallLeagueMinGames &&
              p.gamesPlayed < config.gameLimit,
        )
        .map((p) => p.player);
    final smallPlace = place(small);
    switch (smallPlace) {
      case 0:
        acc.smallFirsts++;
      case 1:
        acc.smallSeconds++;
      case 2:
        acc.smallThirds++;
    }
    if (smallPlace >= 0) at('small:$smallPlace', s);

    if (stats.mvpPlayerId == player.id) {
      acc.mvp++;
      at('mvp', s);
    }
    if (stats.bestSheriffPlayerId == player.id) {
      acc.bestSheriff++;
      at('sheriff', s);
    }
    if (stats.bestDonPlayerId == player.id) {
      acc.bestDon++;
      at('don', s);
    }
    if (stats.bestCivilianPlayerId == player.id) {
      acc.bestCivilian++;
      at('civilian', s);
    }
    if (stats.bestMafiaPlayerId == player.id) {
      acc.bestMafia++;
      at('mafia', s);
    }
    if (stats.mostKilledPlayerId == player.id) {
      acc.mostKilled++;
      at('killed', s);
    }
  }

  for (final t in tournaments) {
    final i = place(t.podium.map(resolver.resolve));
    if (i < 0) continue;
    (acc.tournamentPlaces[t.type] ??= [0, 0, 0])[i]++;
    at('${t.type.name}:$i', '${t.name} · S${t.seasonId}');
  }

  return acc;
}
