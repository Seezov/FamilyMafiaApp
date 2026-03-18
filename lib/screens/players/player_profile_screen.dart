import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/best_moves.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/screens/players/season_chart_painter.dart';
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
    final isFullyLoaded = phase == LoadingPhase.allLoaded;

    return Scaffold(
      appBar: AppBar(title: Text(player.displayName)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: _avatarColor(player.displayName),
                      child: Text(
                        _initials(player.displayName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      player.displayName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total games played',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    if (acc.sumOfNominations() > 0 || !isFullyLoaded) ...[
                      _AccomplishmentsSection(acc: acc, isFullyLoaded: isFullyLoaded),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      'Games per season',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              _SeasonChart(gamesBySeason: gamesBySeason),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (roleGames.isNotEmpty) ...[
                      _RoleDistributionSection(roleGames: roleGames, roleWins: roleWins, rolePercentiles: rolePercentiles),
                      const SizedBox(height: 24),
                    ],
                    if (firstKill.total > 0) ...[
                      _FirstKillSection(
                        total: firstKill.total,
                        cityLost: firstKill.cityLost,
                        totalGames: firstKill.civSherGames,
                      ),
                      const SizedBox(height: 24),
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
            ],
          ),
        ),
      ),
    );
  }
}
