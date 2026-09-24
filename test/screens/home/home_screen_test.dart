import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/screens/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _season = SeasonConfig(
  id: 99,
  title: 'Test Season',
  gameLimit: 40,
  smallLeagueMinGames: 15,
  gamesMultiplier: 0.0,
  source: BundledSource(jsonFile: 'none.json'),
);

/// Players sitting on every boundary that matters, highest first (the order the
/// loader hands the screen). Below the band: 14. In the band: 15 and 39. Main
/// league: 40 (exactly the limit) and 41.
const _allGames = [41, 40, 39, 15, 14];

/// Only main-league players, so the small league comes out empty.
const _mainOnlyGames = [41, 40];

/// A player named after their game count, with the count as their id.
RatingPlayerStats _player(int games) => RatingPlayerStats(
      seasonId: _season.id,
      player: Player(id: games, displayName: 'p$games'),
      gamesPlayed: games,
      seasonGameLimit: _season.gameLimit,
    );

/// Award rankings hold main-league ids, exactly as the loader computes them
/// from players with `gamesPlayed >= gameLimit`.
SeasonStats _statsFor(List<int> gameCounts) => SeasonStats(
      playerStats: [for (final games in gameCounts) _player(games)],
      mvpRanking: const [41],
      bestSheriffRanking: const [41],
      bestDonRanking: const [40],
      bestCivilianRanking: const [40],
      bestMafiaRanking: const [41],
      mostKilledRanking: const [40],
    );

/// Pumps the real [HomeScreen] with the data graph faked out at the boundary:
/// the load future resolves immediately and the season repository is seeded.
Future<void> _pumpHome(
  WidgetTester tester, {
  List<int> gameCounts = _allGames,
  SeasonConfig? season = _season,
  int? gameLimitOverride,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialLoadProvider.overrideWith((ref) {}),
        loadingPhaseProvider.overrideWith((ref) => LoadingPhase.allLoaded),
        selectedSeasonProvider.overrideWith((ref) => season),
        loadedSeasonConfigsProvider.overrideWith(
          (ref) => season == null ? <SeasonConfig>[] : [season],
        ),
        gameLimitOverrideProvider.overrideWith((ref) => gameLimitOverride),
        seasonRepositoryProvider.overrideWith((ref) {
          final repo = SeasonRepository();
          if (season != null) repo.addSeason(season.id, _statsFor(gameCounts));
          return repo;
        }),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ),
  );
  await tester.pump();
}

Future<void> _selectSmallLeague(WidgetTester tester) async {
  await tester.tap(find.text('Мала'));
  await tester.pump();
}

/// The players currently rendered in the ratings list, by seeded game count.
List<int> _listedPlayers() =>
    [for (final games in _allGames) if (find.text('p$games').evaluate().isNotEmpty) games];

void main() {
  group('HomeScreen league toggle', () {
    testWidgets('the main league lists only players at or above the limit',
        (tester) async {
      await _pumpHome(tester);

      expect(find.text('Основна'), findsOneWidget);
      expect(_listedPlayers(), [41, 40]);
    });

    testWidgets('the small league lists the band and nothing above it',
        (tester) async {
      await _pumpHome(tester);
      await _selectSmallLeague(tester);

      // 15 and 39 are in [smallLeagueMinGames, gameLimit); 40 and 41 are not,
      // and 14 is below the band.
      expect(_listedPlayers(), [39, 15]);
    });

    testWidgets('tapping Мала changes which players are listed',
        (tester) async {
      await _pumpHome(tester);
      final before = _listedPlayers();

      await _selectSmallLeague(tester);
      final after = _listedPlayers();

      expect(after, isNot(before));
      expect(after.toSet().intersection(before.toSet()), isEmpty);
    });

    testWidgets('the toggle is not shown before a season resolves',
        (tester) async {
      await _pumpHome(tester, season: null);

      expect(find.text('Select a season'), findsOneWidget);
      expect(find.text('Основна'), findsNothing);
      expect(find.text('Мала'), findsNothing);
    });
  });

  group('HomeScreen season awards', () {
    testWidgets('the awards card is shown for the main league',
        (tester) async {
      await _pumpHome(tester);

      expect(find.text('Season Awards'), findsOneWidget);
      // The MVP winner resolves to a real name, not an em-dash.
      expect(find.text('p41'), findsWidgets);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('the awards card is hidden in the small league',
        (tester) async {
      // Regression guard: the rankings hold main-league ids, so against a
      // small-league playerStats list every award would render an em-dash.
      await _pumpHome(tester);
      expect(find.text('Season Awards'), findsOneWidget);

      await _selectSmallLeague(tester);

      expect(find.text('Season Awards'), findsNothing);
      expect(find.text('—'), findsNothing);
    });
  });

  group('HomeScreen empty states', () {
    testWidgets('the small league names its band in Ukrainian',
        (tester) async {
      await _pumpHome(tester, gameCounts: _mainOnlyGames);
      await _selectSmallLeague(tester);

      expect(find.text('Немає гравців у діапазоні 15–39 ігор'), findsOneWidget);
    });

    testWidgets('the main league names the effective limit in Ukrainian',
        (tester) async {
      // The override, not the season's own gameLimit, is what the filter uses:
      // the message has to print the same number.
      await _pumpHome(tester, gameLimitOverride: 100);

      expect(_listedPlayers(), isEmpty);
      expect(
        find.text('Немає гравців, які зіграли щонайменше 100 ігор'),
        findsOneWidget,
      );
      expect(find.text('No players meet this game limit'), findsNothing);
    });
  });
}
