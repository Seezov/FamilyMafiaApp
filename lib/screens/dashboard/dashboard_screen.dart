import 'dart:ui' show ImageFilter;

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/widgets/hero_card.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);
    return dataState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
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

  static const _leaderboardOrder = [
    _LeaderboardSpec.protocol,
    _LeaderboardSpec.civilian,
    _LeaderboardSpec.sheriff,
    _LeaderboardSpec.mafia,
    _LeaderboardSpec.don,
  ];

  void _showRulesDialog(BuildContext context) {
    showDialog<void>(
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(clubOverviewProvider);
    final roleWinRates = ref.watch(roleWinRateProvider);
    final topByRole = ref.watch(topPlayersByRoleProvider);
    final protocolEntries = ref.watch(protocolGuessLeaderboardProvider);
    final cs = Theme.of(context).colorScheme;

    String formatGames(int count) {
      if (count >= 1000) {
        final k = count / 1000;
        return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
      }
      return '$count';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: CustomScrollView(
        slivers: [
          // Frosted SliverAppBar
          SliverAppBar(
            pinned: true,
            toolbarHeight: 0,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  color: cs.surface.withValues(alpha: 0.82),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xDD000000),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _showRulesDialog(context),
                      child: Icon(
                        Icons.info_outline,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),

              // ── Hero card: Club Overview ───────────────────────────────
              HeroCard(
                label: 'All Time',
                title: 'Club Overview',
                gradientStart: const Color(0xFF00897B),
                gradientEnd: const Color(0xFF004D40),
                statTiles: [
                  HeroStatTile(
                    value: '${overview.seasons}',
                    label: 'Seasons',
                  ),
                  HeroStatTile(
                    value: formatGames(overview.games),
                    label: 'Games',
                  ),
                  HeroStatTile(
                    value: '${overview.players}',
                    label: 'Players',
                  ),
                  HeroStatTile(
                    value: '${(overview.cityWR * 100).toStringAsFixed(1)}%',
                    label: 'City WR',
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Win Rate by Role ───────────────────────────────────────
              SectionCard(
                title: 'Win Rate by Role',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: Role.values.map((role) {
                    final wr = roleWinRates[role] ?? 0.0;
                    final pct = (wr * 100).toStringAsFixed(0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circle
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: role.lightColor,
                                ),
                              ),
                              // Progress ring
                              CircularProgressIndicator(
                                value: wr,
                                strokeWidth: 4,
                                backgroundColor:
                                    role.lightColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    role.color),
                              ),
                              // Percentage text
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: role.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _roleName(role),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // ── Leaderboard cards ──────────────────────────────────────
              for (final spec in _leaderboardOrder) ...[
                if (spec == _LeaderboardSpec.protocol)
                  _ProtocolLeaderboardCard(entries: protocolEntries)
                else
                  _RoleLeaderboardCard(
                    role: spec.role!,
                    entries: topByRole[spec.role!] ?? [],
                  ),
                const SizedBox(height: 16),
              ],

              SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
            ]),
          ),
        ],
      ),
    );
  }

  static String _roleName(Role role) => switch (role) {
        Role.civilian => 'Civilian',
        Role.mafia => 'Mafia',
        Role.sheriff => 'Sheriff',
        Role.don => 'Don',
      };
}

// ---------------------------------------------------------------------------
// Leaderboard spec helper
// ---------------------------------------------------------------------------

enum _LeaderboardSpec {
  protocol(null),
  civilian(Role.civilian),
  sheriff(Role.sheriff),
  mafia(Role.mafia),
  don(Role.don);

  const _LeaderboardSpec(this.role);
  final Role? role;
}

// ---------------------------------------------------------------------------
// Role leaderboard card
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
        Role.mafia => Icons.theater_comedy,
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
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header with role-tinted background
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: color.withValues(alpha: 0.08),
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
    Color(0xFFF9A825), // gold
    Color(0xFF90A4AE), // silver
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
                color: rank == 1 ? roleColor : Colors.black87,
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

class _ProtocolLeaderboardCard extends StatelessWidget {
  final List<ProtocolLeaderEntry> entries;

  const _ProtocolLeaderboardCard({required this.entries});

  static const _color = Color(0xFF7B1FA2); // purple

  static const _rankColors = [
    Color(0xFFF9A825), // gold
    Color(0xFF90A4AE), // silver
    Color(0xFFBF8970), // bronze
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: _color.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: _color, size: 20),
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
              _ProtocolRow(
                rank: i + 1,
                entry: entries[i],
                rankColors: _rankColors,
              ),
            ],
        ],
      ),
    );
  }
}

class _ProtocolRow extends StatelessWidget {
  final int rank;
  final ProtocolLeaderEntry entry;
  final List<Color> rankColors;

  const _ProtocolRow({
    required this.rank,
    required this.entry,
    required this.rankColors,
  });

  static const _protocolColor = Color(0xFF7B1FA2);

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rankColor =
        rank <= 3 ? rankColors[rank - 1] : cs.onSurfaceVariant;
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
                color: rank == 1 ? _protocolColor : Colors.black87,
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
