part of '../home_screen.dart';

class _StatItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final String winner;
  final String pointsLabel;
  final String metricLabel;
  final String emptyText;
  final List<_RankingEntry> entries;

  /// False for count-only items (No host) that have no ranking to open.
  final bool expandable;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.winner,
    required this.pointsLabel,
    required this.metricLabel,
    required this.emptyText,
    required this.entries,
    this.expandable = true,
  });
}

class _SeasonStatsCard extends ConsumerStatefulWidget {
  final bool showHosts;

  const _SeasonStatsCard({required this.showHosts});

  @override
  ConsumerState<_SeasonStatsCard> createState() => _SeasonStatsCardState();
}

class _SeasonStatsCardState extends ConsumerState<_SeasonStatsCard> {
  String? _open;

  static String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
  static String _signed(double v) =>
      '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';

  List<_StatItem> _items(SeasonExtraStats s) {
    String first<T>(List<T> l, String Function(T) f) =>
        l.isEmpty ? '—' : f(l.first);
    return [
      _StatItem(
        icon: Icons.casino, label: 'Most Games',
        iconColor: const Color(0xFF3F51B5), bgColor: const Color(0xFFE8EAF6),
        winner: first(s.mostGames, (p) => '${p.player.displayName} · ${p.gamesPlayed}'),
        pointsLabel: 'WR', metricLabel: 'Games',
        emptyText: 'No players in this league.',
        entries: [
          for (final p in s.mostGames)
            (name: p.player.displayName, points: _pct(p.winRate), detail: '${p.gamesPlayed}'),
        ],
      ),
      _StatItem(
        icon: Icons.nightlight_round, label: 'Top ПУ %',
        iconColor: const Color(0xFFFF9800), bgColor: const Color(0xFFFFF3E0),
        winner: first(s.topFirstKilledPct, (p) => '${p.player.displayName} · ${_pct(p.percentOfDeath)}'),
        pointsLabel: 'ПУ', metricLabel: '% of red',
        emptyText: 'No red games in this league.',
        entries: [
          for (final p in s.topFirstKilledPct)
            (name: p.player.displayName, points: '${p.firstKilled}/${redGames(p)}', detail: _pct(p.percentOfDeath)),
        ],
      ),
      if (widget.showHosts) ...[
        _StatItem(
          icon: Icons.mic, label: 'Most Hosted',
          iconColor: const Color(0xFF00897B), bgColor: const Color(0xFFE0F2F1),
          winner: first(s.mostHosted, (h) =>
              '${h.host.displayName} · ${h.hosted} (${s.seasonGames == 0 ? '—' : _pct(h.hosted / s.seasonGames)})'),
          pointsLabel: 'Share', metricLabel: 'Games',
          emptyText: 'No host data for this season.',
          entries: [
            for (final h in s.mostHosted)
              (name: h.host.displayName, points: s.seasonGames == 0 ? '—' : _pct(h.hosted / s.seasonGames), detail: '${h.hosted}'),
          ],
        ),
        _StatItem(
          icon: Icons.add_circle_outline, label: 'Host avg доп',
          iconColor: const Color(0xFF43A047), bgColor: const Color(0xFFE8F5E9),
          winner: first(s.hostAvgPlus, (h) => '${h.host.displayName} · ${_signed(h.avgPlus)}'),
          pointsLabel: 'Games', metricLabel: 'Avg / game',
          emptyText: 'No host hosted $kHostMinGamesForAverage+ games.',
          entries: [
            for (final h in s.hostAvgPlus)
              (name: h.host.displayName, points: '${h.hosted}', detail: _signed(h.avgPlus)),
          ],
        ),
        _StatItem(
          icon: Icons.remove_circle_outline, label: 'Host avg мінус',
          iconColor: const Color(0xFFE53935), bgColor: const Color(0xFFFFEBEE),
          winner: first(s.hostAvgMinus, (h) => '${h.host.displayName} · ${_signed(h.avgMinus)}'),
          pointsLabel: 'Games', metricLabel: 'Avg / game',
          emptyText: 'No host hosted $kHostMinGamesForAverage+ games.',
          entries: [
            for (final h in s.hostAvgMinus)
              (name: h.host.displayName, points: '${h.hosted}', detail: _signed(h.avgMinus)),
          ],
        ),
        _StatItem(
          icon: Icons.help_outline, label: 'No host',
          iconColor: const Color(0xFF757575), bgColor: const Color(0xFFF5F5F5),
          winner: s.gamesWithoutHost == null ? 'No data' : '${s.gamesWithoutHost} games',
          pointsLabel: '', metricLabel: '', emptyText: '', entries: const [],
          expandable: false,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(seasonExtraStatsProvider);
    if (s == null) return const SizedBox.shrink();
    final items = _items(s);
    final open = items.where((i) => i.label == _open).firstOrNull;

    return SectionCard(
      title: 'Season Stats',
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
            children: [
              for (final i in items)
                _StatBadge(
                  icon: i.icon, label: i.label,
                  iconColor: i.iconColor, bgColor: i.bgColor,
                  winner: i.winner,
                  isOpen: i.label == _open,
                  onTap: i.expandable
                      ? () => setState(() => _open = _open == i.label ? null : i.label)
                      : null,
                ),
            ],
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
                      icon: open.icon, label: open.label,
                      iconColor: open.iconColor, bgColor: open.bgColor,
                      pointsLabel: open.pointsLabel, metricLabel: open.metricLabel,
                      emptyText: open.emptyText, entries: open.entries,
                    ),
                  ),
          ),
          if (s.tournaments.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in TournamentType.values)
                  if ((s.tournaments[t] ?? 0) > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${s.tournaments[t]} ${t.label.toLowerCase()}${s.tournaments[t]! > 1 ? 's' : ''}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: t.color),
                      ),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
