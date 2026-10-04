import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/player_accomplishments.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/stats/player_leagues.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Profile order of the role bars (`role_distribution_section.dart`).
const _profileRoleOrder = [Role.civilian, Role.mafia, Role.sheriff, Role.don];

Map<String, Object?> _summary(ExportContext x, Player p) {
  final stats = x.read(playerStatsMapProvider)[p.displayName];
  final seasons = x
          .read(seasonGamesProvider)
          .where((e) => e.name == p.displayName)
          .firstOrNull
          ?.seasonData
          .length ??
      0;
  return {
    'id': p.id,
    'slug': x.slugs[p.id],
    'name': p.displayName,
    'initials': initials(p.displayName),
    'games': stats?.games ?? 0,
    'winRate': stats?.winRate ?? 0.0,
    'seasons': seasons,
    'latestRating': x.read(latestSeasonRatingProvider(p)),
  };
}

/// The Players tab.
Map<String, Object?> playersJson(ExportContext x) {
  final summaries = [for (final p in x.players) _summary(x, p)];
  return {
    'players': summaries,
    'table': SiteTable(
      showRank: true,
      sortColumn: 1,
      columns: const [
        SiteColumn('Player', numeric: false),
        SiteColumn('Games'),
        SiteColumn('WR'),
        SiteColumn('Seasons'),
        SiteColumn('Rating', tip: 'Rating in the latest season played', phone: false),
      ],
      rows: [
        for (final s in summaries)
          [
            SiteCell(s['name']! as String, link: s['slug'] as String?),
            SiteCell('${s['games']}', s: s['games'] as int),
            SiteCell(pct0(s['winRate']! as double),
                s: s['winRate'] as double, tone: 'wr'),
            SiteCell('${s['seasons']}', s: s['seasons'] as int),
            switch (s['latestRating']) {
              final double r => SiteCell(rounded(r, 2), s: r),
              _ => const SiteCell('—'),
            },
          ]
      ],
    ).toJson(),
  };
}

/// One player's profile.
Map<String, Object?> playerJson(ExportContext x, Player p) {
  final acc = x.read(playerAccomplishmentsProvider(p));
  final leagues = x.read(playerLeaguesProvider(p));
  final perSeason = {
    for (final e in x
            .read(seasonGamesProvider)
            .where((e) => e.name == p.displayName)
            .firstOrNull
            ?.seasonData ??
        const <SeasonEntry>[])
      e.seasonId: e.games
  };

  final roleGames = <Role, int>{};
  for (final MapEntry(key: value, value: n) in x.read(playerRoleGamesProvider(p)).entries) {
    if (Role.findByValue(value) case final r?) roleGames[r] = (roleGames[r] ?? 0) + n;
  }
  final roleWins = <Role, int>{};
  for (final MapEntry(key: value, value: n) in x.read(playerRoleWinsProvider(p)).entries) {
    if (Role.findByValue(value) case final r?) roleWins[r] = (roleWins[r] ?? 0) + n;
  }
  final totalRoleGames = roleGames.values.fold(0, (a, b) => a + b);
  final percentiles = x.read(roleWinRatePercentilesProvider(p));
  String? top(double? v) =>
      v == null ? null : 'Top ${v < 1 ? v.toStringAsFixed(1) : v.toInt()}%';

  final fk = x.read(playerFirstKillProvider(p));
  final bm = x.read(playerBestMovesProvider(p));

  return {
    ..._summary(x, p),
    'accomplishments': {
      'total': acc.sumOfNominations() + acc.mostKilled,
      'groups': _awardGroups(acc),
      'main': [acc.firsts, acc.seconds, acc.thirds],
      'small': [acc.smallFirsts, acc.smallSeconds, acc.smallThirds],
      'awards': {
        'mvp': acc.mvp,
        'sheriff': acc.bestSheriff,
        'don': acc.bestDon,
        'civilian': acc.bestCivilian,
        'mafia': acc.bestMafia,
        'killed': acc.mostKilled,
      },
      'tournaments': [
        for (final t in TournamentType.values)
          if (acc.tournamentPodiums(t) > 0)
            {
              'type': t.name,
              'label': t.label,
              'podiums': acc.tournamentPodiums(t),
              'places': acc.tournamentPlaces[t] ?? const [0, 0, 0],
            }
      ],
    },
    'timeline': [
      for (final c in x.seasons)
        {
          'seasonId': c.id,
          'title': c.title,
          'games': perSeason[c.id] ?? 0,
          'league': (leagues[c.id] ?? SeasonLeague.none).name,
        }
    ],
    'roles': [
      for (final r in _profileRoleOrder)
        if ((roleGames[r] ?? 0) > 0)
          {
            'role': r.name,
            'label': roleLabel(r),
            'games': roleGames[r],
            'wins': roleWins[r] ?? 0,
            'share': roleGames[r]! / totalRoleGames,
            'top': top(percentiles[r]),
          }
    ],
    'firstKill': {
      'total': fk.total,
      'cityLost': fk.cityLost,
      'civSherGames': fk.civSherGames,
    },
    'bestMoves': {
      'firstKilled': bm.isFirstKilled,
      'zero': bm.zeroBlacks,
      'one': bm.oneBlack,
      'two': bm.twoBlacks,
      'three': bm.threeBlacks,
    },
  };
}

const _places = ['1st', '2nd', '3rd'];
const _medals = ['gold', 'silver', 'bronze'];

/// The profile's award cards, grouped like the app's Accomplishments section:
/// one card per place or award, with where it was earned.
List<Map<String, Object?>> _awardGroups(PlayerAccomplishments acc) {
  Map<String, Object?> card(String key, String label, String icon, String tone,
          {String? kind, String? kindType}) =>
      {
        'label': label,
        'icon': icon,
        'tone': tone,
        'kind': ?kind,
        'kindType': ?kindType,
        'count': acc.where[key]?.length ?? 0,
        'where': acc.where[key] ?? const <String>[],
      };
  List<Map<String, Object?>> podium(String prefix) => [
        for (var i = 0; i < 3; i++)
          card('$prefix:$i', '${_places[i]} place', 'trophy', _medals[i]),
      ];

  final groups = [
    ('Main league', podium('main')),
    ('Small league', podium('small')),
    ('Season awards', [
      card('mvp', 'MVP', 'star', 'mvp'),
      card('sheriff', 'Best Sheriff', 'sheriff', 'sheriff'),
      card('civilian', 'Best Civilian', 'civilian', 'civilian'),
      card('mafia', 'Best Mafia', 'mafia', 'mafia'),
      card('don', 'Best Don', 'don', 'don'),
      card('killed', 'Most Killed', 'killed', 'killed'),
    ]),
    ('Tournament prize places', [
      for (final t in TournamentType.values)
        for (var i = 0; i < 3; i++)
          card('${t.name}:$i', '${_places[i]} place', 'medal', _medals[i],
              kind: t.label, kindType: t.name),
    ]),
  ];
  return [
    for (final (title, cards) in groups)
      if (cards.any((c) => (c['count'] as int) > 0))
        {
          'title': title,
          'cards': [for (final c in cards) if ((c['count'] as int) > 0) c],
        }
  ];
}
