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

    List<Widget> podium(int first, int second, int third, String suffix) => [
          if (first > 0)
            _AccBadge(
              label: '1st$suffix',
              count: first,
              bgColor: _gold.light,
              borderColor: _gold.color.withValues(alpha: 0.3),
              iconColor: _gold.icon,
              icon: Icons.emoji_events,
            ),
          if (second > 0)
            _AccBadge(
              label: '2nd$suffix',
              count: second,
              bgColor: _silver.light,
              borderColor: _silver.color.withValues(alpha: 0.3),
              iconColor: _silver.icon,
              icon: Icons.emoji_events,
            ),
          if (third > 0)
            _AccBadge(
              label: '3rd$suffix',
              count: third,
              bgColor: _bronze.light,
              borderColor: _bronze.color.withValues(alpha: 0.3),
              iconColor: _bronze.icon,
              icon: Icons.emoji_events,
            ),
        ];

    final mainLeague = podium(acc.firsts, acc.seconds, acc.thirds, '');
    final smallLeague =
        podium(acc.smallFirsts, acc.smallSeconds, acc.smallThirds, '');

    final awards = <Widget>[
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

    final tournaments = <Widget>[
      for (final t in TournamentType.values)
        if (acc.tournamentPodiums(t) > 0)
          _AccBadge(
            label: t.label,
            count: acc.tournamentPodiums(t),
            bgColor: t.lightColor,
            borderColor: t.color.withValues(alpha: 0.3),
            iconColor: t.color,
            icon: Icons.military_tech,
            places: acc.tournamentPlaces[t],
          ),
    ];

    final groups = <(String, List<Widget>)>[
      ('Main league', mainLeague),
      ('Small league', smallLeague),
      ('Season awards', awards),
      ('Tournament prize places', tournaments),
    ].where((g) => g.$2.isNotEmpty).toList();

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
      child: groups.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (title, badges)) in groups.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Text(
                    title,
                    style: tt.labelMedium?.copyWith(
                      color: const Color(0x99000000),
                    ),
                  ),
                  const SizedBox(height: 6),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.9,
                    children: badges,
                  ),
                ],
              ],
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

  /// `[1st, 2nd, 3rd]` breakdown shown under the label, for tournaments.
  final List<int>? places;

  const _AccBadge({
    required this.label,
    required this.count,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
    required this.icon,
    this.places,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(
              color: const Color(0x99000000),
            ),
          ),
          if (places case final p?)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (i, medal) in [_gold, _silver, _bronze].indexed)
                  if (p[i] > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        '${p[i]}',
                        style: tt.labelSmall?.copyWith(
                          color: medal.icon,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

typedef _Medal = ({Color light, Color color, Color icon});

const _Medal _gold =
    (light: Color(0xFFFFF8E1), color: Color(0xFFFFC107), icon: Color(0xFFF9A825));
const _Medal _silver =
    (light: Color(0xFFECEFF1), color: Color(0xFFB0BEC5), icon: Color(0xFF78909C));
const _Medal _bronze =
    (light: Color(0xFFEFEBE9), color: Color(0xFFBF8970), icon: Color(0xFFBF8970));
