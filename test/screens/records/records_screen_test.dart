import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/screens/records/records_screen.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows MVP rows and switches category', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        recordsInputProvider.overrideWithValue(RecordsInput(
          ratings: {
            26: [RatingPlayerStats(seasonId: 26, player: const Player(id: 1, displayName: 'Braun'),
                gamesPlayed: 50, wins: 30, winRate: 0.6, additionalPoints: 20)],
          },
          configs: const [SeasonConfig(id: 26, title: 'S26', gameLimit: 40, smallLeagueMinGames: 15,
              gamesMultiplier: 0, source: BundledSource(jsonFile: 'x'))],
          games: const [],
          resolver: PlayerResolver(const []),
        )),
        winStreaksProvider.overrideWithValue(const []),
      ],
      child: const MaterialApp(home: RecordsScreen()),
    ));
    expect(find.text('Braun'), findsOneWidget);
    await t.tap(find.text('Games'));
    await t.pump();
    expect(find.text('Braun'), findsOneWidget);
    expect(find.text('50'), findsWidgets);

    await t.tap(find.text('Hosts'));
    await t.pump();
    expect(find.text('All hosts'), findsOneWidget);
  });
}
