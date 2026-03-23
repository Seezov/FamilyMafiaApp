part of '../home_screen.dart';

class _SeasonHeroCard extends ConsumerWidget {
  final SeasonConfig season;

  const _SeasonHeroCard({required this.season});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(seasonSummaryProvider);
    if (summary == null) return const SizedBox.shrink();

    final cityWRStr = '${(summary.cityWR * 100).toStringAsFixed(0)}%';
    final mafiaWRStr = '${(summary.mafiaWR * 100).toStringAsFixed(0)}%';

    return HeroCard(
      gradientStart: const Color(0xFFE53935),
      gradientEnd: const Color(0xFFB71C1C),
      label: season.title,
      title: 'Season Summary',
      statTiles: [
        HeroStatTile(value: '${summary.games}', label: 'Games'),
        HeroStatTile(value: '${summary.players}', label: 'Players'),
        HeroStatTile(value: cityWRStr, label: 'City WR'),
        HeroStatTile(value: mafiaWRStr, label: 'Mafia WR'),
      ],
    );
  }
}

class _SeasonAwardsCard extends StatelessWidget {
  final SeasonStats stats;

  const _SeasonAwardsCard({required this.stats});

  String _name(int playerId) {
    if (playerId == -1 || stats.playerStats.isEmpty) return '—';
    return stats.playerStats
        .firstWhere(
          (p) => p.player.id == playerId,
          orElse: () => stats.playerStats.first,
        )
        .player
        .displayName;
  }

  @override
  Widget build(BuildContext context) {
    final awards = [
      _AwardConfig(
        icon: Icons.star,
        label: 'MVP',
        iconColor: const Color(0xFFF9A825),
        bgColor: const Color(0xFFFFF8E1),
        winner: _name(stats.mvpPlayerId),
      ),
      _AwardConfig(
        icon: Icons.local_police,
        label: 'Sheriff',
        iconColor: const Color(0xFF00BCD4),
        bgColor: const Color(0xFFE0F7FA),
        winner: _name(stats.bestSheriffPlayerId),
      ),
      _AwardConfig(
        icon: Icons.person,
        label: 'Civilian',
        iconColor: const Color(0xFFE53935),
        bgColor: const Color(0xFFFFEBEE),
        winner: _name(stats.bestCivilianPlayerId),
      ),
      _AwardConfig(
        icon: Icons.theater_comedy,
        label: 'Mafia',
        iconColor: const Color(0xFF616161),
        bgColor: const Color(0xFFF5F5F5),
        winner: _name(stats.bestMafiaPlayerId),
      ),
      _AwardConfig(
        icon: Icons.gps_fixed,
        label: 'Don',
        iconColor: const Color(0xFF212121),
        bgColor: const Color(0xFFEEEEEE),
        winner: _name(stats.bestDonPlayerId),
      ),
      _AwardConfig(
        icon: Icons.close,
        label: 'Most Killed',
        iconColor: const Color(0xFFFF9800),
        bgColor: const Color(0xFFFFF3E0),
        winner: _name(stats.mostKilledPlayerId),
      ),
    ];

    return SectionCard(
      title: 'Season Awards',
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 3.2,
        children: awards.map((a) => _AwardBadge(config: a)).toList(),
      ),
    );
  }
}

class _AwardConfig {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final String winner;

  const _AwardConfig({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.winner,
  });
}

class _AwardBadge extends StatelessWidget {
  final _AwardConfig config;

  const _AwardBadge({required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: config.bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(config.icon, size: 18, color: config.iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  config.label,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  config.winner,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xDD000000),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
