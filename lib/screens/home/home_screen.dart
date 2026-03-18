import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'src/loading_indicator.dart';
part 'src/background_loading_banner.dart';
part 'src/season_chips.dart';
part 'src/game_limit_picker.dart';
part 'src/season_header_card.dart';
part 'src/player_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(initialLoadProvider);

    return dataState.when(
      loading: () => const Scaffold(
        body: Center(child: _LoadingDots()),
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
    final hasQualifying = ref.watch(hasQualifyingPlayersProvider);
    final effectiveLimit = ref.watch(effectiveGameLimitProvider);
    final phase = ref.watch(loadingPhaseProvider);
    final isBackgroundLoading = phase != LoadingPhase.allLoaded;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final season = ref.read(selectedSeasonProvider);
          if (season == null) return;
          await refreshSeason(ref, season);
        },
        child: CustomScrollView(
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
          if (isBackgroundLoading)
            const SliverToBoxAdapter(
              child: _BackgroundLoadingBanner(),
            ),
          if (seasonStats != null && selectedSeason != null) ...[
            SliverToBoxAdapter(
              child: _SeasonHeaderCard(
                season: selectedSeason,
                stats: seasonStats,
              ),
            ),
            if (!hasQualifying)
              SliverToBoxAdapter(
                child: _GameLimitPicker(
                  currentLimit: effectiveLimit,
                  defaultLimit: selectedSeason.gameLimit,
                ),
              ),
            if (seasonStats.playerStats.isNotEmpty) ...[
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PlayerCard(
                    rating: seasonStats.playerStats[index],
                    rank: index + 1,
                  ),
                  childCount: seasonStats.playerStats.length,
                ),
              ),
            ] else
              const SliverFillRemaining(
                child: Center(child: Text('No players meet this game limit')),
              ),
            SliverToBoxAdapter(
              child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
            ),
          ] else
            const SliverFillRemaining(
              child: Center(child: Text('Select a season')),
            ),
        ],
      ),
      ),
    );
  }
}
