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
    final dataState = ref.watch(appDataProvider);

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
    final players = ref.watch(playersListProvider);

    return Scaffold(
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
          ),
          itemCount: players.length,
          itemBuilder: (context, i) => _PlayerCard(player: players[i]),
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;

  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerProfileScreen(player: player),
        ),
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _avatarColor(player.displayName),
                child: Text(
                  _initials(player.displayName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                player.displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
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
