import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugScreen extends ConsumerWidget {
  const DebugScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataState = ref.watch(appDataProvider);
    return dataState.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (_) => const _DebugContent(),
    );
  }
}

class _DebugContent extends ConsumerWidget {
  const _DebugContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(debugSlotWinRateProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final totalPlayed = slots.fold<int>(0, (a, s) => a + s.played);
    final totalWins = slots.fold<int>(0, (a, s) => a + s.wins);
    final overallWr = totalPlayed == 0 ? 0.0 : totalWins / totalPlayed;

    return Scaffold(
      appBar: AppBar(title: Text('Debug · $kDebugPlayer')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        children: [
          Text('Win rate by slot', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            totalPlayed == 0
                ? 'No rating games found for $kDebugPlayer.'
                : 'Overall: $totalWins/$totalPlayed · '
                    '${(overallWr * 100).toStringAsFixed(1)}%',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final s in slots) ...[
            _SlotRow(slot: s),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final SlotWinRate slot;
  const _SlotRow({required this.slot});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasGames = slot.played > 0;
    final pct = (slot.winRate * 100).toStringAsFixed(1);
    final color = hasGames ? cs.primary : cs.onSurfaceVariant;

    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            'Slot ${slot.slot}',
            overflow: TextOverflow.ellipsis,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: hasGames ? null : cs.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: slot.winRate,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            hasGames ? '${slot.wins}/${slot.played} · $pct%' : '—',
            textAlign: TextAlign.end,
            style: tt.bodySmall?.copyWith(
              color: hasGames ? null : cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
