import 'package:family_mafia_app/models/player.dart';
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
                    const SizedBox(height: 32),
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
