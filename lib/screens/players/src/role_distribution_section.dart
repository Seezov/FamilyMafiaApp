part of '../player_profile_screen.dart';

// ---------------------------------------------------------------------------
// Role Distribution
// ---------------------------------------------------------------------------

class _RoleDistributionSection extends StatelessWidget {
  final Map<String, int> roleGames;
  final Map<String, int> roleWins;
  final Map<Role, double?> rolePercentiles;

  const _RoleDistributionSection({
    required this.roleGames,
    required this.roleWins,
    required this.rolePercentiles,
  });

  static const _order = [Role.civilian, Role.mafia, Role.sheriff, Role.don];

  static Color _roleColor(Role role) => switch (role) {
        Role.civilian => const Color(0xFFE53935),
        Role.mafia => const Color(0xFF616161),
        Role.sheriff => const Color(0xFF00BCD4),
        Role.don => const Color(0xFF212121),
      };

  static String _roleName(Role role) => switch (role) {
        Role.civilian => 'Civilian',
        Role.mafia => 'Mafia',
        Role.sheriff => 'Sheriff',
        Role.don => 'Don',
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    final summary = <Role, int>{};
    for (final entry in roleGames.entries) {
      final role = Role.findByValue(entry.key);
      if (role != null) summary[role] = (summary[role] ?? 0) + entry.value;
    }
    if (summary.isEmpty) return const SizedBox.shrink();

    final wins = <Role, int>{};
    for (final entry in roleWins.entries) {
      final role = Role.findByValue(entry.key);
      if (role != null) wins[role] = (wins[role] ?? 0) + entry.value;
    }

    final total = summary.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Role Distribution', style: tt.titleMedium),
        const SizedBox(height: 12),
        for (final role in _order)
          if ((summary[role] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RoleBar(
                label: _roleName(role),
                count: summary[role]!,
                wins: wins[role] ?? 0,
                total: total,
                color: _roleColor(role),
                topPct: rolePercentiles[role],
              ),
            ),
      ],
    );
  }
}

class _RoleBar extends ConsumerWidget {
  final String label;
  final int count;
  final int wins;
  final int total;
  final Color color;
  final double? topPct;

  const _RoleBar({
    required this.label,
    required this.count,
    required this.wins,
    required this.total,
    required this.color,
    this.topPct,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final phase = ref.watch(loadingPhaseProvider);
    final pct = total > 0 ? (count / total * 100).round() : 0;
    final winPct = count > 0 ? (wins / count * 100).round() : 0;

    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: LayoutBuilder(builder: (ctx, constraints) {
            final barW =
                total > 0 ? constraints.maxWidth * count / total : 0.0;
            return Stack(children: [
              Container(
                height: 20,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                height: 20,
                width: barW,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ]);
          }),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$count ($pct%)',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '$winPct% WR',
                style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              ),
              if (topPct != null)
                Text(
                  'Top ${topPct! < 1 ? topPct!.toStringAsFixed(1) : topPct!.toInt()}%',
                  style: tt.bodySmall?.copyWith(
                      color: const Color(0xFF66BB6A),
                      fontWeight: FontWeight.w600),
                )
              else if (phase != LoadingPhase.allLoaded)
                SkeletonShimmer.text(width: 48, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
