import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);
    return dataState.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) => const _DashboardContent(),
    );
  }
}

// ---------------------------------------------------------------------------
// Content
// ---------------------------------------------------------------------------

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent();

  static const _roleOrder = [Role.civilian, Role.mafia, Role.sheriff, Role.don];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topByRole = ref.watch(topPlayersByRoleProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Leaderboards',
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Leaderboard Rules'),
                        content: const Text(
                          'Only players with 140 or more total rating games '
                          'appear on these leaderboards.\n\n'
                          'Win rate is calculated across all seasons.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Protocol guesses · All-time win rate by role · 140+ games',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              const _ProtocolGuessLeaderboardCard(),
              const SizedBox(height: 16),
              for (final role in _roleOrder) ...[
                _RoleLeaderboardCard(
                  role: role,
                  entries: topByRole[role] ?? [],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Role card
// ---------------------------------------------------------------------------

class _RoleLeaderboardCard extends StatelessWidget {
  final Role role;
  final List<RoleLeaderEntry> entries;

  const _RoleLeaderboardCard({required this.role, required this.entries});

  static Color _roleColor(Role role) => switch (role) {
        Role.civilian => const Color(0xFFE53935),
        Role.mafia => const Color(0xFF616161),
        Role.sheriff => const Color(0xFF00BCD4),
        Role.don => const Color(0xFF212121),
      };

  static IconData _roleIcon(Role role) => switch (role) {
        Role.civilian => Icons.person,
        Role.mafia => Icons.thumb_down,
        Role.sheriff => Icons.local_police,
        Role.don => Icons.gps_fixed,
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
    final cs = Theme.of(context).colorScheme;
    final color = _roleColor(role);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(_roleIcon(role), color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  _roleName(role),
                  style: tt.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'WR',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 40),
                Text(
                  'G',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Rows
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No qualifying players yet',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              _LeaderRow(rank: i + 1, entry: entries[i], roleColor: color),
            ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Leaderboard row
// ---------------------------------------------------------------------------

class _LeaderRow extends StatelessWidget {
  final int rank;
  final RoleLeaderEntry entry;
  final Color roleColor;

  const _LeaderRow({
    required this.rank,
    required this.entry,
    required this.roleColor,
  });

  static const _rankColors = [
    Color(0xFFFFD700), // gold
    Color(0xFFB0BEC5), // silver
    Color(0xFFBF8970), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rankColor =
        rank <= 3 ? _rankColors[rank - 1] : cs.onSurfaceVariant;
    final wrPct = (entry.wr * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: tt.labelLarge?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.player.displayName,
              style: tt.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$wrPct%',
              textAlign: TextAlign.end,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: rank == 1 ? roleColor : cs.onSurface,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${entry.games}',
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Protocol guess leaderboard card
// ---------------------------------------------------------------------------

class _ProtocolGuessLeaderboardCard extends ConsumerWidget {
  const _ProtocolGuessLeaderboardCard();

  static const _color = Color(0xFF7B1FA2); // purple

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(protocolGuessLeaderboardProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _color.withValues(alpha: 0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(Icons.visibility, color: _color, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Protocol Guesses',
                  style: tt.titleMedium?.copyWith(
                    color: _color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Acc',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(width: 24),
                Text(
                  'G',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Rows
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No protocol data yet',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              _ProtocolRow(rank: i + 1, entry: entries[i]),
            ],
        ],
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  final int rank;
  final ProtocolLeaderEntry entry;

  const _ProtocolRow({required this.rank, required this.entry});

  static const _rankColors = [
    Color(0xFFFFD700),
    Color(0xFFB0BEC5),
    Color(0xFFBF8970),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rankColor =
        rank <= 3 ? _rankColors[rank - 1] : cs.onSurfaceVariant;
    final accPct = (entry.accuracy * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: tt.labelLarge?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.player.displayName,
              style: tt.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$accPct%',
              textAlign: TextAlign.end,
              style: tt.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: rank == 1 ? const Color(0xFF7B1FA2) : cs.onSurface,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${entry.correct}/${entry.total}',
              textAlign: TextAlign.end,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
