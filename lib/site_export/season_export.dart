import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/host_stats.dart';
import 'package:family_mafia_app/services/stats/season_extra_stats.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Everything the Season tab shows for [season], both leagues.
Map<String, Object?> seasonJson(ExportContext x, SeasonConfig season) {
  final leagues = <String, Object?>{};
  for (final league in League.values) {
    x.select(season, league);
    final stats = x.read(currentSeasonStatsProvider);
    final extra = x.read(seasonExtraStatsProvider);
    leagues[league.name] = {
      'ratings': _ratings(x, season, league, stats).toJson(),
      'stats': extra == null
          ? const []
          : _statItems(x, extra, showHosts: league == League.main),
      if (league == League.main && stats != null) 'awards': _awards(x, stats),
    };
  }

  x.select(season, League.main);
  final summary = x.read(seasonSummaryProvider);
  final counts = x.read(seasonLeagueCountsProvider);
  final extra = x.read(seasonExtraStatsProvider);
  final tournaments =
      x.read(tournamentsProvider).where((t) => t.seasonId == season.id);
  return {
    'id': season.id,
    'title': season.title,
    'gameLimit': season.gameLimit,
    'smallLeagueMinGames': season.smallLeagueMinGames,
    'summary': summary == null
        ? null
        : {
            'games': summary.games,
            'players': summary.players,
            'cityWR': summary.cityWR,
            'mafiaWR': summary.mafiaWR,
          },
    'leagueCounts':
        counts == null ? null : {'main': counts.main, 'small': counts.small},
    'tournaments': [
      for (final t in tournaments)
        {
          'type': t.type.name,
          'label': t.type.label,
          'name': t.name,
          'games': t.games,
          'date': t.date,
          'podium': t.podium,
        }
    ],
    'tournamentCounts': [
      for (final MapEntry(key: type, value: count)
          in (extra?.tournaments ?? const {}).entries)
        {'type': type.name, 'label': type.label, 'count': count}
    ],
    'leagues': leagues,
  };
}

SiteTable _ratings(ExportContext x, SeasonConfig season, League league,
    SeasonStats? stats) {
  final limit = x.read(effectiveGameLimitProvider);
  final protocol = season.id >= 29;
  SiteCell signedCell(double v) => SiteCell(
        v >= 0 ? '+${v.roundTo(2)}' : '${v.roundTo(2)}',
        s: v,
        tone: v > 0 ? 'pos' : v < 0 ? 'neg' : null,
      );

  return SiteTable(
    showRank: true,
    empty: league == League.small
        ? 'No players in the ${season.smallLeagueMinGames}–${limit - 1} game range'
        : 'No players have played at least $limit games',
    columns: [
      const SiteColumn('Player', numeric: false),
      const SiteColumn('WR'),
      const SiteColumn('Rating'),
      const SiteColumn('Games', tip: 'Wins / games'),
      const SiteColumn('Add. Pts', tip: 'Additional points from the host (доп)', phone: false),
      const SiteColumn('Penalty', phone: false),
      SiteColumn(protocol ? 'Support 5' : 'Best Move', phone: false),
      const SiteColumn('MVP', phone: false),
      const SiteColumn('CI/Game', tip: 'Compensation for being killed first, per game', phone: false),
      const SiteColumn('CI', tip: 'Compensation for being killed first', phone: false),
      const SiteColumn('Death %', phone: false),
      const SiteColumn('First Killed', tip: 'ПУ — killed on the first night', phone: false),
      const SiteColumn('City Lost', tip: 'Killed first and the city lost', phone: false),
      if (protocol) ...const [
        SiteColumn('Protocol Pts', phone: false),
        SiteColumn('Guesses', tip: 'Correct / total colour guesses', phone: false),
      ],
      for (final r in kRoleOrder) ...[
        SiteColumn('W/G', group: roleLabel(r), phone: false),
        SiteColumn('±', group: roleLabel(r), tip: 'Points in this role', phone: false),
      ],
    ],
    rows: [
      for (final p in stats?.playerStats ?? const <RatingPlayerStats>[])
        [
          x.name(p.player),
          SiteCell(pct1(p.winRate), s: p.winRate, tone: 'wr'),
          SiteCell(rounded(p.ratingCoefficient, 2), s: p.ratingCoefficient),
          SiteCell('${p.wins}/${p.gamesPlayed}', s: p.gamesPlayed),
          SiteCell(rounded(p.additionalPoints, 2),
              s: p.additionalPoints, tone: p.additionalPoints > 0 ? 'pos' : null),
          SiteCell(rounded(p.penaltyPoints, 2),
              s: p.penaltyPoints, tone: p.penaltyPoints > 0 ? 'neg' : null),
          SiteCell(rounded(p.bestMovePoints, 2),
              s: p.bestMovePoints, tone: p.bestMovePoints > 0 ? 'pos' : null),
          SiteCell(rounded(p.mvp, 4), s: p.mvp),
          SiteCell(rounded(p.ciForGame, 3), s: p.ciForGame),
          SiteCell(rounded(p.ci, 3), s: p.ci),
          SiteCell('${(p.percentOfDeath * 100).roundTo(1)}%', s: p.percentOfDeath),
          SiteCell('${p.firstKilled}', s: p.firstKilled),
          SiteCell('${p.firstKilledCityLost}', s: p.firstKilledCityLost),
          if (protocol) ...[
            SiteCell(rounded(p.protocolPoints, 2), s: p.protocolPoints),
            SiteCell('${p.protocolCorrectGuesses}/${p.protocolTotalGuesses}',
                s: p.protocolTotalGuesses == 0
                    ? null
                    : p.protocolCorrectGuesses / p.protocolTotalGuesses),
          ],
          for (final r in kRoleOrder) ...[
            _roleWinsCell(p, r),
            signedCell(rolePoints(p.bestMoveAndAdditionalPointsByRole, r)),
          ],
        ]
    ],
  );
}

