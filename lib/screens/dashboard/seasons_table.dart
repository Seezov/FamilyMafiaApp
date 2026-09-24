import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';

SortableColumn<SeasonRow> _named(String label, NamedValue? Function(SeasonRow) f, String Function(num) fmt) =>
    SortableColumn(
      label: label,
      width: 120,
      text: (r) => f(r) == null ? '—' : '${f(r)!.name} ${fmt(f(r)!.value)}',
      sortValue: (r) => f(r)?.value ?? -1,
    );

List<SortableColumn<SeasonRow>> _columns() => [
      SortableColumn(label: 'Season', width: 58, text: (r) => 'S${r.seasonId}', sortValue: (r) => r.seasonId),
      SortableColumn(label: 'Games', width: 56, text: (r) => '${r.games}', sortValue: (r) => r.games),
      SortableColumn(label: 'City WR', width: 60, text: (r) => _pct(r.cityWR), sortValue: (r) => r.cityWR),
      SortableColumn(label: 'Mafia WR', width: 64, text: (r) => _pct(r.mafiaWR), sortValue: (r) => r.mafiaWR),
      SortableColumn(label: 'Players', width: 58, text: (r) => '${r.players}', sortValue: (r) => r.players),
      SortableColumn(label: 'Main lg', width: 58, text: (r) => '${r.mainLeague}', sortValue: (r) => r.mainLeague),
      for (final t in TournamentType.values)
        SortableColumn(label: '${t.label}s', width: 78, text: (r) => '${r.tournaments[t] ?? 0}', sortValue: (r) => r.tournaments[t] ?? 0),
      _named('Most games', (r) => r.mostGames, (v) => '$v'),
      _named('MVP', (r) => r.mvp, (v) => v.toStringAsFixed(2)),
      _named('Most ПУ', (r) => r.mostKilled, (v) => '$v'),
      _named('Top ПУ %', (r) => r.topKilledPct, (v) => _pct(v.toDouble())),
      _named('Most hosted', (r) => r.mostHosted, (v) => '$v'),
      _named('Host avg +', (r) => r.hostAvgPlus, (v) => v.toStringAsFixed(2)),
      _named('Best Don', (r) => r.bestDon, (v) => _pct(v.toDouble())),
      _named('Best Sheriff', (r) => r.bestSheriff, (v) => _pct(v.toDouble())),
      _named('Best Civilian', (r) => r.bestCivilian, (v) => _pct(v.toDouble())),
      _named('Best Mafia', (r) => r.bestMafia, (v) => _pct(v.toDouble())),
    ];

class SeasonsTableCard extends ConsumerWidget {
  const SeasonsTableCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(seasonRowsProvider);
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Seasons',
      trailing: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SeasonsTableScreen()),
        ),
        child: const Text('Expand'),
      ),
      child: SortableTable<SeasonRow>(
        columns: _columns(),
        rows: rows,
        initialSortIndex: 0,
        collapsedRowCount: 5,
      ),
    );
  }
}

class SeasonsTableScreen extends ConsumerWidget {
  const SeasonsTableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(seasonRowsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Seasons')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SortableTable<SeasonRow>(columns: _columns(), rows: rows, initialSortIndex: 0),
      ),
    );
  }
}
