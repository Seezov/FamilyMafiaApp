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
              SizedBox(
                width: double.infinity,
                height: 220,
                child: CustomPaint(
                  painter: SeasonChartPainter(gamesBySeason),
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
        Text('Accomplishments', style: tt.titleMedium),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: badges),
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
      width: 76,
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
