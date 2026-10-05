import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/screens/players/players_providers.dart';
import 'package:family_mafia_app/services/stats/annual_rating.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/site_table.dart';

/// Club seasons from this one on feed the annual rating automatically; the
/// earlier years' season blocks were imported from the sheets.
const kFirstDerivedSeason = 28;

/// A «Сезон» event per finished club season: main league ranks 1…N, the
/// small league's top 5 as places 101–105, in the year the season ends.
List<AnnualEvent> derivedSeasonEvents(ExportContext x,
    {int fromSeasonId = kFirstDerivedSeason}) {
  final live = x.read(seasonsInProgressProvider);
  final dates = <int, List<DateTime>>{};
  for (final g in x.read(gamesRepositoryProvider)) {
    if (g.date != null) (dates[g.seasonId] ??= []).add(g.date!);
  }
  final out = <AnnualEvent>[];
  for (final s in x.seasons) {
    if (s.id < fromSeasonId || live.contains(s.id) || dates[s.id] == null) continue;
    List<Player> ranked(League league) {
      x.select(s, league);
      return [for (final p in x.read(currentSeasonStatsProvider)?.playerStats ?? const []) p.player];
    }

    final main = ranked(League.main);
    final small = ranked(League.small).take(5).toList();
    out.add(AnnualEvent(
      id: 'season-${s.id}',
      year: seasonYear(dates[s.id]!),
      kind: AnnualKind.season,
      name: s.title,
      results: [
        for (final (i, p) in main.indexed) AnnualResult(p.displayName, i + 1),
        for (final (i, p) in small.indexed) AnnualResult(p.displayName, 101 + i),
      ],
    ));
  }
  return out;
}

/// The Annual pages: per year, the standings and the events behind them.
Map<String, Object?> annualJson(ExportContext x, List<AnnualEvent> stored) {
  final resolver = x.read(playerResolverProvider);
  final events = [...stored, ...derivedSeasonEvents(x)];
  final years = {for (final e in events) e.year}.toList()..sort((a, b) => b.compareTo(a));
  String pts(double v) => v.toStringAsFixed(2);
  SiteCell cell(String raw) {
    final p = resolver.resolve(raw);
    return x.slugs[p.id] == null ? SiteCell(raw) : x.name(p);
  }

  return {
    'years': [
      for (final year in years)
        () {
          final ofYear = events.where((e) => e.year == year).toList()
            ..sort((a, b) {
              if (a.date == null || b.date == null) {
                if (a.date != b.date) return a.date == null ? 1 : -1;
                return a.name.compareTo(b.name);
              }
              final c = b.date!.compareTo(a.date!);
              return c != 0 ? c : a.name.compareTo(b.name);
            });
          final standings = annualStandings(ofYear,
              keyOf: (n) => personKey(resolver.resolve(n)),
              nameOf: (n) => resolver.resolve(n).displayName);
          return {
            'year': year,
            'standings': [
              for (final s in standings)
                {
                  'rank': s.rank,
                  'player': cell(s.name).toJson(),
                  'score': pts(s.score),
                  'wins': s.wins,
                  'top3': s.top3,
                  'top10': s.top10,
                  'events': s.participations,
                  'entries': [
                    for (final e in s.entries)
                      {'event': e.event.id, 'place': e.place, 'points': pts(e.points), 'counted': e.counted}
                  ],
                }
            ],
            'events': [
              for (final e in ofYear)
                {
                  'id': e.id,
                  'kind': e.kind.name,
                  'label': e.kind.label,
                  'name': e.name,
                  'date': e.date,
                  'stars': e.stars,
                  'participants': e.participants,
                  'results': [
                    for (final r in [...e.results]..sort((a, b) => a.place.compareTo(b.place)))
                      {
                        'player': cell(r.player).toJson(),
                        'place': r.place,
                        'points': pts(eventPoints(e.kind, r.place, stars: e.stars, participants: e.participants)),
                      }
                  ],
                }
            ],
          };
        }(),
    ],
  };
}
