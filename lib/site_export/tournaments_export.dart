import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// The Tournaments page: every tournament in the season config, totals per
/// type, a per-season summary and the players with the most prize places.
Map<String, Object?> tournamentsJson(ExportContext x) {
  final resolver = x.read(playerResolverProvider);
  final all = [...x.read(tournamentsProvider)];
  // Stable: config order within a season.
  final indexed = [for (var i = 0; i < all.length; i++) (i, all[i])]
    ..sort((a, b) {
      final c = a.$2.seasonId.compareTo(b.$2.seasonId);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
  final list = [for (final (_, t) in indexed) t];

  return {
    'totals': {
      'tournaments': list.length,
      'games': list.fold<int>(0, (a, t) => a + t.games),
    },
    'types': [
      for (final type in TournamentType.values)
        if (list.any((t) => t.type == type))
          {
            'type': type.name,
            'label': type.label,
            'count': list.where((t) => t.type == type).length,
            'games': list
                .where((t) => t.type == type)
                .fold<int>(0, (a, t) => a + t.games),
          }
    ],
    'winners': _winners(x, list, resolver).toJson(),
    'bySeason': _bySeason(x, list).toJson(),
    'seasons': [
      for (final s in x.seasons.reversed)
        if (list.any((t) => t.seasonId == s.id))
          {
            'id': s.id,
            'title': s.title,
            'events': [
              for (final t in list.where((t) => t.seasonId == s.id))
                {
                  'type': t.type.name,
                  'label': t.type.label,
                  'name': t.name,
                  'games': t.games,
                  'date': t.date,
                  'podium': [
                    for (final name in t.podium)
                      _podiumCell(x, resolver, name).toJson()
                  ],
                }
            ],
          }
    ],
  };
}

/// The resolved player's name, linked when the site has a page for them;
/// otherwise the name as written in the config.
SiteCell _podiumCell(ExportContext x, PlayerResolver resolver, String raw) {
  final p = resolver.resolve(raw);
  return x.slugs[p.id] == null ? SiteCell(raw) : x.name(p);
}

SiteTable _winners(
    ExportContext x, List<Tournament> list, PlayerResolver resolver) {
  final places = <String, (SiteCell, List<int>, int)>{};
  for (final t in list) {
    for (var i = 0; i < t.podium.length && i < 3; i++) {
      final p = resolver.resolve(t.podium[i]);
      final key = personKey(p);
      final (cell, counts, minicaps) = places[key] ??
          (_podiumCell(x, resolver, t.podium[i]), [0, 0, 0], 0);
      counts[i]++;
      places[key] = (
        cell,
        counts,
        minicaps + (i == 0 && t.type == TournamentType.minicap ? 1 : 0),
      );
    }
  }
  return SiteTable(
    sortColumn: 1,
    showRank: true,
    collapsed: 30,
    columns: const [
      SiteColumn('Player', numeric: false),
      SiteColumn('1st'),
      SiteColumn('2nd'),
      SiteColumn('3rd'),
      SiteColumn('Podiums'),
      SiteColumn('Minicap wins'),
    ],
    rows: [
      for (final (cell, c, minicaps) in places.values)
        [
          cell,
          // Ties on wins are broken by 2nd, then 3rd places.
          SiteCell('${c[0]}', s: c[0] * 10000 + c[1] * 100 + c[2]),
          SiteCell('${c[1]}', s: c[1]),
          SiteCell('${c[2]}', s: c[2]),
          SiteCell('${c[0] + c[1] + c[2]}', s: c[0] + c[1] + c[2]),
          SiteCell('$minicaps', s: minicaps),
        ]
    ],
  );
}

SiteTable _bySeason(ExportContext x, List<Tournament> list) {
  return SiteTable(
    sortColumn: 0,
    columns: [
      const SiteColumn('Season'),
      for (final t in TournamentType.values) SiteColumn('${t.label}s'),
      const SiteColumn('Total'),
      const SiteColumn('Games'),
    ],
    rows: [
      for (final s in x.seasons)
        [
          SiteCell('S${s.id}', s: s.id),
          for (final type in TournamentType.values)
            _count(list.where((t) => t.seasonId == s.id && t.type == type)
                .length),
          _count(list.where((t) => t.seasonId == s.id).length),
          _count(list
              .where((t) => t.seasonId == s.id)
              .fold<int>(0, (a, t) => a + t.games)),
        ]
    ],
  );
}

SiteCell _count(int n) => SiteCell(n == 0 ? '·' : '$n', s: n);
