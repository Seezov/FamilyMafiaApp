part of '../home_screen.dart';

class _SeasonHeaderCard extends StatelessWidget {
  final SeasonConfig season;
  final SeasonStats stats;

  const _SeasonHeaderCard({required this.season, required this.stats});

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
