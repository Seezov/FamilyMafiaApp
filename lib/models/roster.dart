import 'dart:convert';

/// The club's player list as stored in Firestore `config/players`: ordered
/// (the app numbers players by position), each a display name plus the other
/// spellings games use. Pure Dart: the CI prefetch imports it.
class RosterEntry {
  const RosterEntry(this.name, [this.nicknames = const []]);

  final String name;
  final List<String> nicknames;

  Iterable<String> get names => [name, ...nicknames];
}

const kMaxRosterEntries = 2000;
const kMaxNicknames = 50;

/// Reads the `players` field. Throws [FormatException] on anything but a list
/// of `{name: string, nicknames?: [string]}`.
List<RosterEntry> parseRoster(Object? players) {
  if (players is! List) throw const FormatException('roster: players is not a list');
  return [
    for (final (i, p) in players.indexed)
      if (p is Map && p['name'] is String)
        RosterEntry(p['name'] as String, switch (p['nicknames']) {
          null => const [],
          final List l when l.every((n) => n is String) => l.cast<String>().toList(),
          _ => throw FormatException('roster: entry $i (${p['name']}) has a bad nicknames list'),
        })
      else
        throw FormatException('roster: entry $i has no string name'),
  ];
}

/// Lower-cased names or nicknames owned by more than one entry, sorted.
List<String> rosterClashes(List<RosterEntry> roster) {
  final owner = <String, int>{};
  final clashes = <String>{};
  for (final (i, e) in roster.indexed) {
    for (final n in e.names) {
      final k = n.toLowerCase();
      if (owner.putIfAbsent(k, () => i) != i) clashes.add(k);
    }
  }
  return clashes.toList()..sort();
}

void checkRoster(List<RosterEntry> roster) {
  if (roster.length > kMaxRosterEntries) {
    throw FormatException('roster: ${roster.length} players, the limit is $kMaxRosterEntries');
  }
  for (final e in roster) {
    if (e.nicknames.length > kMaxNicknames) {
      throw FormatException('roster: ${e.name} has ${e.nicknames.length} nicknames, the limit is $kMaxNicknames');
    }
  }
  final clashes = rosterClashes(roster);
  if (clashes.isNotEmpty) {
    throw FormatException('roster: names used by two players: ${clashes.join(', ')}');
  }
}

/// Drops every entry whose names are all claimed by earlier entries — the
/// resolver never reaches it, so stats do not change.
List<RosterEntry> dedupeRoster(List<RosterEntry> roster) {
  final seen = <String>{};
  final out = <RosterEntry>[];
  for (final e in roster) {
    final keys = e.names.map((n) => n.toLowerCase()).toList();
    if (keys.every(seen.contains)) continue;
    seen.addAll(keys);
    out.add(e);
  }
  return out;
}

List<RosterEntry> rosterFromAppJson(String json) => [
      for (final p in (jsonDecode(json) as List).cast<Map<String, dynamic>>())
        RosterEntry(p['displayName'] as String, (p['nicknames'] as List?)?.cast<String>() ?? const []),
    ];

/// The app's `players.json` shape. Empty nickname lists are left out: the app
/// hides a player whose `nicknames` is an empty list.
String rosterAppJson(List<RosterEntry> roster) => jsonEncode([
      for (final e in roster)
        {'id': 0, 'displayName': e.name, if (e.nicknames.isNotEmpty) 'nicknames': e.nicknames},
    ]);
