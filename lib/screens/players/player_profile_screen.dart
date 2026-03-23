import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/best_moves.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/screens/players/season_chart_painter.dart';
import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/skeleton_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'src/accomplishments_section.dart';
part 'src/season_chart.dart';
part 'src/player_utilities.dart';
part 'src/role_distribution_section.dart';
part 'src/first_kill_section.dart';
part 'src/best_moves_section.dart';

class PlayerProfileScreen extends ConsumerWidget {
  final Player player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(seasonGamesProvider);
    final acc = ref.watch(playerAccomplishmentsProvider(player));
    final roleGames = ref.watch(playerRoleGamesProvider(player));
    final roleWins = ref.watch(playerRoleWinsProvider(player));
    final rolePercentiles = ref.watch(roleWinRatePercentilesProvider(player));
    final firstKill = ref.watch(playerFirstKillProvider(player));
    final bestMoves = ref.watch(playerBestMovesProvider(player));
    final phase = ref.watch(loadingPhaseProvider);

    SeasonGamesEntry? entry;
    for (final e in entries) {
      if (e.name == player.displayName) {
        entry = e;
        break;
      }
    }

    // Determine max season id from loaded configs
    final loadedConfigs = ref.watch(loadedSeasonConfigsProvider);
    final maxSeasonId = loadedConfigs.isNotEmpty
        ? loadedConfigs.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1
        : 29;

    final gamesBySeason = List<int?>.generate(maxSeasonId, (i) {
      final match = entry?.seasonData.where((e) => e.seasonId == i);
      return (match == null || match.isEmpty) ? null : match.first.games;
    });

    final total = entry?.seasonData.fold(0, (s, e) => s + e.games) ?? 0;
    final seasonsCount = entry?.seasonData.length ?? 0;
    final isFullyLoaded = phase == LoadingPhase.allLoaded;

    // Compute overall win rate from playerStatsMap
    final statsMap = ref.watch(playerStatsMapProvider);
    final playerStats = statsMap[player.displayName];
    final winRate = playerStats != null && playerStats.games > 0
        ? playerStats.winRate
        : null;
    final winRateStr = winRate != null
        ? '${(winRate * 100).round()}%'
        : '—';

    // Latest season rating
    final latestRating = ref.watch(latestSeasonRatingProvider(player));
    final ratingStr = latestRating != null
        ? latestRating.toStringAsFixed(2)
        : '—';

    return Scaffold(
      appBar: AppBar(title: Text(player.displayName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Hero card — custom gradient layout with avatar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.transparent,
                              child: Text(
                                _initials(player.displayName),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  player.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$total games played',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: HeroStatTile(
                              value: winRateStr,
                              label: 'WIN RATE',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HeroStatTile(
                              value: ratingStr,
                              label: 'RATING',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: HeroStatTile(
                              value: '$seasonsCount',
                              label: 'SEASONS',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (acc.sumOfNominations() > 0 || !isFullyLoaded) ...[
                _AccomplishmentsSection(acc: acc, isFullyLoaded: isFullyLoaded),
                const SizedBox(height: 16),
              ],
              _SeasonChartSection(gamesBySeason: gamesBySeason),
              const SizedBox(height: 16),
              if (roleGames.isNotEmpty) ...[
                _RoleDistributionSection(roleGames: roleGames, roleWins: roleWins, rolePercentiles: rolePercentiles),
                const SizedBox(height: 16),
              ],
              if (firstKill.total > 0) ...[
                _FirstKillSection(
                  total: firstKill.total,
                  cityLost: firstKill.cityLost,
                  totalGames: firstKill.civSherGames,
                ),
                const SizedBox(height: 16),
              ],
              () {
                final bmTotal = bestMoves.zeroBlacks +
                    bestMoves.oneBlack +
                    bestMoves.twoBlacks +
                    bestMoves.threeBlacks;
                return bmTotal > 0
                    ? _BestMovesSection(bm: bestMoves)
                    : const SizedBox.shrink();
              }(),
            ],
          ),
        ),
      ),
    );
  }
}