SiteCell _roleWinsCell(RatingPlayerStats p, Role r) {
  final games = roleCount(p.gamesForRole, r);
  final wins = roleCount(p.winByRole, r);
  return games == 0
      ? const SiteCell('–')
      : SiteCell('$wins/$games', s: wins / games, tone: 'wr');
}

/// The Season Awards card (`season_header_card.dart`), main league only.
List<Map<String, Object?>> _awards(ExportContext x, SeasonStats stats) {
  RatingPlayerStats? byId(int id) =>
      stats.playerStats.where((p) => p.player.id == id).firstOrNull;

  SiteCell seasonPts(RatingPlayerStats p) => p.gamesPlayed == 0
      ? const SiteCell('—')
      : _signedCell(p.additionalPoints / p.gamesPlayed);

  SiteCell rolePts(RatingPlayerStats p, Role role) {
    final games = roleCount(p.gamesForRole, role);
    if (games == 0) return const SiteCell('—');
    return _signedCell(rolePoints(p.bestMoveAndAdditionalPointsByRole, role) / games);
  }

  SiteCell record(RatingPlayerStats p, Role role) {
    final games = roleCount(p.gamesForRole, role);
    final wins = roleCount(p.winByRole, role);
    if (games == 0) return const SiteCell('—');
    return SiteCell('$wins/$games  ${(wins / games * 100).toStringAsFixed(1)}%',
        s: wins / games, tone: 'wr');
  }

  Map<String, Object?> award(String key, String label, List<int> ranking,
      String metric, SiteCell Function(RatingPlayerStats) points,
      SiteCell Function(RatingPlayerStats) detail) {
    final ranked = [
      for (final id in ranking)
        ?byId(id)
    ];
    final winner = ranked.firstOrNull;
    return {
      'key': key,
      'label': label,
      'winner': winner?.player.displayName ?? '—',
      if (winner != null && x.slugs[winner.player.id] != null)
        'winnerLink': x.slugs[winner.player.id],
      'table': SiteTable(
        showRank: true,
        empty: 'Nobody qualified.',
        columns: [
          const SiteColumn('Player', numeric: false),
          const SiteColumn('Avg pts'),
          SiteColumn(metric),
        ],
        rows: [
          for (final p in ranked) [x.name(p.player), points(p), detail(p)]
        ],
      ).toJson(),
    };
  }

  return [
    award('mvp', 'MVP', stats.mvpRanking, 'Score', seasonPts,
        (p) => SiteCell(p.mvp.toStringAsFixed(3), s: p.mvp)),
    award('sheriff', 'Sheriff', stats.bestSheriffRanking, 'Record',
        (p) => rolePts(p, Role.sheriff), (p) => record(p, Role.sheriff)),
    award('civilian', 'Civilian', stats.bestCivilianRanking, 'Record',
        (p) => rolePts(p, Role.civilian), (p) => record(p, Role.civilian)),
    award('mafia', 'Mafia', stats.bestMafiaRanking, 'Record',
        (p) => rolePts(p, Role.mafia), (p) => record(p, Role.mafia)),
    award('don', 'Don', stats.bestDonRanking, 'Record',
        (p) => rolePts(p, Role.don), (p) => record(p, Role.don)),
    award('mostKilled', 'Most Killed', stats.mostKilledRanking, 'Deaths',
        seasonPts, (p) => SiteCell('${p.firstKilled}', s: p.firstKilled)),
  ];
}

