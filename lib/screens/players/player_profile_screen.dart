import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/best_moves.dart';
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
    final roleGames = ref.watch(playerRoleGamesProvider(player));
    final firstKill = ref.watch(playerFirstKillProvider(player));
    final bestMoves = ref.watch(playerBestMovesProvider(player));

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
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (roleGames.isNotEmpty) ...[
                      _RoleDistributionSection(roleGames: roleGames),
                      const SizedBox(height: 24),
                    ],
                    if (firstKill.total > 0) ...[
                      _FirstKillSection(
                        total: firstKill.total,
                        cityLost: firstKill.cityLost,
                        totalGames: total,
                      ),
                      const SizedBox(height: 24),
                    ],
                    () {
                      final bmTotal = bestMoves.zeroBlacks +
                          bestMoves.oneBlack +
                          bestMoves.twoBlacks +
                          bestMoves.threeBlacks;
                      return bmTotal > 0
                          ? _BestMovesSection(bm: bestMoves)
                          : const SizedBox.shrink();
                    }(),
                  ],
                ),
              ),
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

// ---------------------------------------------------------------------------
// Role Distribution
// ---------------------------------------------------------------------------

class _RoleDistributionSection extends StatelessWidget {
  final Map<String, int> roleGames;

  const _RoleDistributionSection({required this.roleGames});

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

    final total = summary.values.fold(0, (a, b) => a + b);
    final maxCount = summary.values.reduce((a, b) => a > b ? a : b);

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
                total: total,
                maxCount: maxCount,
                color: _roleColor(role),
              ),
            ),
      ],
    );
  }
}

class _RoleBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final int maxCount;
  final Color color;

  const _RoleBar({
    required this.label,
    required this.count,
    required this.total,
    required this.maxCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final pct = total > 0 ? (count / total * 100).round() : 0;

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
                maxCount > 0 ? constraints.maxWidth * count / maxCount : 0.0;
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
          width: 52,
          child: Text(
            '$count ($pct%)',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

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

// ---------------------------------------------------------------------------
// Best Moves
// ---------------------------------------------------------------------------

class _BestMovesSection extends StatelessWidget {
  final BestMoves bm;

  const _BestMovesSection({required this.bm});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final total =
        bm.zeroBlacks + bm.oneBlack + bm.twoBlacks + bm.threeBlacks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Best Moves', style: tt.titleMedium),
        const SizedBox(height: 2),
        Text(
          '$total best moves total',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _BlackCard(blacks: 0, count: bm.zeroBlacks, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 1, count: bm.oneBlack, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 2, count: bm.twoBlacks, total: total)),
          const SizedBox(width: 8),
          Expanded(child: _BlackCard(blacks: 3, count: bm.threeBlacks, total: total)),
        ]),
      ],
    );
  }
}

class _BlackCard extends StatelessWidget {
  final int blacks;
  final int count;
  final int total;

  const _BlackCard(
      {required this.blacks, required this.count, required this.total});

  static const _colors = [
    Color(0xFFBDBDBD), // 0 blacks — light gray
    Color(0xFF757575), // 1 black  — medium gray
    Color(0xFF424242), // 2 blacks — dark gray
    Color(0xFF212121), // 3 blacks — near black
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final color = _colors[blacks];
    final pct = total > 0 ? (count / total * 100).round() : 0;
    final label = blacks == 1 ? '1 black' : '$blacks blacks';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < blacks
                        ? color
                        : color.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('$count',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text('$pct%',
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(label,
              style: tt.labelSmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}
