import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/screens/players/season_chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerProfileScreen extends ConsumerWidget {
  final Player player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(seasonGamesProvider);
    final acc = ref.watch(playerAccomplishmentsProvider(player));

    SeasonGamesEntry? entry;
    for (final e in entries) {
      if (e.name == player.displayName) {
        entry = e;
        break;
      }
    }

    final gamesBySeason = List<int?>.generate(29, (i) {
      final match = entry?.seasonData.where((e) => e.seasonId == i);
      return (match == null || match.isEmpty) ? null : match.first.games;
    });

    final total = entry?.seasonData.fold(0, (s, e) => s + e.games) ?? 0;

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
                    if (acc.sumOfNominations() > 0) ...[
                      _AccomplishmentsSection(acc: acc),
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
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Accomplishments section
// ---------------------------------------------------------------------------

class _AccomplishmentsSection extends StatelessWidget {
  final PlayerAccomplishments acc;

  const _AccomplishmentsSection({required this.acc});

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
          ],
        ),
        const SizedBox(height: 10),
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

// ---------------------------------------------------------------------------
// Interactive season chart
// ---------------------------------------------------------------------------

class _SeasonChart extends StatefulWidget {
  final List<int?> gamesBySeason;

  const _SeasonChart({required this.gamesBySeason});

  @override
  State<_SeasonChart> createState() => _SeasonChartState();
}

class _SeasonChartState extends State<_SeasonChart> {
  int? _selectedIndex;

  static const _chartHeight = 220.0;

  int? _findNearest(Offset local, double width) {
    final chartWidth =
        width - SeasonChartPainter.leftPadding - SeasonChartPainter.rightPadding;
    final widthStep = chartWidth / (widget.gamesBySeason.length - 1);

    int? closest;
    double minDist = double.infinity;
    for (int i = 0; i < widget.gamesBySeason.length; i++) {
      if (widget.gamesBySeason[i] == null) continue;
      final px = SeasonChartPainter.leftPadding + i * widthStep;
      final dist = (local.dx - px).abs();
      if (dist < minDist) {
        minDist = dist;
        closest = i;
      }
    }
    return (closest != null && minDist < widthStep) ? closest : null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return TapRegion(
          onTapOutside: (_) => setState(() => _selectedIndex = null),
          child: GestureDetector(
          onTapUp: (d) {
            final idx = _findNearest(d.localPosition, width);
            setState(() => _selectedIndex = idx == _selectedIndex ? null : idx);
          },
          onPanUpdate: (d) {
            final idx = _findNearest(d.localPosition, width);
            setState(() => _selectedIndex = idx);
          },
          child: Stack(
            children: [
              SizedBox(
                width: double.infinity,
                height: _chartHeight,
                child: CustomPaint(
                  painter: SeasonChartPainter(
                    widget.gamesBySeason,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              ),
              if (_selectedIndex != null) _buildTooltip(_selectedIndex!, width),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildTooltip(int index, double width) {
    final chartWidth =
        width - SeasonChartPainter.leftPadding - SeasonChartPainter.rightPadding;
    final chartHeight = _chartHeight - SeasonChartPainter.bottomPadding;
    final widthStep = chartWidth / (widget.gamesBySeason.length - 1);

    final games = widget.gamesBySeason[index]!;
    final x = SeasonChartPainter.leftPadding + index * widthStep;
    final clamped = games.clamp(0, SeasonChartPainter.maxYAxis.toInt()).toDouble();
    final y = chartHeight - chartHeight * (clamped / SeasonChartPainter.maxYAxis);

    const tooltipW = 90.0;
    const tooltipH = 32.0;
    const gap = 10.0;

    double left = x - tooltipW / 2;
    if (left < 0) left = 0;
    if (left + tooltipW > width) left = width - tooltipW;
    final top = (y - tooltipH - gap).clamp(0.0, _chartHeight - tooltipH);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: tooltipW,
        height: tooltipH,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          'S$index · $games games',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

Color _avatarColor(String name) {
  const colors = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF66BB6A),
    Color(0xFFFFA726),
    Color(0xFF42A5F5),
    Color(0xFFEC407A),
  ];
  final index = name.codeUnits.fold(0, (s, c) => s + c) % colors.length;
  return colors[index];
}