SiteCell _signedCell(double v) =>
    SiteCell(signed2(v), s: v, tone: v > 0 ? 'pos' : v < 0 ? 'neg' : null);

/// The Season Stats card (`season_stats_card.dart`).
List<Map<String, Object?>> _statItems(ExportContext x, SeasonExtraStats s,
    {required bool showHosts}) {
  String first<T>(List<T> l, String Function(T) f) =>
      l.isEmpty ? '—' : f(l.first);
  Map<String, Object?> item(String label, String winner, String empty,
          String a, String b, List<List<SiteCell>> rows) =>
      {
        'label': label,
        'winner': winner,
        'table': SiteTable(
          showRank: true,
          empty: empty,
          columns: [
            const SiteColumn('Player', numeric: false),
            SiteColumn(a),
            SiteColumn(b),
          ],
          rows: rows,
        ).toJson(),
      };
  final hostEmpty = 'No host hosted $kHostMinGamesForAverage+ games.';

  return [
    item(
      'Most Games',
      first(s.mostGames, (p) => '${p.player.displayName} · ${p.gamesPlayed}'),
      'No players in this league.', 'WR', 'Games',
      [
        for (final p in s.mostGames)
          [
            x.name(p.player),
            SiteCell(pct0(p.winRate), s: p.winRate, tone: 'wr'),
            SiteCell('${p.gamesPlayed}', s: p.gamesPlayed),
          ]
      ],
    ),
    item(
      'Top ПУ %',
      first(s.topFirstKilledPct,
          (p) => '${p.player.displayName} · ${pct0(p.percentOfDeath)}'),
      'No red games in this league.', 'ПУ', '% of red',
      [
        for (final p in s.topFirstKilledPct)
          [
            x.name(p.player),
            SiteCell('${p.firstKilled}/${redGames(p)}', s: p.firstKilled),
            SiteCell(pct0(p.percentOfDeath), s: p.percentOfDeath),
          ]
      ],
    ),
    if (showHosts) ...[
      item(
        'Most Hosted',
        first(s.mostHosted, (h) =>
            '${h.host.displayName} · ${h.hosted} (${s.seasonGames == 0 ? '—' : pct0(h.hosted / s.seasonGames)})'),
        'No host data for this season.', 'Share', 'Games',
        [
          for (final h in s.mostHosted)
            [
              x.name(h.host),
              s.seasonGames == 0
                  ? const SiteCell('—')
                  : SiteCell(pct0(h.hosted / s.seasonGames),
                      s: h.hosted / s.seasonGames),
              SiteCell('${h.hosted}', s: h.hosted),
            ]
        ],
      ),
      item(
        'Host avg доп',
        first(s.hostAvgPlus, (h) => '${h.host.displayName} · ${signed2(h.avgPlus)}'),
        hostEmpty, 'Games', 'Avg / game',
        [
          for (final h in s.hostAvgPlus)
            [x.name(h.host), SiteCell('${h.hosted}', s: h.hosted), _signedCell(h.avgPlus)]
        ],
      ),
      item(
        'Host avg мінус',
        first(s.hostAvgMinus, (h) => '${h.host.displayName} · ${signed2(h.avgMinus)}'),
        hostEmpty, 'Games', 'Avg / game',
        [
          for (final h in s.hostAvgMinus)
            [x.name(h.host), SiteCell('${h.hosted}', s: h.hosted), _signedCell(h.avgMinus)]
        ],
      ),
      {
        'label': 'No host',
        'winner': s.gamesWithoutHost == null
            ? 'No data'
            : '${s.gamesWithoutHost} games',
      },
    ],
  ];
}
