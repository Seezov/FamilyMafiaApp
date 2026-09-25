import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:family_mafia_app/widgets/section_card.dart';
import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _pct(double v) => '${(v * 100).toStringAsFixed(0)}%';
String _f(double v) => v.toStringAsFixed(2);
String _season(int? s) => s == null ? 'All time' : 'S$s';

const _topN = 10;

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(recordCategoryProvider);
    final period = ref.watch(recordPeriodProvider);
    final allTime = ref.watch(recordAllTimeProvider);
    final role = ref.watch(recordRoleProvider);
    final input = ref.watch(recordsInputProvider);

    Widget chips<T>(List<T> values, T selected, String Function(T) label, void Function(T) onTap) =>
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final v in values)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(label(v)),
                  selected: v == selected,
                  onSelected: (_) => onTap(v),
                ),
              ),
          ]),
        );

    final table = switch (category) {
      RecordCategory.mvp => SortableTable<MvpRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: mvpRecords(input, period),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            // MVP records follow the club MVP formula (доп + protocol + best
            // move + minuses), so this column is labeled "Pts/game" rather
            // than "Доп/game" even though the field is still `addPerGame`.
            SortableColumn(label: 'Pts/game', width: 70, text: (r) => _f(r.addPerGame), sortValue: (r) => r.addPerGame),
            SortableColumn(label: 'Max', width: 50, text: (r) => _f(r.maxSingleAdd), sortValue: (r) => r.maxSingleAdd),
            SortableColumn(label: 'Total', width: 56, text: (r) => r.totalAdd.toStringAsFixed(1), sortValue: (r) => r.totalAdd),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.roles => SortableTable<RoleRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: roleRecords(input, role, period),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Pts/game', width: 66, text: (r) => _f(r.pointsPerGame), sortValue: (r) => r.pointsPerGame),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Games', width: 54, text: (r) => '${r.games}', sortValue: (r) => r.games),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.games => SortableTable<GamesRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: gamesRecords(input, allTime: allTime),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Games', width: 56, text: (r) => '${r.games}', sortValue: (r) => r.games),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 64, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId ?? -1),
          ]),
      RecordCategory.hosts => SortableTable<HostRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: hostRecords(input, allTime: allTime, period: period),
          columns: [
            SortableColumn(label: 'Host', width: 130, text: (r) => r.host.displayName),
            SortableColumn(label: 'Hosted', width: 58, text: (r) => '${r.hosted}', sortValue: (r) => r.hosted),
            SortableColumn(label: 'Avg +', width: 54,
                text: (r) => r.periodGames >= kHostMinGamesForAverage ? _f(r.avgPlus) : '—',
                sortValue: (r) => r.periodGames >= kHostMinGamesForAverage ? r.avgPlus : -99),
            SortableColumn(label: 'Avg −', width: 54,
                text: (r) => r.periodGames >= kHostMinGamesForAverage ? _f(r.avgMinus) : '—',
                sortValue: (r) => r.periodGames >= kHostMinGamesForAverage ? -r.avgMinus : -99),
            SortableColumn(label: 'Season', width: 64, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId ?? -1),
          ]),
      RecordCategory.firstKilled => SortableTable<FirstKillRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: firstKillRecords(input),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'ПУ', width: 44, text: (r) => '${r.count}', sortValue: (r) => r.count),
            SortableColumn(label: '% of red', width: 62, text: (r) => _pct(r.pct), sortValue: (r) => r.pct),
            SortableColumn(label: 'Red games', width: 70, text: (r) => '${r.redGames}', sortValue: (r) => r.redGames),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.penalties => SortableTable<PenaltyRecord>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: penaltyRecords(input),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            // Negated so "most minus" sorts first when descending.
            SortableColumn(label: 'Minus/game', width: 76, text: (r) => _f(r.minusPerGame), sortValue: (r) => -r.minusPerGame),
            SortableColumn(label: 'Max', width: 50, text: (r) => _f(r.maxSingleMinus), sortValue: (r) => -r.maxSingleMinus),
            SortableColumn(label: 'Total', width: 56, text: (r) => r.totalMinus.toStringAsFixed(1), sortValue: (r) => -r.totalMinus),
            SortableColumn(label: 'WR', width: 50, text: (r) => _pct(r.winRate), sortValue: (r) => r.winRate),
            SortableColumn(label: 'Season', width: 56, text: (r) => _season(r.seasonId), sortValue: (r) => r.seasonId),
          ]),
      RecordCategory.streaks => SortableTable<WinStreak>(
          showRank: true, collapsedRowCount: _topN, initialSortIndex: 1,
          rows: ref.watch(winStreaksProvider),
          columns: [
            SortableColumn(label: 'Player', width: 130, text: (r) => r.player.displayName),
            SortableColumn(label: 'Wins in a row', width: 96, text: (r) => '${r.length}', sortValue: (r) => r.length),
            SortableColumn(label: 'Seasons', width: 80, text: (r) => r.seasonsLabel, sortValue: (r) => r.fromSeason),
          ]),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text('Records'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          chips(RecordCategory.values, category, (c) => c.label,
              (c) => ref.read(recordCategoryProvider.notifier).state = c),
          const SizedBox(height: 8),
          if (category == RecordCategory.roles)
            chips(Role.values, role, (r) => r.name[0].toUpperCase() + r.name.substring(1),
                (r) => ref.read(recordRoleProvider.notifier).state = r),
          if (category.hasAllTime)
            chips([false, true], allTime, (v) => v ? 'All time' : 'Per season',
                (v) => ref.read(recordAllTimeProvider.notifier).state = v),
          if (category.hasPeriod)
            chips(PointsPeriod.values, period, (p) => p.label,
                (p) => ref.read(recordPeriodProvider.notifier).state = p),
          const SizedBox(height: 8),
          SectionCard(
            title: category.label,
            trailing: Text(
              // Hosts aren't players, so hostRecords() applies no league
              // filter regardless of the Per season / All time toggle.
              category == RecordCategory.hosts
                  ? 'All hosts'
                  : category == RecordCategory.streaks ||
                          (category == RecordCategory.games && allTime)
                      ? 'All players'
                      : category == RecordCategory.penalties
                          ? 'Main league · Seasons $kPenaltyColumnFirstSeason+'
                          : 'Main league only',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            child: table,
          ),
        ],
      ),
    );
  }
}
