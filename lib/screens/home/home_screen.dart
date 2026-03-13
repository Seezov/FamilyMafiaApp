import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'dart:ui' show ImageFilter;

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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.82),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _SeasonChips(selectedSeason: selectedSeason),
            ),
          ),
          if (seasonStats != null && selectedSeason != null) ...[
            SliverToBoxAdapter(
              child: _SeasonHeaderCard(
                season: selectedSeason,
                stats: seasonStats,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _PlayerCard(
                  rating: seasonStats.playerStats[index],
                  rank: index + 1,
                ),
                childCount: seasonStats.playerStats.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ] else
            const SliverFillRemaining(
              child: Center(child: Text('Select a season')),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Season chip selector
// ---------------------------------------------------------------------------

class _SeasonChips extends ConsumerWidget {
  final Season? selectedSeason;

  const _SeasonChips({required this.selectedSeason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: Season.values.reversed.map((season) {
          final isSelected = season == selectedSeason;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(season.title),
              selected: isSelected,
              onSelected: (_) =>
                  ref.read(selectedSeasonProvider.notifier).state = season,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Season header card (title + award badges)
// ---------------------------------------------------------------------------

class _SeasonHeaderCard extends StatelessWidget {
  final Season season;
  final SeasonStats stats;

  const _SeasonHeaderCard({required this.season, required this.stats});

  String _name(int playerId) => stats.playerStats
      .firstWhere(
        (p) => p.player.id == playerId,
        orElse: () => stats.playerStats.first,
      )
      .player
      .displayName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      elevation: 0,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              season.title,
              style: tt.headlineSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AwardBadge(
                  icon: Icons.star,
                  label: 'MVP',
                  value: _name(stats.mvpPlayerId),
                  color: cs.onPrimaryContainer,
                ),
                _AwardBadge(
                  icon: Icons.local_police,
                  label: 'Sheriff',
                  value: _name(stats.bestSheriffPlayerId),
                  color: cs.onPrimaryContainer,
                ),
                _AwardBadge(
                  icon: Icons.person,
                  label: 'Civilian',
                  value: _name(stats.bestCivilianPlayerId),
                  color: cs.onPrimaryContainer,
                ),
                _AwardBadge(
                  icon: Icons.thumb_down,
                  label: 'Mafia',
                  value: _name(stats.bestMafiaPlayerId),
                  color: cs.onPrimaryContainer,
                ),
                _AwardBadge(
                  icon: Icons.gps_fixed,
                  label: 'Don',
                  value: _name(stats.bestDonPlayerId),
                  color: cs.onPrimaryContainer,
                ),
                _AwardBadge(
                  icon: Icons.close,
                  label: 'Most Killed',
                  value: _name(stats.mostKilledPlayerId),
                  color: cs.onPrimaryContainer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AwardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _AwardBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label  ',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color.withAlpha(180), fontWeight: FontWeight.w400),
          ),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Player card (compact, expandable)
// ---------------------------------------------------------------------------

class _PlayerCard extends StatefulWidget {
  final RatingPlayerStats rating;
  final int rank;

  const _PlayerCard({required this.rating, required this.rank});

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rating = widget.rating;
    final rank = widget.rank;

    final (rankBg, rankFg) = switch (rank) {
      1 => (const Color(0xFFFFD700), Colors.black87),
      2 => (const Color(0xFFB0BEC5), Colors.black87),
      3 => (const Color(0xFFBF8970), Colors.white),
      _ => (cs.surfaceContainerHighest, cs.onSurfaceVariant),
    };

    final winRatePct = rating.winRate * 100;
    final (wrFg, wrBg) = winRatePct >= 50
        ? (Colors.green.shade700, Colors.green.shade50)
        : winRatePct >= 35
            ? (Colors.amber.shade800, Colors.amber.shade50)
            : (Colors.red.shade700, Colors.red.shade50);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              // Collapsed header row
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: rankBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$rank',
                      style: tt.labelMedium?.copyWith(
                        color: rankFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      rating.player.displayName,
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  // Win-rate pill
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: wrBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${winRatePct.roundTo(1)}%',
                      style: tt.labelSmall?.copyWith(
                        color: wrFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Rating coefficient
                  Text(
                    rating.ratingCoefficient.roundTo(2).toString(),
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
              // Expanded details
              if (_expanded) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _ExpandedStats(rating: rating),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expanded stats section
// ---------------------------------------------------------------------------

class _ExpandedStats extends StatelessWidget {
  final RatingPlayerStats rating;

  const _ExpandedStats({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGrid(cells: [
          _StatCell(
              label: 'Games',
              value: '${rating.wins}/${rating.gamesPlayed}'),
          _StatCell(
              label: 'Add. Pts',
              value: rating.additionalPoints.roundTo(2).toString()),
          _StatCell(
              label: 'Penalty',
              value: rating.penaltyPoints.roundTo(2).toString()),
          _StatCell(
              label: 'Best Move',
              value: rating.bestMovePoints.roundTo(2).toString()),
        ]),
        const SizedBox(height: 8),
        _StatGrid(cells: [
          _StatCell(label: 'MVP', value: rating.mvp.roundTo(4).toString()),
          _StatCell(
              label: 'CI/Game',
              value: rating.ciForGame.roundTo(3).toString()),
          _StatCell(label: 'CI', value: rating.ci.roundTo(3).toString()),
          _StatCell(
              label: 'Death %',
              value:
                  '${(rating.percentOfDeath * 100).roundTo(1)}%'),
        ]),
        const SizedBox(height: 8),
        _StatGrid(cells: [
          _StatCell(label: 'First Killed', value: '${rating.firstKilled}'),
          _StatCell(
              label: 'City Lost',
              value: '${rating.firstKilledCityLost}'),
        ]),
        const SizedBox(height: 12),
        _RoleBreakdown(rating: rating),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<_StatCell> cells;

  const _StatGrid({required this.cells});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: cells.map((c) => Expanded(child: c)).toList(),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        Text(value,
            style:
                tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _RoleBreakdown extends StatelessWidget {
  final RatingPlayerStats rating;

  const _RoleBreakdown({required this.rating});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'By role',
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
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
          final wr = games > 0 ? (wins / games * 100).roundTo(1) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 68,
                  child: Text(roleName,
                      style: tt.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ),
                Text('$wins/$games',
                    style: tt.bodySmall),
                const SizedBox(width: 6),
                Text(
                  '$wr% WR',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 6),
                Text(
                  '+${add.roundTo(2)}',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.primary),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
