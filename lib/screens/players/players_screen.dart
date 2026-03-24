import 'dart:ui' show ImageFilter;

import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/players/player_profile_screen.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(initialLoadProvider);

    return dataState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error loading data: $e')),
      ),
      data: (_) => const _PlayersContent(),
    );
  }
}

class _PlayersContent extends ConsumerWidget {
  const _PlayersContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(filteredPlayersProvider);
    final phase = ref.watch(loadingPhaseProvider);
    final isBackgroundLoading = phase != LoadingPhase.allLoaded;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
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
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.82),
                ),
              ),
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(0),
              child: SizedBox.shrink(),
            ),
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: const _SearchBar(),
            ),
          ),
          if (isBackgroundLoading)
            const SliverToBoxAdapter(child: _BackgroundLoadingIndicator()),
          if (players.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No players found')),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, MediaQuery.paddingOf(context).bottom + 80),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _PlayerCard(player: players[i]),
                  childCount: players.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackgroundLoadingIndicator extends StatelessWidget {
  const _BackgroundLoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinearProgressIndicator(
          minHeight: 2,
          backgroundColor: cs.surfaceContainerHighest,
          color: cs.primary,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            'Loading all seasons\u2026',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends ConsumerStatefulWidget {
  const _SearchBar();

  @override
  ConsumerState<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends ConsumerState<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(playerSearchQueryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _controller,
        onChanged: (v) =>
            ref.read(playerSearchQueryProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Search players…',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _controller.clear();
                    ref.read(playerSearchQueryProvider.notifier).state = '';
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _PlayerCard extends ConsumerWidget {
  final Player player;

  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsMap = ref.watch(playerStatsMapProvider);
    final stats = statsMap[player.displayName];
    final games = stats?.games ?? 0;
    final winRate = stats?.winRate ?? 0.0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(player: player),
        ),
      ),
      child: Container(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _avatarColor(player.displayName),
                child: Text(
                  _initials(player.displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                player.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                '$games games',
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              _WinRatePill(winRate: winRate),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinRatePill extends StatelessWidget {
  final double winRate;

  const _WinRatePill({required this.winRate});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (winRate >= 0.50) {
      bg = const Color(0xFF4CAF50).withValues(alpha: 0.15);
      fg = const Color(0xFF2E7D32);
    } else if (winRate >= 0.40) {
      bg = const Color(0xFFFFC107).withValues(alpha: 0.20);
      fg = const Color(0xFFE65100);
    } else {
      bg = const Color(0xFFF44336).withValues(alpha: 0.12);
      fg = const Color(0xFFC62828);
    }

    final pct = (winRate * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$pct%',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
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
