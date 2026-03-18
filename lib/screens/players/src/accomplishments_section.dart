part of '../player_profile_screen.dart';

// ---------------------------------------------------------------------------
// Accomplishments section
// ---------------------------------------------------------------------------

class _AccomplishmentsSection extends StatelessWidget {
  final PlayerAccomplishments acc;
  final bool isFullyLoaded;

  const _AccomplishmentsSection({required this.acc, required this.isFullyLoaded});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final badges = <Widget>[
      if (acc.firsts > 0)
        _AccBadge(label: '1st', count: acc.firsts, color: const Color(0xFFFFD700), icon: Icons.emoji_events),
      if (acc.seconds > 0)
        _AccBadge(label: '2nd', count: acc.seconds, color: const Color(0xFFB0BEC5), icon: Icons.emoji_events),
      if (acc.thirds > 0)
        _AccBadge(label: '3rd', count: acc.thirds, color: const Color(0xFFBF8970), icon: Icons.emoji_events),
      if (acc.mvp > 0)
        _AccBadge(label: 'MVP', count: acc.mvp, color: cs.primary, icon: Icons.star),
      if (acc.bestSheriff > 0)
        _AccBadge(label: 'Sheriff', count: acc.bestSheriff, color: Colors.blue.shade600, icon: Icons.local_police),
      if (acc.bestDon > 0)
        _AccBadge(label: 'Don', count: acc.bestDon, color: Colors.red.shade700, icon: Icons.gps_fixed),
      if (acc.bestCivilian > 0)
        _AccBadge(label: 'Civilian', count: acc.bestCivilian, color: Colors.green.shade600, icon: Icons.person),
      if (acc.bestMafia > 0)
        _AccBadge(label: 'Mafia', count: acc.bestMafia, color: Colors.deepPurple.shade400, icon: Icons.thumb_down),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Accomplishments', style: tt.titleMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${acc.sumOfNominations()}',
                style: tt.labelMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!isFullyLoaded) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (badges.isNotEmpty)
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: badges,
          )
        else if (!isFullyLoaded)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Loading all seasons\u2026',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _AccBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _AccBadge({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: tt.titleMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
