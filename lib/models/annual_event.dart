// Pure Dart on purpose: tool/prefetch_seasons.dart validates Firestore events with it.
import 'dart:convert';

/// The kinds of events in the annual rating (the sheet's «Турнір», «Серія»,
/// «Марафон», «Сезон» blocks).
enum AnnualKind {
  tournament('Tournament'),
  series('Series'),
  marathon('Marathon'),
  season('Season');

  const AnnualKind(this.label);

  final String label;

  static AnnualKind parse(String v) => values.firstWhere((k) => k.name == v,
      orElse: () => throw FormatException('unknown event kind "$v"'));
}

class AnnualResult {
  const AnnualResult(this.player, this.place);

  /// The name as entered; the export resolves nicknames.
  final String player;

  /// 1-based; 101–105 are the small league's top 5 in a season event.
  final int place;
}

/// One event of the annual rating: an external tournament, series or
/// marathon entered by an admin, an imported season block, or a club season
/// derived by the export.
class AnnualEvent {
  const AnnualEvent({
    required this.id,
    required this.year,
    required this.kind,
    required this.name,
    this.date,
    this.stars,
    this.participants,
    required this.results,
  });

  final String id;
  final int year;
  final AnnualKind kind;
  final String name;

  /// `YYYY-MM-DD`, or null when unknown.
  final String? date;

  /// Tournament only.
  final int? stars;
  final int? participants;
  final List<AnnualResult> results;

  /// Throws [FormatException] naming [id] on a field the export can't use.
  factory AnnualEvent.fromJson(Map<String, dynamic> json, {required String id}) {
    Never bad(String what) => throw FormatException('event $id: $what');
    final year = json['year'];
    if (year is! int || year < 2000 || year > 2100) bad('year');
    final AnnualKind kind;
    try {
      kind = AnnualKind.parse('${json['kind']}');
    } on FormatException {
      bad('kind');
    }
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) bad('name');
    final date = json['date'];
    if (date != null && date is! String) bad('date');
    final stars = json['stars'];
    final participants = json['participants'];
    if (kind == AnnualKind.tournament) {
      if (stars is! int || stars < 0 || stars > 5) bad('stars');
      if (participants is! int || participants < 1) bad('participants');
    }
    final raw = json['results'];
    if (raw is! List) bad('results');
    final results = <AnnualResult>[];
    for (final (i, r) in raw.indexed) {
      if (r is! Map || r['player'] is! String || (r['player'] as String).trim().isEmpty ||
          r['place'] is! int || (r['place'] as int) < 1) {
        bad('result #$i');
      }
      results.add(AnnualResult((r['player'] as String).trim(), r['place'] as int));
    }
    return AnnualEvent(
      id: id,
      year: year,
      kind: kind,
      name: name.trim(),
      date: date as String?,
      stars: kind == AnnualKind.tournament ? stars as int : null,
      participants: kind == AnnualKind.tournament ? participants as int : null,
      results: results,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'year': year,
        'kind': kind.name,
        'name': name,
        'date': date,
        'stars': stars,
        'participants': participants,
        'results': [for (final r in results) {'player': r.player, 'place': r.place}],
      };
}

/// The prefetch snapshot: a JSON list of events, each with its document `id`.
List<AnnualEvent> parseAnnualEvents(String json) {
  final list = jsonDecode(json);
  if (list is! List) throw const FormatException('annual events: not a list');
  return [
    for (final (i, e) in list.indexed)
      if (e is Map<String, dynamic> && e['id'] is String)
        AnnualEvent.fromJson(e, id: e['id'] as String)
      else
        throw FormatException('annual events: entry #$i has no id'),
  ];
}
