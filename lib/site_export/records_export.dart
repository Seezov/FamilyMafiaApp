import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/records/records_providers.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

const _topN = 10;

SiteTable _table(List<SiteColumn> columns, List<List<SiteCell>> rows) =>
    SiteTable(
      showRank: true,
      collapsed: _topN,
      sortColumn: 1,
      empty: 'No records yet.',
      columns: columns,
      rows: rows,
    );

/// The Records tab: every category, role, scope and period, pre-ranked.
/// Columns, text and sort keys follow `records_screen.dart`.
Map<String, Object?> recordsJson(ExportContext x) {
  final input = x.read(recordsInputProvider);
  final tables = <String, Object?>{};
  void add(String key, String scope, SiteTable t) =>
      tables[key] = {'scope': scope, 'table': t.toJson()};

  for (final period in PointsPeriod.values) {
    add('mvp/${period.name}', 'Main league only', _table(const [
      SiteColumn('Player', numeric: false),
      SiteColumn('Pts/game'),
      SiteColumn('Max'),
      SiteColumn('Total'),
      SiteColumn('WR'),
      SiteColumn('Season'),
    ], [
      for (final r in mvpRecords(input, period))
        [
          x.name(r.player),
          SiteCell(f2(r.addPerGame), s: r.addPerGame),
          SiteCell(f2(r.maxSingleAdd), s: r.maxSingleAdd),
          SiteCell(r.totalAdd.toStringAsFixed(1), s: r.totalAdd),
          SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
          SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
        ]
    ]));

    for (final role in Role.values) {
      add('roles/${role.name}/${period.name}', 'Main league only', _table(const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Pts/game'),
        SiteColumn('WR'),
        SiteColumn('Games'),
        SiteColumn('Season'),
      ], [
        for (final r in roleRecords(input, role, period))
          [
            x.name(r.player),
            SiteCell(f2(r.pointsPerGame), s: r.pointsPerGame),
            SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
            SiteCell('${r.games}', s: r.games),
            SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
          ]
      ]));
    }

    for (final allTime in [false, true]) {
      add('hosts/${allTime ? 'alltime' : 'season'}/${period.name}', 'All hosts',
          _table(const [
        SiteColumn('Host', numeric: false),
        SiteColumn('Hosted'),
        SiteColumn('Avg +'),
        SiteColumn('Avg −'),
        SiteColumn('Season'),
      ], [
        for (final r in hostRecords(input, allTime: allTime, period: period))
          [
            x.name(r.host),
            SiteCell('${r.hosted}', s: r.hosted),
            r.periodGames >= kHostMinGamesForAverage
                ? SiteCell(f2(r.avgPlus), s: r.avgPlus)
                : const SiteCell('—', s: -99),
            r.periodGames >= kHostMinGamesForAverage
                ? SiteCell(f2(r.avgMinus), s: -r.avgMinus)
                : const SiteCell('—', s: -99),
            SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
          ]
      ]));
    }
  }

  for (final allTime in [false, true]) {
    add('games/${allTime ? 'alltime' : 'season'}',
        allTime ? 'All players' : 'Main league only', _table(const [
      SiteColumn('Player', numeric: false),
      SiteColumn('Games'),
      SiteColumn('WR'),
      SiteColumn('Season'),
    ], [
      for (final r in gamesRecords(input, allTime: allTime))
        [
          x.name(r.player),
          SiteCell('${r.games}', s: r.games),
          SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
          SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
        ]
    ]));
  }

  add('pu', 'Main league only', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('ПУ', tip: 'Killed on the first night'),
    SiteColumn('% of red'),
    SiteColumn('Red games'),
    SiteColumn('Season'),
  ], [
    for (final r in firstKillRecords(input))
      [
        x.name(r.player),
        SiteCell('${r.count}', s: r.count),
        SiteCell(pct0(r.pct), s: r.pct),
        SiteCell('${r.redGames}', s: r.redGames),
        SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
      ]
  ]));

  // Negated sort keys: "most minus" first when descending, as in the app.
  add('penalties', 'Main league · Seasons $kPenaltyColumnFirstSeason+', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('Minus/game'),
    SiteColumn('Max'),
    SiteColumn('Total'),
    SiteColumn('WR'),
    SiteColumn('Season'),
  ], [
    for (final r in penaltyRecords(input))
      [
        x.name(r.player),
        SiteCell(f2(r.minusPerGame), s: -r.minusPerGame),
        SiteCell(f2(r.maxSingleMinus), s: -r.maxSingleMinus),
        SiteCell(r.totalMinus.toStringAsFixed(1), s: -r.totalMinus),
        SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
        SiteCell(seasonLabel(r.seasonId), s: r.seasonId),
      ]
  ]));

  add('streaks', 'All players', _table(const [
    SiteColumn('Player', numeric: false),
    SiteColumn('Wins in a row'),
    SiteColumn('Seasons', numeric: false),
  ], [
    for (final WinStreak r in x.read(winStreaksProvider))
      [
        x.name(r.player),
        SiteCell('${r.length}', s: r.length),
        SiteCell(r.seasonsLabel, s: r.fromSeason),
      ]
  ]));

  return {
    'categories': const [
      {'slug': 'mvp', 'label': 'MVP', 'filters': ['period']},
      {'slug': 'roles', 'label': 'Roles', 'filters': ['role', 'period']},
      {'slug': 'games', 'label': 'Games', 'filters': ['scope']},
      {'slug': 'hosts', 'label': 'Hosts', 'filters': ['scope', 'period']},
      {'slug': 'pu', 'label': 'ПУ', 'filters': <String>[]},
      {'slug': 'penalties', 'label': 'Penalties', 'filters': <String>[]},
      {'slug': 'streaks', 'label': 'Streaks', 'filters': <String>[]},
    ],
    'roles': [
      for (final r in Role.values) {'key': r.name, 'label': roleLabel(r)}
    ],
    'scopes': const [
      {'key': 'season', 'label': 'Per season'},
      {'key': 'alltime', 'label': 'All time'},
    ],
    'periods': [
      for (final p in PointsPeriod.values) {'key': p.name, 'label': p.label}
    ],
    'defaults': const {'role': 'don', 'scope': 'season', 'period': 'modern'},
    'tables': tables,
  };
}
