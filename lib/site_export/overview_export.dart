import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/dashboard/dashboard_providers.dart';
import 'package:family_mafia_app/services/stats/season_rows.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// The Dashboard tab, plus the season list every page's picker needs.
Map<String, Object?> overviewJson(ExportContext x) {
  final seasons = x.seasons;
  final club = x.read(clubOverviewProvider);
  final roleWR = x.read(roleWinRateProvider);
  final top = x.read(topPlayersByRoleProvider);

  return {
    'seasons': [
      for (final s in seasons) {'id': s.id, 'title': s.title}
    ],
    'latestSeasonId': seasons.last.id,
    'club': {
      'seasons': club.seasons,
      'games': club.games,
      'players': club.players,
      'cityWR': club.cityWR,
    },
    'roleWR': {for (final r in kRoleOrder) r.name: roleWR[r] ?? 0.0},
    'leaderboardNote':
        'All-time win rate, players with at least $kDashboardMinRatingGames rating games.',
    'leaderboards': [
      for (final r in kRoleOrder)
        {
          'role': r.name,
          'label': roleLabel(r),
          'table': SiteTable(
            showRank: true,
            empty: 'Nobody qualifies yet.',
            columns: const [
              SiteColumn('Player', numeric: false),
              SiteColumn('WR'),
              SiteColumn('Games'),
            ],
            rows: [
              for (final e in top[r] ?? const [])
                [
                  x.name(e.player),
                  SiteCell(pct1(e.wr), s: e.wr, tone: 'wr'),
                  SiteCell('${e.games}', s: e.games),
                ]
            ],
          ).toJson(),
        }
    ],
    'protocol': SiteTable(
      showRank: true,
      empty: 'No protocol data yet.',
      columns: const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Accuracy'),
        SiteColumn('Guesses', tip: 'Correct / total colour guesses'),
      ],
      rows: [
        for (final e in x.read(protocolGuessLeaderboardProvider))
          [
            x.name(e.player),
            SiteCell(pct1(e.accuracy), s: e.accuracy, tone: 'wr'),
            SiteCell('${e.correct}/${e.total}', s: e.total),
          ]
      ],
    ).toJson(),
    'seasonsTable': _seasonsTable(x.read(seasonRowsProvider)).toJson(),
  };
}

/// `seasons_table.dart`, column for column.
SiteTable _seasonsTable(List<SeasonRow> rows) {
  SiteCell named(NamedValue? v, String Function(num) fmt) => v == null
      ? const SiteCell('—')
      : SiteCell('${v.name} ${fmt(v.value)}', s: v.value);
  String pct(num v) => pct0(v.toDouble());
  String int_(num v) => '$v';
  String dec(num v) => v.toStringAsFixed(2);

  final named_ = <(String, NamedValue? Function(SeasonRow), String Function(num))>[
    ('Most games', (r) => r.mostGames, int_),
    ('MVP', (r) => r.mvp, dec),
    ('Most ПУ', (r) => r.mostKilled, int_),
    ('Top ПУ %', (r) => r.topKilledPct, pct),
    ('Most hosted', (r) => r.mostHosted, int_),
    ('Host avg +', (r) => r.hostAvgPlus, dec),
    ('Best Don', (r) => r.bestDon, pct),
    ('Best Sheriff', (r) => r.bestSheriff, pct),
    ('Best Civilian', (r) => r.bestCivilian, pct),
    ('Best Mafia', (r) => r.bestMafia, pct),
  ];

  return SiteTable(
    sortColumn: 0,
    columns: [
      const SiteColumn('Season'),
      const SiteColumn('Games'),
      const SiteColumn('City WR'),
      const SiteColumn('Mafia WR'),
      const SiteColumn('Players'),
      const SiteColumn('Main lg', tip: 'Players in the main league'),
      for (final t in TournamentType.values) SiteColumn('${t.label}s'),
      for (final (label, _, _) in named_) SiteColumn(label, numeric: false),
    ],
    rows: [
      for (final r in rows)
        [
          SiteCell('S${r.seasonId}', s: r.seasonId),
          SiteCell('${r.games}', s: r.games),
          SiteCell(pct0(r.cityWR), s: r.cityWR),
          SiteCell(pct0(r.mafiaWR), s: r.mafiaWR),
          SiteCell('${r.players}', s: r.players),
          SiteCell('${r.mainLeague}', s: r.mainLeague),
          for (final t in TournamentType.values)
            SiteCell('${r.tournaments[t] ?? 0}', s: r.tournaments[t] ?? 0),
          for (final (_, get, fmt) in named_) named(get(r), fmt),
        ]
    ],
  );
}
