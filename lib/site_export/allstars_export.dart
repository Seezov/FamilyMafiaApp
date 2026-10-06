import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

const _nominations = {
  NominationKind.mvp: ('🏅', 'MVP'),
  NominationKind.firstKilled: ('💀', 'Найчастіше убитий першим'),
  NominationKind.bestRed: ('👍', 'Кращий червоний'),
  NominationKind.bestMafia: ('👎', 'Краща мафія'),
};

/// The «Річні турніри» pages: every yearly all-star tournament, newest first,
/// and the players with the most podiums across them.
Map<String, Object?> allstarsJson(ExportContext x, List<AllstarsEvent> events) {
  final resolver = x.read(playerResolverProvider);
  SiteCell cell(String raw) {
    final p = resolver.resolve(raw);
    return x.slugs[p.id] == null ? SiteCell(raw) : x.name(p);
  }

  final sorted = [...events]..sort((a, b) => b.year.compareTo(a.year));
  return {
    'events': [for (final e in sorted) _event(e, cell)],
    'champions': _champions(sorted, resolver, cell).toJson(),
  };
}

Map<String, Object?> _event(AllstarsEvent e, SiteCell Function(String) cell) => {
      'year': e.year,
      'name': e.name,
      if (e.date != null) 'date': e.date,
      'hostLabel': e.hostLabel,
      if (e.host != null) 'host': e.host,
      if (e.source != null) 'source': e.source,
      'players': e.standings.length,
      'games': e.gameCount,
      'podium': [for (final s in e.standings.take(3)) cell(s.player).toJson()],
      'table': SiteTable(
        showRank: true,
        columns: [
          const SiteColumn('Гравець', numeric: false),
          for (final c in e.columns) SiteColumn(c.label, tip: c.tip),
        ],
        rows: [
          for (final s in e.standings)
            [cell(s.player), for (final v in s.values) SiteCell(v)]
        ],
      ).toJson(),
      'nominations': e.nominations != null
          ? [
              for (final n in e.nominations!)
                _nomination(NominationKind.values.byName(n.key), true, [
                  for (final r in n.top) {'player': cell(r.player).toJson(), 'value': r.value}
                ])
            ]
          : [
              for (final MapEntry(key: k, value: rows) in computeNominations(
                      e.games, [for (final s in e.standings) s.player])
                  .entries)
                _nomination(k, false, [
                  for (final r in rows)
                    {
                      'player': cell(r.player).toJson(),
                      'value': k == NominationKind.firstKilled
                          ? '${r.value.round()}'
                          : f2(r.value),
                    }
                ])
            ],
    };

Map<String, Object?> _nomination(
        NominationKind k, bool official, List<Map<String, Object?>> rows) =>
    {
      'key': k.name,
      'icon': _nominations[k]!.$1,
      'label': _nominations[k]!.$2,
      'official': official,
      'rows': rows,
    };

SiteTable _champions(List<AllstarsEvent> events, PlayerResolver resolver,
    SiteCell Function(String) cell) {
  final places = <String, (SiteCell, List<int>, List<int>)>{};
  for (final e in events) {
    for (var i = 0; i < e.standings.length && i < 3; i++) {
      final raw = e.standings[i].player;
      final key = personKey(resolver.resolve(raw));
      final (c, counts, wonYears) = places[key] ?? (cell(raw), [0, 0, 0], <int>[]);
      counts[i]++;
      if (i == 0) wonYears.add(e.year);
      places[key] = (c, counts, wonYears);
    }
  }
  return SiteTable(
    sortColumn: 1,
    showRank: true,
    columns: const [
      SiteColumn('Гравець', numeric: false),
      SiteColumn('1'),
      SiteColumn('2'),
      SiteColumn('3'),
      SiteColumn('Подіуми'),
      SiteColumn('Перемоги', numeric: false),
    ],
    rows: [
      for (final (c, n, years) in places.values)
        [
          c,
          // Ties on wins are broken by 2nd, then 3rd places.
          SiteCell('${n[0]}', s: n[0] * 10000 + n[1] * 100 + n[2]),
          SiteCell('${n[1]}', s: n[1]),
          SiteCell('${n[2]}', s: n[2]),
          SiteCell('${n[0] + n[1] + n[2]}', s: n[0] + n[1] + n[2]),
          SiteCell((years..sort()).join(', ')),
        ]
    ],
  );
}
