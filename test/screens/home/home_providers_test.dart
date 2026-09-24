import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _season = SeasonConfig(
  id: 99,
  title: 'Test Season',
  gameLimit: 40,
  gamesMultiplier: 0.0,
  smallLeagueMinGames: 15,
  source: BundledSource(jsonFile: 'none.json'),
);

/// Players sitting on every boundary that matters.
const _gameCounts = [14, 15, 39, 40, 41];

SeasonStats _statsFor(List<int> gameCounts) => SeasonStats(
      playerStats: [
        for (final (index, games) in gameCounts.indexed)
          RatingPlayerStats(
            seasonId: _season.id,
            player: Player(id: index, displayName: 'p$games'),
            gamesPlayed: games,
          ),
      ],
      mvpRanking: const [],
      bestSheriffRanking: const [],
      bestDonRanking: const [],
      bestCivilianRanking: const [],
      bestMafiaRanking: const [],
      mostKilledRanking: const [],
    );

ProviderContainer _containerWith(List<int> gameCounts) {
  final container = ProviderContainer(
    overrides: [
      seasonRepositoryProvider.overrideWith(
        (ref) => SeasonRepository()..addSeason(_season.id, _statsFor(gameCounts)),
      ),
    ],
  );
  // Listeners only run once the provider is alive.
  container.read(leagueOverrideResetProvider);
  container.read(selectedSeasonProvider.notifier).state = _season;
  addTearDown(container.dispose);
  return container;
}

List<int> _gamesIn(ProviderContainer c) =>
    (c.read(currentSeasonStatsProvider)?.playerStats ?? [])
        .map((p) => p.gamesPlayed)
        .toList();

void main() {
  group('currentSeasonStatsProvider league filtering', () {
    test('main league keeps gamesPlayed >= gameLimit (unchanged)', () {
      final c = _containerWith(_gameCounts);
      expect(c.read(selectedLeagueProvider), League.main);
      expect(_gamesIn(c), [40, 41]);
    });

    test('small league keeps min <= gamesPlayed < gameLimit', () {
      final c = _containerWith(_gameCounts);
      c.read(selectedLeagueProvider.notifier).state = League.small;
      expect(_gamesIn(c), [15, 39]);
    });

    test('a player with exactly gameLimit games is main league only', () {
      final c = _containerWith([40]);
      expect(_gamesIn(c), [40]);

      c.read(selectedLeagueProvider.notifier).state = League.small;
      expect(_gamesIn(c), isEmpty);
    });

    test('the leagues never overlap', () {
      final c = _containerWith(_gameCounts);
      final main = _gamesIn(c).toSet();
      c.read(selectedLeagueProvider.notifier).state = League.small;
      final small = _gamesIn(c).toSet();

      expect(main.intersection(small), isEmpty);
    });

    test('selecting the small league clears the game limit override', () {
      final c = _containerWith(_gameCounts);
      c.read(gameLimitOverrideProvider.notifier).state = 20;

      c.read(selectedLeagueProvider.notifier).state = League.small;

      expect(c.read(gameLimitOverrideProvider), isNull);
    });
  });
}
