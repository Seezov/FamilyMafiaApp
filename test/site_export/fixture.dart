import 'dart:io';

import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/role_percentiles_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const kFixtureTournament = Tournament(
  seasonId: 21,
  type: TournamentType.minicap,
  name: 'Fixture cup',
  games: 3,
);

/// Real bundled seasons loaded through [SeasonLoaderService] into a container,
/// the way `loadSiteContainer` ends up — without assets or a snapshot.
Future<ProviderContainer> fixtureContainer(
    {List<int> seasonIds = const [17, 21]}) async {
  final players = PlayersRepository();
  final games = GamesRepository();
  final ratings = RatingRepository();
  final seasons = SeasonRepository();
  final percentiles = RolePercentilesRepository();
  final loader =
      SeasonLoaderService(players, games, ratings, seasons, percentiles);

  final configs = Season.allConfigs()
      .where((c) => seasonIds.contains(c.id))
      .toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  await loader.loadSeasons(
    metas: [
      for (final c in configs) seasonMetaFor(c, DateTime.now())
    ],
    playersJson: File('assets/raw/players.json').readAsStringSync(),
    seasonJsons: [
      for (final c in configs)
        File('assets/raw/season${c.id}.json').readAsStringSync()
    ],
  );
  await loader.recomputePercentiles(
      players: players.state, games: games.state);

  final container = ProviderContainer(overrides: [
    playersRepositoryProvider.overrideWith((ref) => players),
    gamesRepositoryProvider.overrideWith((ref) => games),
    ratingRepositoryProvider.overrideWith((ref) => ratings),
    seasonRepositoryProvider.overrideWith((ref) => seasons),
    rolePercentilesRepositoryProvider.overrideWith((ref) => percentiles),
    tournamentsProvider.overrideWithValue(const [kFixtureTournament]),
  ]);
  container.read(loadedSeasonConfigsProvider.notifier).state =
      loader.applyThresholds(configs);
  addTearDown(container.dispose);
  return container;
}
