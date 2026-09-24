part of '../home_screen.dart';

typedef _RankingEntry = ({String name, String points, String detail});

class _SeasonHeroCard extends ConsumerWidget {
  final SeasonConfig season;

  const _SeasonHeroCard({required this.season});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(seasonSummaryProvider);
    if (summary == null) return const SizedBox.shrink();

    final cityWRStr = '${(summary.cityWR * 100).toStringAsFixed(0)}%';
    final mafiaWRStr = '${(summary.mafiaWR * 100).toStringAsFixed(0)}%';

    final leagues = ref.watch(seasonLeagueCountsProvider);
    final tournamentsCount = ref
        .watch(tournamentsProvider)
        .where((t) => t.seasonId == season.id)
        .length;

    return HeroCard(
      gradientStart: const Color(0xFF00897B),
      gradientEnd: const Color(0xFF004D40),
      label: season.title,
      title: 'Season Summary',
      statTiles: [
        HeroStatTile(value: '${summary.games}', label: 'Games'),
        HeroStatTile(value: '${summary.players}', label: 'Players'),
        HeroStatTile(value: cityWRStr, label: 'City WR'),
        HeroStatTile(value: mafiaWRStr, label: 'Mafia WR'),
      ],
      secondaryStatTiles: [
        HeroStatTile(value: '${leagues?.main ?? 0}', label: 'Main league'),
        HeroStatTile(value: '${leagues?.small ?? 0}', label: 'Small league'),
        HeroStatTile(value: '$tournamentsCount', label: 'Tournaments'),
      ],
    );
  }
}

class _SeasonAwardsCard extends StatefulWidget {
  final SeasonStats stats;

  const _SeasonAwardsCard({required this.stats});

  @override
  State<_SeasonAwardsCard> createState() => _SeasonAwardsCardState();
}

class _SeasonAwardsCardState extends State<_SeasonAwardsCard> {
  /// Label of the award whose ranking is open, or null when all are collapsed.
  String? _openAward;

  RatingPlayerStats? _statsFor(int playerId) {
    if (playerId == -1) return null;
    for (final p in widget.stats.playerStats) {
      if (p.player.id == playerId) return p;
    }
    return null;
  }

  String _winnerName(List<int> ranking) => ranking.isEmpty
      ? '—'
      : (_statsFor(ranking.first)?.player.displayName ?? '—');

  static String _roleDetail(RatingPlayerStats p, Role role) {
    final key = role.sheetValue;
    final games =
        p.gamesForRole.firstWhere((e) => e.$1 == key, orElse: () => (key, 0)).$2;
    final wins =
        p.winByRole.firstWhere((e) => e.$1 == key, orElse: () => (key, 0)).$2;
    if (games == 0) return '—';
    return '$wins/$games  ${(wins / games * 100).toStringAsFixed(1)}%';
  }

  /// Average points per game in [role]: (доп + ОП + штраф) / games in that role.
  /// This is the figure that orders players who are within the award's win-rate
  /// band of each other.
  static String _rolePoints(RatingPlayerStats p, Role role) {
    final key = role.sheetValue;
    final games =
        p.gamesForRole.firstWhere((e) => e.$1 == key, orElse: () => (key, 0)).$2;
    if (games == 0) return '—';
    final points = p.bestMoveAndAdditionalPointsByRole
        .firstWhere((e) => e.$1 == key, orElse: () => (key, 0.0))
        .$2;
    return _points(points / games);
  }

  /// Average additional points per game across the whole season.
  static String _seasonPoints(RatingPlayerStats p) => p.gamesPlayed == 0
      ? '—'
      : _points(p.additionalPoints / p.gamesPlayed);

  static String _points(double value) =>
      '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)}';

  List<_AwardConfig> get _awards => [
        _AwardConfig(
          icon: Icons.star,
          label: 'MVP',
          iconColor: const Color(0xFFF9A825),
          bgColor: const Color(0xFFFFF8E1),
          ranking: widget.stats.mvpRanking,
          metricLabel: 'Score',
          points: _seasonPoints,
          detail: (p) => p.mvp.toStringAsFixed(3),
        ),
        _AwardConfig(
          icon: Icons.local_police,
          label: 'Sheriff',
          iconColor: Role.sheriff.color,
          bgColor: Role.sheriff.lightColor,
          ranking: widget.stats.bestSheriffRanking,
          metricLabel: 'Record',
          points: (p) => _rolePoints(p, Role.sheriff),
          detail: (p) => _roleDetail(p, Role.sheriff),
        ),
        _AwardConfig(
          icon: Icons.person,
          label: 'Civilian',
          iconColor: Role.civilian.color,
          bgColor: Role.civilian.lightColor,
          ranking: widget.stats.bestCivilianRanking,
          metricLabel: 'Record',
          points: (p) => _rolePoints(p, Role.civilian),
          detail: (p) => _roleDetail(p, Role.civilian),
        ),
        _AwardConfig(
          icon: Icons.theater_comedy,
          label: 'Mafia',
          iconColor: Role.mafia.color,
          bgColor: Role.mafia.lightColor,
          ranking: widget.stats.bestMafiaRanking,
          metricLabel: 'Record',
          points: (p) => _rolePoints(p, Role.mafia),
          detail: (p) => _roleDetail(p, Role.mafia),
        ),
        _AwardConfig(
          icon: Icons.gps_fixed,
          label: 'Don',
          iconColor: Role.don.color,
          bgColor: Role.don.lightColor,
          ranking: widget.stats.bestDonRanking,
          metricLabel: 'Record',
          points: (p) => _rolePoints(p, Role.don),
          detail: (p) => _roleDetail(p, Role.don),
        ),
        _AwardConfig(
          icon: Icons.close,
          label: 'Most Killed',
          iconColor: const Color(0xFFFF9800),
          bgColor: const Color(0xFFFFF3E0),
          ranking: widget.stats.mostKilledRanking,
          metricLabel: 'Deaths',
          points: _seasonPoints,
          detail: (p) => '${p.firstKilled}',
        ),
      ];

