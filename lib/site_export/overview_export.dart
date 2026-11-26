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
      for (final s in seasons) {'id': s.id, 'title': seasonTitle(s.title)}
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
        'Відсоток перемог за весь час, гравці з щонайменше $kDashboardMinRatingGames рейтинговими іграми.',
    'leaderboards': [
      for (final r in kRoleOrder)
        {
          'role': r.name,
          'label': roleLabel(r),
          'table': SiteTable(
            showRank: true,
            empty: 'Поки ніхто не проходить.',
            columns: const [
              SiteColumn('Гравець', numeric: false),
              SiteColumn('WR'),
              SiteColumn('Ігри'),
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
      empty: 'Даних протоколу ще немає.',
      columns: const [
        SiteColumn('Гравець', numeric: false),
        SiteColumn('Точність'),
        SiteColumn('Вгадування', tip: 'Вгадані / всі кольори'),
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
    ('Найбільше ігор', (r) => r.mostGames, int_),
    ('MVP', (r) => r.mvp, dec),
    ('Найбільше ПУ', (r) => r.mostKilled, int_),
    ('Найвищий % ПУ', (r) => r.topKilledPct, pct),
    ('Найбільше проведених', (r) => r.mostHosted, int_),
    ('Сер. доп ведучого', (r) => r.hostAvgPlus, dec),
    ('Кращий дон', (r) => r.bestDon, pct),
    ('Кращий шериф', (r) => r.bestSheriff, pct),
    ('Кращий мирний', (r) => r.bestCivilian, pct),
    ('Краща мафія', (r) => r.bestMafia, pct),
  ];

  return SiteTable(
    sortColumn: 0,
    columns: [
      const SiteColumn('Сезон'),
      const SiteColumn('Ігри'),
      const SiteColumn('WR міста'),
      const SiteColumn('WR мафії'),
      const SiteColumn('Гравці'),
      const SiteColumn('Вища ліга', tip: 'Гравців у вищій лізі'),
      for (final t in TournamentType.values) SiteColumn(tournamentPlural(t)),
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
