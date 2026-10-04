import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/services/stats/tournament_review.dart';
import 'package:family_mafia_app/site_export/export_context.dart';

/// Rows of a tournament table shown on the Debug page.
const _standingRows = 10;

/// The Debug page: every tournament in the config with the games behind it,
/// plus tournament-like evenings the config doesn't have yet.
Map<String, Object?> debugJson(ExportContext x) {
  final resolver = x.read(playerResolverProvider);
  final games = x.read(gamesRepositoryProvider);
  final tournaments = x.read(tournamentsProvider);
  final evenings = detectEvenings(games);

  Map<String, Object?> evidence(List<Game> gs) {
    final evening = DetectedEvening(gs.first.seasonId, gs);
    return {
      'games': gs.length,
      'dates': [for (final d in evening.dates) _day(d)],
      'hosts': evening.hosts,
      'standings': [
        for (final s in tournamentStandings(gs, resolver).take(_standingRows))
          {
            ...x.name(s.player).toJson(),
            'pts': double.parse(s.points.toStringAsFixed(2)),
            'w': s.wins,
            'g': s.games,
          },
      ],
    };
  }

  String display(String raw) => resolver.resolve(raw).displayName;

  return {
    'repo': {
      'owner': 'Seezov',
      'name': 'FamilyMafiaApp',
      'branch': 'feature/flutter_migration',
      'files': ['remote_config.json', 'assets/raw/season_config.json'],
    },
    'types': [
      for (final t in TournamentType.values) {'type': t.name, 'label': t.label},
    ],
    'tournaments': [
      for (final t in tournaments)
        () {
          final gs = tournamentGames(t, games);
          final ev = gs.isEmpty ? null : evidence(gs);
          final top = gs.isEmpty
              ? null
              : [
                  for (final s in tournamentStandings(gs, resolver).take(3))
                    s.player.displayName,
                ];
          return {
            'key': _key(t.seasonId, t.name),
            'season': t.seasonId,
            'type': t.type.name,
            'name': t.name,
            'games': t.games,
            'date': t.date,
            'podium': t.podium,
            'status': t.status ?? 'sheet',
            'evidence': ev,
            // Null when there are no games to check against.
            'podiumMatches': top == null
                ? null
                : _sameList(top, t.podium.map(display).toList()),
          };
        }(),
    ],
    'candidates': [
      for (final e in evenings)
        if (!tournaments.any((t) => eveningMatches(e, t)))
          {
            'id': e.id,
            'season': e.seasonId,
            'suggested': _suggest(e, resolver),
            'evidence': evidence(e.games),
          },
    ],
  };
}

String _key(int season, String name) => '$season|$name';

String _day(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
String _two(int n) => n.toString().padLeft(2, '0');

bool _sameList(List<String> a, List<String> b) =>
    a.length == b.length &&
    [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((e) => e);

/// A config entry for [e]: a minicap up to 6 games, otherwise a marathon.
Map<String, Object?> _suggest(DetectedEvening e, PlayerResolver resolver) {
  final dates = e.dates;
  final date = dates.isEmpty
      ? null
      : dates.length == 1
      ? _day(dates.first)
      : '${_day(dates.first)}–${_day(dates.last)}';
  final type = e.games.length <= 6
      ? TournamentType.minicap
      : TournamentType.marathon;
  return {
    'type': type.name,
    'name':
        '${type == TournamentType.minicap ? 'Мінікап' : 'Марафон'}'
        '${dates.isEmpty ? '' : ' ${_day(dates.first)}'}',
    'games': e.games.length,
    'date': date,
    'podium': [
      for (final s in tournamentStandings(e.games, resolver).take(3))
        s.player.displayName,
    ],
  };
}