  void _toggle(_AwardConfig award) {
    setState(() {
      _openAward = _openAward == award.label ? null : award.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final awards = _awards;
    final open = awards.where((a) => a.label == _openAward).firstOrNull;

    return SectionCard(
      title: 'Season Awards',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: awards
                .map((a) => _StatBadge(
                      icon: a.icon,
                      label: a.label,
                      iconColor: a.iconColor,
                      bgColor: a.bgColor,
                      winner: _winnerName(a.ranking),
                      isOpen: a.label == _openAward,
                      onTap: () => _toggle(a),
                    ))
                .toList(),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open == null
                ? const SizedBox(width: double.infinity, height: 0)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _StatRanking(
                      icon: open.icon,
                      label: open.label,
                      iconColor: open.iconColor,
                      bgColor: open.bgColor,
                      pointsLabel: 'Avg pts',
                      metricLabel: open.metricLabel,
                      emptyText: 'Nobody played enough games for this award.',
                      entries: [
                        for (final p in open.ranking
                            .map(_statsFor)
                            .whereType<RatingPlayerStats>())
                          (
                            name: p.player.displayName,
                            points: open.points(p),
                            detail: open.detail(p),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AwardConfig {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;

  /// Player ids, best first. Empty when nobody qualified for the award.
  final List<int> ranking;

  /// Header for the [detail] column.
  final String metricLabel;

  /// Average additional points per game earned towards this award.
  final String Function(RatingPlayerStats) points;

  /// The figure this award ranks by, shown at the end of each row.
  final String Function(RatingPlayerStats) detail;

  const _AwardConfig({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.ranking,
    required this.metricLabel,
    required this.points,
    required this.detail,
  });
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final String winner;
  final bool isOpen;
  final VoidCallback? onTap;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.winner,
    required this.isOpen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isOpen ? iconColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 9, color: Colors.grey),
                    ),
                    Text(
                      winner,
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
              if (onTap != null)
                AnimatedRotation(
                  turns: isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: iconColor.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The open stat's full ranking: winner first, then the runners-up.
class _StatRanking extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final String pointsLabel;
  final String metricLabel;
  final String emptyText;
  final List<_RankingEntry> entries;

  const _StatRanking({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.pointsLabel,
    required this.metricLabel,
    required this.emptyText,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptyText,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            )
          else ...[
            _RankingHeader(pointsLabel: pointsLabel, metricLabel: metricLabel),
            for (var i = 0; i < entries.length; i++)
              _RankingRow(
                rank: i + 1,
                name: entries[i].name,
                points: entries[i].points,
                detail: entries[i].detail,
                accent: iconColor,
              ),
          ],
        ],
      ),
    );
  }
}

/// Column headers for the ranking, so the two trailing figures are unambiguous.
class _RankingHeader extends StatelessWidget {
  final String pointsLabel;
  final String metricLabel;

  const _RankingHeader({required this.pointsLabel, required this.metricLabel});

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: Colors.grey,
    );
    return Padding(
      padding: const EdgeInsets.only(left: 28, bottom: 2),
      child: Row(
        children: [
          const Expanded(child: Text('Player', style: style)),
          SizedBox(
            width: _RankingRow.pointsWidth,
            child: Text(pointsLabel, style: style, textAlign: TextAlign.right),
          ),
          SizedBox(
            width: _RankingRow.detailWidth,
            child:
                Text(metricLabel, style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  static const pointsWidth = 52.0;
  static const detailWidth = 84.0;

  final int rank;
  final String name;
  final String points;
  final String detail;
  final Color accent;

  const _RankingRow({
    required this.rank,
    required this.name,
    required this.points,
    required this.detail,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isWinner = rank == 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isWinner ? 13 : 11,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                color: isWinner ? accent : Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: isWinner ? 13 : 12,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xDD000000),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: pointsWidth,
            child: Text(
              points,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isWinner ? 12 : 11,
                fontWeight: isWinner ? FontWeight.w600 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: Colors.grey.shade700,
              ),
            ),
          ),
          SizedBox(
            width: detailWidth,
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isWinner ? 12 : 11,
                fontWeight: isWinner ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: isWinner ? accent : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
