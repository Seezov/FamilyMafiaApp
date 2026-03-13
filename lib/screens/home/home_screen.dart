import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);

    return dataState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading data: $e')),
      ),
      data: (_) => const _HomeContent(),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedSeason = ref.watch(selectedSeasonProvider);
    final seasonStats = ref.watch(currentSeasonStatsProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Season selector row (newest → oldest)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: Season.values.reversed.map((season) {
                  final isSelected = season == selectedSeason;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonal(
                      onPressed: () => ref
                          .read(selectedSeasonProvider.notifier)
                          .state = season,
                      style: isSelected
                          ? FilledButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onPrimary,
                            )
                          : null,
                      child: Text(season.title),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Content area
            Expanded(
              child: seasonStats == null
                  ? const Center(child: Text('Select a season'))
                  : _SeasonView(
                      season: selectedSeason!,
                      stats: seasonStats,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonView extends StatelessWidget {
  final Season season;
  final SeasonStats stats;

  const _SeasonView({required this.season, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          season.title,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        _StatsView(stats: stats),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: stats.playerStats.length,
            itemBuilder: (context, index) => _PlayerStatsItem(
              rating: stats.playerStats[index],
              rank: index + 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsView extends StatelessWidget {
  final SeasonStats stats;

  const _StatsView({required this.stats});

  String _name(int playerId) =>
      stats.playerStats
          .firstWhere(
            (p) => p.player.id == playerId,
            orElse: () => stats.playerStats.first,
          )
          .player
          .displayName;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.titleSmall;
    final medium = Theme.of(context).textTheme.titleMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('MVP: ${_name(stats.mvpPlayerId)}', style: medium),
              const SizedBox(width: 16),
              Text('Most Killed: ${_name(stats.mostKilledPlayerId)}',
                  style: medium),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Best Sheriff: ${_name(stats.bestSheriffPlayerId)}',
                  style: small),
              const SizedBox(width: 8),
              Text('Best Don: ${_name(stats.bestDonPlayerId)}', style: small),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Best Civilian: ${_name(stats.bestCivilianPlayerId)}',
                  style: small),
              const SizedBox(width: 8),
              Text('Best Mafia: ${_name(stats.bestMafiaPlayerId)}',
                  style: small),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerStatsItem extends StatelessWidget {
  final RatingPlayerStats rating;
  final int rank;

  const _PlayerStatsItem({required this.rating, required this.rank});

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodySmall;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name + rank + rating
            Row(
              children: [
                Text(
                  '#$rank  ${rating.player.displayName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${rating.ratingCoefficient}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              'Wins: ${rating.wins}/${rating.gamesPlayed} games'
              ' (${(rating.winRate * 100).roundTo(2)}% WR)',
              style: body,
            ),
            Text(
              'Add. Points: ${rating.additionalPoints.roundTo(2)}'
              '  |  Penalty: ${rating.penaltyPoints.roundTo(2)}',
              style: body,
            ),
            Text(
              'Best Move Points: ${rating.bestMovePoints.roundTo(2)}',
              style: body,
            ),
            Text('MVP: ${rating.mvp.roundTo(4)}', style: body),
            Text(
              'First Killed: ${rating.firstKilled}'
              ' (City Lost: ${rating.firstKilledCityLost})',
              style: body,
            ),
            Text(
              'Death %: ${(rating.percentOfDeath * 100).roundTo(2)}%',
              style: body,
            ),
            Text(
              'CI/Game: ${rating.ciForGame.roundTo(3)}'
              '  |  CI: ${rating.ci.roundTo(3)}',
              style: body,
            ),

            const SizedBox(height: 6),

            // Per-role breakdown
            ...Role.values.map((role) {
              final roleName =
                  role.name[0].toUpperCase() + role.name.substring(1);
              final wins = rating.winByRole
                  .firstWhere((e) => role.sheetValues.contains(e.$1),
                      orElse: () => (role.sheetValue, 0))
                  .$2;
              final games = rating.gamesForRole
                  .firstWhere((e) => role.sheetValues.contains(e.$1),
                      orElse: () => (role.sheetValue, 0))
                  .$2;
              final add = rating.bestMoveAndAdditionalPointsByRole
                  .firstWhere((e) => role.sheetValues.contains(e.$1),
                      orElse: () => (role.sheetValue, 0.0))
                  .$2;
              final wr = games > 0
                  ? (wins / games * 100).roundTo(2)
                  : 0.0;

              return Text(
                '$roleName: $wins/$games games, $wr% WR,'
                ' ${add.roundTo(2)} Add.Pts',
                style: body,
              );
            }),
          ],
        ),
      ),
    );
  }
}
