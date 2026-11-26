import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
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
      empty: 'Рекордів ще немає.',
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
    add('mvp/${period.name}', 'Лише вища ліга', _table(const [
      SiteColumn('Гравець', numeric: false),
      SiteColumn('Бали/гра'),
      SiteColumn('Макс'),
      SiteColumn('Разом'),
      SiteColumn('WR'),
      SiteColumn('Сезон'),
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
      add('roles/${role.name}/${period.name}', 'Лише вища ліга', _table(const [
        SiteColumn('Гравець', numeric: false),
        SiteColumn('Бали/гра'),
        SiteColumn('WR'),
        SiteColumn('Ігри'),
        SiteColumn('Сезон'),
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

  }

  // Hosts: every season together — the points period doesn't change how many
  // games someone hosted — plus a "Без ведучого" row for games with no host
  // marked (only in seasons where hosts were recorded at all).
  for (final allTime in [false, true]) {
    final noHost = <int?, int>{};
    for (final s in input.games.map((g) => g.seasonId).toSet()) {
      final n = gamesWithoutHost(input.games.where((g) => g.seasonId == s)) ?? 0;
      if (n == 0) continue;
      final key = allTime ? null : s;
      noHost[key] = (noHost[key] ?? 0) + n;
    }
    add('hosts/${allTime ? 'alltime' : 'season'}', 'Усі ведучі', _table([
      const SiteColumn('Ведучий', numeric: false),
      const SiteColumn('Проведено'),
      const SiteColumn('Сер. +'),
      const SiteColumn('Сер. −'),
      if (!allTime) const SiteColumn('Сезон'),
    ], [
      for (final r in hostRecords(input, allTime: allTime))
        [
          x.name(r.host),
          SiteCell('${r.hosted}', s: r.hosted),
          r.periodGames >= kHostMinGamesForAverage
              ? SiteCell(f2(r.avgPlus), s: r.avgPlus)
              : const SiteCell('—', s: -99),
          r.periodGames >= kHostMinGamesForAverage
              ? SiteCell(f2(r.avgMinus), s: -r.avgMinus)
              : const SiteCell('—', s: -99),
          if (!allTime) SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
        ],
      for (final MapEntry(key: season, value: n) in noHost.entries)
        [
          const SiteCell('Без ведучого'),
          SiteCell('$n', s: n),
          const SiteCell('—', s: -99),
          const SiteCell('—', s: -99),
          if (!allTime) SiteCell(seasonLabel(season), s: season ?? -1),
        ],
    ]));
  }

  for (final allTime in [false, true]) {
    add('games/${allTime ? 'alltime' : 'season'}',
        allTime ? 'Усі гравці' : 'Лише вища ліга', _table([
      const SiteColumn('Гравець', numeric: false),
      const SiteColumn('Ігри'),
      const SiteColumn('WR'),
      if (!allTime) const SiteColumn('Сезон'),
    ], [
      for (final r in gamesRecords(input, allTime: allTime))
        [
          x.name(r.player),
          SiteCell('${r.games}', s: r.games),
          SiteCell(pct0(r.winRate), s: r.winRate, tone: 'wr'),
          if (!allTime) SiteCell(seasonLabel(r.seasonId), s: r.seasonId ?? -1),
        ]
    ]));
  }

  add('pu', 'Лише вища ліга', _table(const [
    SiteColumn('Гравець', numeric: false),
    SiteColumn('ПУ', tip: 'Убитий у першу ніч'),
    SiteColumn('% червоних'),
    SiteColumn('Червоні ігри'),
    SiteColumn('Сезон'),
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
  add('penalties', 'Вища ліга · сезони $kPenaltyColumnFirstSeason+', _table(const [
    SiteColumn('Гравець', numeric: false),
    SiteColumn('Мінус/гра'),
    SiteColumn('Макс'),
    SiteColumn('Разом'),
    SiteColumn('WR'),
    SiteColumn('Сезон'),
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

  add('streaks', 'Усі гравці', _table(const [
    SiteColumn('Гравець', numeric: false),
    SiteColumn('Перемог поспіль'),
    SiteColumn('Сезони', numeric: false),
  ], [
    for (final WinStreak r in x.read(winStreaksProvider))
      [
        x.name(r.player),
        SiteCell('${r.length}', s: r.length),
        SiteCell(r.seasonsLabel, s: r.fromSeason),
      ]
  ]));

  // Season prize places: top 3 of each league, as on the player profiles.
  for (final league in ['main', 'small']) {
    final rows = <List<SiteCell>>[];
    for (final p in x.players) {
      final acc = x.read(playerAccomplishmentsProvider(p));
      final c = league == 'main'
          ? [acc.firsts, acc.seconds, acc.thirds]
          : [acc.smallFirsts, acc.smallSeconds, acc.smallThirds];
      final total = c[0] + c[1] + c[2];
      if (total == 0) continue;
      rows.add([
        x.name(p),
        // Ties on wins are broken by 2nd, then 3rd places.
        SiteCell('${c[0]}', s: c[0] * 10000 + c[1] * 100 + c[2]),
        SiteCell('${c[1]}', s: c[1]),
        SiteCell('${c[2]}', s: c[2]),
        SiteCell('$total', s: total),
      ]);
    }
    add('podiums/$league', 'За перемогами, далі за 2 і 3 місцями', _table(const [
      SiteColumn('Гравець', numeric: false),
      SiteColumn('1 місце'),
      SiteColumn('2 місце'),
      SiteColumn('3 місце'),
      SiteColumn('Подіуми'),
    ], rows));
  }

  // Season awards, as on the player profiles.
  final nominations = <List<SiteCell>>[];
  for (final p in x.players) {
    final acc = x.read(playerAccomplishmentsProvider(p));
    final c = [
      acc.mvp,
      acc.bestSheriff,
      acc.bestCivilian,
      acc.bestMafia,
      acc.bestDon,
      acc.mostKilled,
    ];
    final total = c.fold(0, (a, n) => a + n);
    if (total == 0) continue;
    nominations.add([
      x.name(p),
      for (final n in c) SiteCell('$n', s: n),
      // Ties on the total are broken by MVPs.
      SiteCell('$total', s: total * 100 + acc.mvp),
    ]);
  }
  add('nominations', 'Нагороди сезону · за сумою, далі за MVP', SiteTable(
    showRank: true,
    collapsed: _topN,
    sortColumn: 7,
    empty: 'Рекордів ще немає.',
    columns: const [
      SiteColumn('Гравець', numeric: false),
      SiteColumn('MVP'),
      SiteColumn('Шериф', tip: 'Кращий шериф'),
      SiteColumn('Мирний', tip: 'Кращий мирний'),
      SiteColumn('Мафія', tip: 'Краща мафія'),
      SiteColumn('Дон', tip: 'Кращий дон'),
      SiteColumn('Найчастіше вбитий', tip: 'Найбільше вбивств у першу ніч у вищій лізі'),
      SiteColumn('Разом'),
    ],
    rows: nominations,
  ));

  return {
    'categories': const [
      {
        'slug': 'podiums',
        'label': 'Призові місця',
        'filters': ['league'],
        'group': 'Статистика сезону',
      },
      {
        'slug': 'nominations',
        'label': 'Номінації',
        'filters': <String>[],
        'group': 'Статистика сезону',
      },
      {'slug': 'mvp', 'label': 'MVP', 'filters': ['period'], 'group': 'За весь час'},
      {
        'slug': 'roles',
        'label': 'Ролі',
        'filters': ['role', 'period'],
        'group': 'За весь час',
      },
      {'slug': 'games', 'label': 'Ігри', 'filters': ['scope'], 'group': 'За весь час'},
      {'slug': 'hosts', 'label': 'Ведучі', 'filters': ['scope'], 'group': 'За весь час'},
      {'slug': 'pu', 'label': 'ПУ', 'filters': <String>[], 'group': 'За весь час'},
      {
        'slug': 'penalties',
        'label': 'Штрафи',
        'filters': <String>[],
        'group': 'За весь час',
      },
      {
        'slug': 'streaks',
        'label': 'Серії перемог',
        'filters': <String>[],
        'group': 'За весь час',
      },
    ],
    'roles': [
      for (final r in Role.values) {'key': r.name, 'label': roleLabel(r)}
    ],
    'scopes': const [
      {'key': 'alltime', 'label': 'За весь час'},
      {'key': 'season', 'label': 'За сезон'},
    ],
    'leagues': const [
      {'key': 'main', 'label': 'Вища ліга'},
      {'key': 'small', 'label': 'Мала ліга'},
    ],
    'periods': [
      for (final p in PointsPeriod.values) {'key': p.name, 'label': pointsPeriodLabel(p)}
    ],
    'defaults': const {
      'role': 'don',
      'scope': 'alltime',
      'period': 'modern',
      'league': 'main',
    },
    'tables': tables,
  };
}
