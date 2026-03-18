part of '../player_profile_screen.dart';

// ---------------------------------------------------------------------------
// First Kill
// ---------------------------------------------------------------------------

class _FirstKillSection extends StatelessWidget {
  final int total;
  final int cityLost;
  final int totalGames;

  const _FirstKillSection({
    required this.total,
    required this.cityLost,
    required this.totalGames,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cityLostPct = total > 0 ? (cityLost / total * 100).round() : 0;
    final firstKillPct =
        totalGames > 0 ? (total / totalGames * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('First Kill', style: tt.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _StatCard(
              value: '$total',
              label: 'first-killed',
              sub: '$firstKillPct% of games',
              color: const Color(0xFFFB8C00),
              icon: Icons.flash_on,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatCard(
              value: '$cityLost',
              label: 'city lost',
              sub: '$cityLostPct% of first kills',
              color: const Color(0xFFE53935),
              icon: Icons.trending_down,
            ),
          ),
        ]),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final String sub;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(value,
              style: tt.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(sub,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
