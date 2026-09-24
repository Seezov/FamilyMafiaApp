import 'dart:io';

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/html_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
    final matrix = ref.watch(debugSlotRoleProvider);
    final selected = ref.watch(selectedPlayerProvider);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final totalPlayed = slots.fold<int>(0, (a, s) => a + s.played);
    final totalWins = slots.fold<int>(0, (a, s) => a + s.wins);
    final overallWr = totalPlayed == 0 ? 0.0 : totalWins / totalPlayed;

    return Scaffold(
      appBar: AppBar(
        title: Text(selected?.displayName ?? 'Statistics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export stats',
            onPressed: () => _exportStats(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.paddingOf(context).bottom + 80,
        ),
        children: [
          const _PlayerSearchField(),
          const SizedBox(height: 16),
          Text('Win rate by slot & role', style: tt.titleMedium),
          const SizedBox(height: 4),
          Text(
            totalPlayed == 0
                ? 'No rating games found.'
                : 'Overall: $totalWins/$totalPlayed · '
                    '${(overallWr * 100).toStringAsFixed(1)}%',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (totalPlayed > 0) const _MatrixHeader(),
          for (final row in matrix)
            if (totalPlayed > 0) _MatrixRow(row: row),
        ],
      ),
    );
  }
}

Future<void> _exportStats(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final data = ref.read(statsExportDataProvider);
    final html = buildStatsHtml(data);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/family_mafia_stats.html');
    await file.writeAsString(html);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/html')],
      subject: 'Family Mafia — Stats',
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

String _roleLabel(Role role) => switch (role) {
      Role.sheriff => 'Shr',
      Role.don => 'Don',
      Role.civilian => 'Civ',
      Role.mafia => 'Maf',
    };

const double _kSlotColWidth = 56;

class _MatrixHeader extends StatelessWidget {
  const _MatrixHeader();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(width: _kSlotColWidth),
          for (final role in kMatrixRoles)
            Expanded(
              child: Text(
                _roleLabel(role),
                textAlign: TextAlign.center,
                style: tt.labelMedium?.copyWith(
                  color: role.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: Text(
              'Tot',
              textAlign: TextAlign.center,
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixRow extends StatelessWidget {
  final SlotRoleRow row;
  const _MatrixRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: _kSlotColWidth,
            child: Text(
              'Slot ${row.slot}',
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          for (final role in kMatrixRoles)
            Expanded(
              child: _MatrixCell(cell: row.cells[role]!),
            ),
          Expanded(child: _MatrixCell(cell: _rowTotal(row), emphasize: true)),
        ],
      ),
    );
  }
}

RoleWinRate _rowTotal(SlotRoleRow row) {
  var played = 0;
  var wins = 0;
  for (final c in row.cells.values) {
    played += c.played;
    wins += c.wins;
  }
  return (
    played: played,
    wins: wins,
    winRate: played == 0 ? 0.0 : wins / played,
  );
}

class _MatrixCell extends StatelessWidget {
  final RoleWinRate cell;
  final bool emphasize;
  const _MatrixCell({required this.cell, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final hasGames = cell.played > 0;
    if (!hasGames) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      );
    }
    return Column(
      children: [
        Text(
          '${(cell.winRate * 100).toStringAsFixed(0)}%',
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          '${cell.wins}/${cell.played}',
          textAlign: TextAlign.center,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PlayerSearchField extends ConsumerWidget {
  const _PlayerSearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final players = ref.watch(playersListProvider);
    final selected = ref.watch(selectedPlayerProvider);

    return Autocomplete<Player>(
      displayStringForOption: (p) => p.displayName,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.toLowerCase().trim();
        if (q.isEmpty) return const Iterable<Player>.empty();
        return players
            .where((p) => p.displayName.toLowerCase().contains(q));
      },
      onSelected: (p) =>
          ref.read(selectedPlayerProvider.notifier).state = p,
      fieldViewBuilder:
          (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onFieldSubmitted(),
          decoration: InputDecoration(
            hintText: 'Search player…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: selected != null
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.clear();
                      ref.read(selectedPlayerProvider.notifier).state = null;
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
