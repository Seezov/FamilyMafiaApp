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
    add('hosts/${allTime ? 'alltime' : 'season'}', 'All hosts', _table([
      const SiteColumn('Host', numeric: false),
      const SiteColumn('Hosted'),
      const SiteColumn('Avg +'),
      const SiteColumn('Avg −'),
      if (!allTime) const SiteColumn('Season'),
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
        allTime ? 'All players' : 'Main league only', _table([
      const SiteColumn('Player', numeric: false),
      const SiteColumn('Games'),
      const SiteColumn('WR'),
      if (!allTime) const SiteColumn('Season'),
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
    add('podiums/$league', 'Ranked by wins, then 2nd and 3rd places', _table(const [
      SiteColumn('Player', numeric: false),
      SiteColumn('1st'),
      SiteColumn('2nd'),
      SiteColumn('3rd'),
      SiteColumn('Podiums'),
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
  add('nominations', 'Season awards · ranked by total, then MVPs', SiteTable(
    showRank: true,
    collapsed: _topN,
    sortColumn: 7,
    empty: 'No records yet.',
    columns: const [
      SiteColumn('Player', numeric: false),
      SiteColumn('MVP'),
      SiteColumn('Sheriff', tip: 'Best Sheriff'),
      SiteColumn('Civilian', tip: 'Best Civilian'),
      SiteColumn('Mafia', tip: 'Best Mafia'),
      SiteColumn('Don', tip: 'Best Don'),
      SiteColumn('Most killed', tip: 'Most first-night kills in the main league'),
      SiteColumn('Total'),
    ],
    rows: nominations,
  ));

  return {
    'categories': const [
      {
        'slug': 'podiums',
        'label': 'Prize places',
        'filters': ['league'],
        'group': 'Season stats',
      },
      {
        'slug': 'nominations',
        'label': 'Nominations',
        'filters': <String>[],
        'group': 'Season stats',
      },
      {'slug': 'mvp', 'label': 'MVP', 'filters': ['period'], 'group': 'All time'},
      {
        'slug': 'roles',
        'label': 'Roles',
        'filters': ['role', 'period'],
        'group': 'All time',
      },
      {'slug': 'games', 'label': 'Games', 'filters': ['scope'], 'group': 'All time'},
      {'slug': 'hosts', 'label': 'Hosts', 'filters': ['scope'], 'group': 'All time'},
      {'slug': 'pu', 'label': 'ПУ', 'filters': <String>[], 'group': 'All time'},
      {
        'slug': 'penalties',
        'label': 'Penalties',
        'filters': <String>[],
        'group': 'All time',
      },
      {
        'slug': 'streaks',
        'label': 'Streaks',
        'filters': <String>[],
        'group': 'All time',
      },
    ],
    'roles': [
      for (final r in Role.values) {'key': r.name, 'label': roleLabel(r)}
    ],
    'scopes': const [
      {'key': 'alltime', 'label': 'All time'},
      {'key': 'season', 'label': 'Per season'},
    ],
    'leagues': const [
      {'key': 'main', 'label': 'Main league'},
      {'key': 'small', 'label': 'Small league'},
    ],
    'periods': [
      for (final p in PointsPeriod.values) {'key': p.name, 'label': p.label}
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
