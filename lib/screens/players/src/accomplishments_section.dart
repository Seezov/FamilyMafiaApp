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
    final tt = Theme.of(context).textTheme;

    final badges = <Widget>[
      if (acc.firsts > 0)
        _AccBadge(
          label: '1st',
          count: acc.firsts,
          bgColor: const Color(0xFFFFF8E1),
          borderColor: const Color(0xFFFFC107).withValues(alpha: 0.3),
          iconColor: const Color(0xFFF9A825),
          icon: Icons.emoji_events,
        ),
      if (acc.seconds > 0)
        _AccBadge(
          label: '2nd',
          count: acc.seconds,
          bgColor: const Color(0xFFECEFF1),
          borderColor: const Color(0xFFB0BEC5).withValues(alpha: 0.3),
          iconColor: const Color(0xFF78909C),
          icon: Icons.emoji_events,
        ),
      if (acc.thirds > 0)
        _AccBadge(
          label: '3rd',
          count: acc.thirds,
          bgColor: const Color(0xFFEFEBE9),
          borderColor: const Color(0xFFBF8970).withValues(alpha: 0.3),
          iconColor: const Color(0xFFBF8970),
          icon: Icons.emoji_events,
        ),
      if (acc.mvp > 0)
        _AccBadge(
          label: 'MVP',
          count: acc.mvp,
          bgColor: const Color(0xFFFFEBEE),
          borderColor: const Color(0xFFE53935).withValues(alpha: 0.2),
          iconColor: const Color(0xFFE53935),
          icon: Icons.star,
        ),
      if (acc.bestSheriff > 0)
        _AccBadge(
          label: 'Sheriff',
          count: acc.bestSheriff,
          bgColor: Role.sheriff.lightColor,
          borderColor: Role.sheriff.color.withValues(alpha: 0.3),
          iconColor: Role.sheriff.color,
          icon: Icons.local_police,
        ),
      if (acc.bestDon > 0)
        _AccBadge(
          label: 'Don',
          count: acc.bestDon,
          bgColor: Role.don.lightColor,
          borderColor: Role.don.color.withValues(alpha: 0.3),
          iconColor: Role.don.color,
          icon: Icons.gps_fixed,
        ),
      if (acc.bestCivilian > 0)
        _AccBadge(
          label: 'Civilian',
          count: acc.bestCivilian,
          bgColor: Role.civilian.lightColor,
          borderColor: Role.civilian.color.withValues(alpha: 0.3),
          iconColor: Role.civilian.color,
          icon: Icons.person,
        ),
      if (acc.bestMafia > 0)
        _AccBadge(
          label: 'Mafia',
          count: acc.bestMafia,
          bgColor: Role.mafia.lightColor,
          borderColor: Role.mafia.color.withValues(alpha: 0.3),
          iconColor: Role.mafia.color,
          icon: Icons.thumb_down,
        ),
    ];

    final trailing = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${acc.sumOfNominations()}',
            style: tt.labelMedium?.copyWith(
              color: const Color(0xFFE53935),
              fontWeight: FontWeight.bold,
            ),
          ),
          if (!isFullyLoaded) ...[
            const SizedBox(width: 4),
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Color(0xFFE53935),
              ),
            ),
          ],
        ],
      ),
    );

    return SectionCard(
      title: 'Accomplishments',
      trailing: trailing,
      child: badges.isNotEmpty
          ? GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
              children: badges,
            )
          : Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Loading all seasons\u2026',
                style: tt.bodySmall?.copyWith(
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ),
    );
  }
}

class _AccBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  final IconData icon;

  const _AccBadge({
    required this.label,
    required this.count,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: tt.titleMedium?.copyWith(
              color: const Color(0xDD000000),
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: const Color(0x99000000),
            ),
          ),
        ],
      ),
    );
  }
}
