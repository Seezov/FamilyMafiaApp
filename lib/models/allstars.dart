// Pure Dart: read by the site export and its tests.
import 'dart:convert';

/// A seat's role in an all-star game.
enum AllstarsRole {
  civilian,
  sheriff,
  mafia,
  don;

  bool get isRed => this == civilian || this == sheriff;
}

class AllstarsSeat {
  const AllstarsSeat(
      {required this.player, required this.role, required this.add, required this.bestMove});

  /// The name as written in the event's sheet.
  final String player;
  final AllstarsRole role;

  /// Additional points; penalties are stored negative, as in the sheets.
  final double add;

  /// Best-move points (only the first-killed seat has any).
  final double bestMove;
}

class AllstarsGame {
  const AllstarsGame({required this.firstKilled, required this.seats});

  /// Seat 1–10, or null when nobody was killed first.
  final int? firstKilled;
  final List<AllstarsSeat> seats;
}

class AllstarsColumn {
  const AllstarsColumn(this.label, {this.tip});
  final String label;
  final String? tip;
}

class AllstarsStanding {
  const AllstarsStanding(this.player, this.values);
  final String player;

  /// One display string per column, as in the source table.
  final List<String> values;
}

/// An official nomination copied from the federation's results page.
class AllstarsNomination {
  const AllstarsNomination(this.key, this.top);
  final String key;
  final List<({String player, String value})> top;
}

/// One yearly all-star tournament from `assets/raw/allstars.json`.
class AllstarsEvent {
  const AllstarsEvent({
    required this.year,
    required this.name,
    required this.date,
    required this.hostLabel,
    required this.host,
    required this.source,
    required this.gameCount,
    required this.columns,
    required this.standings,
    required this.nominations,
    required this.games,
  });

  final int year;
  final String name;
  final String? date;

  /// «Ведучий» or «Суддя».
  final String hostLabel;
  final String? host;

  /// The federation's results page, when the event is there.
  final String? source;
  final int gameCount;
  final List<AllstarsColumn> columns;

  /// The final table in its own order: index 0 is the winner.
  final List<AllstarsStanding> standings;

  /// Official nominations, or null when they are computed from [games].
  final List<AllstarsNomination>? nominations;
  final List<AllstarsGame> games;
}

const _nominationKeys = {'mvp', 'firstKilled', 'bestRed', 'bestMafia'};

List<AllstarsEvent> parseAllstars(String json) {
  final root = jsonDecode(json) as Map<String, dynamic>;
  return [
    for (final e in (root['events'] as List).cast<Map<String, dynamic>>()) _event(e)
  ];
}

AllstarsEvent _event(Map<String, dynamic> e) {
  final year = e['year'] as int;
  Never bad(String what) => throw FormatException('all-stars $year: $what');

  final columns = [
    for (final c in (e['columns'] as List).cast<Map<String, dynamic>>())
      AllstarsColumn(c['label'] as String, tip: c['tip'] as String?)
  ];
  final standings = [
    for (final s in (e['standings'] as List).cast<Map<String, dynamic>>())
      AllstarsStanding(s['player'] as String, (s['values'] as List).cast<String>())
  ];
  for (final s in standings) {
    if (s.values.length != columns.length) {
      bad('${s.player} has ${s.values.length} values for ${columns.length} columns');
    }
  }
  if (standings.isEmpty) bad('empty final table');

  final noms = e['nominations'] as List?;
  final nominations = noms == null
      ? null
      : [
          for (final n in noms.cast<Map<String, dynamic>>())
            if (_nominationKeys.contains(n['key']))
              AllstarsNomination(n['key'] as String, [
                for (final t in (n['top'] as List).cast<Map<String, dynamic>>())
                  (player: t['player'] as String, value: t['value'] as String)
              ])
            else
              bad('unknown nomination "${n['key']}"')
        ];

  AllstarsRole role(String r) => AllstarsRole.values
      .firstWhere((v) => v.name == r, orElse: () => bad('unknown role "$r"'));

  return AllstarsEvent(
    year: year,
    name: e['name'] as String,
    date: e['date'] as String?,
    hostLabel: e['hostLabel'] as String,
    host: e['host'] as String?,
    source: e['source'] as String?,
    gameCount: e['gameCount'] as int,
    columns: columns,
    standings: standings,
    nominations: nominations,
    games: [
      for (final g in (e['games'] as List).cast<Map<String, dynamic>>())
        AllstarsGame(
          firstKilled: g['firstKilled'] as int?,
          seats: [
            for (final s in (g['seats'] as List).cast<Map<String, dynamic>>())
              AllstarsSeat(
                player: s['player'] as String,
                role: role(s['role'] as String),
                add: (s['add'] as num).toDouble(),
                bestMove: (s['bestMove'] as num).toDouble(),
              )
          ],
        )
    ],
  );
}
