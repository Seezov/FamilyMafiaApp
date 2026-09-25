import 'dart:io';

import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

class _Repos {
  final players = PlayersRepository();
  final games = GamesRepository();
  final ratings = RatingRepository();
  final seasons = SeasonRepository();
  final percentiles = RolePercentilesRepository();

  SeasonLoaderService get loader =>
      SeasonLoaderService(players, games, ratings, seasons, percentiles);
}

void main() {
  // The web loads the remaining seasons one by one; mobile loads them in one
  // batch. Both must leave the repositories in exactly the same state.
  test('loading seasons one by one gives the same repositories as one batch',
      () async {
    final playersJson = File('assets/raw/players.json').readAsStringSync();
    const metas = [
      SeasonMeta(0, 17, 0.25),
      SeasonMeta(5, 50, 0.004),
      SeasonMeta(17, 60, 0.0),
      SeasonMeta(21, 60, 0.0),
    ];
    final jsons = [
      for (final m in metas)
        File('assets/raw/season${m.id}.json').readAsStringSync(),
    ];

    final batched = _Repos();
    await batched.loader.loadSeasons(
        metas: metas, playersJson: playersJson, seasonJsons: jsons);

    final oneByOne = _Repos();
    var yields = 0;
    await oneByOne.loader.loadSeasonsOneByOne(
      metas: metas,
      playersJson: playersJson,
      seasonJsons: jsons,
      yieldBetween: () async => yields++,
    );

    expect(yields, metas.length);
    expect(batched.games.state, isNotEmpty);
    expect(batched.ratings.state, hasLength(metas.length));
    expect(oneByOne.players.state, batched.players.state);
    expect(oneByOne.games.state, batched.games.state);
    expect(oneByOne.ratings.state.keys.toList(),
        batched.ratings.state.keys.toList());
    for (final id in batched.ratings.state.keys) {
      expect(oneByOne.ratings.state[id], batched.ratings.state[id],
          reason: 'ratings of season $id');
    }
    expect(oneByOne.seasons.state.keys.toList(),
        batched.seasons.state.keys.toList());
    for (final id in batched.seasons.state.keys) {
      final a = oneByOne.seasons.state[id]!;
      final b = batched.seasons.state[id]!;
      expect(a.playerStats, b.playerStats, reason: 'season $id playerStats');
      expect(a.mvpRanking, b.mvpRanking);
      expect(a.bestSheriffRanking, b.bestSheriffRanking);
      expect(a.bestDonRanking, b.bestDonRanking);
      expect(a.bestCivilianRanking, b.bestCivilianRanking);
      expect(a.bestMafiaRanking, b.bestMafiaRanking);
      expect(a.mostKilledRanking, b.mostKilledRanking);
    }
  });
}
