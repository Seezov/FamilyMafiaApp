part of '../chat_engine.dart';

extension _PlayerResolver on ChatEngine {
  /// Resolves a query string to a Player using fuzzy matching.
  /// Returns null if no match found. Returns first match if multiple found.
  Player? resolvePlayer(String query) {
    final matches = resolvePlayerCandidates(query);
    return matches.isEmpty ? null : matches.first;
  }

  /// Returns all candidate matches for a query string, ordered by match quality.
  List<Player> resolvePlayerCandidates(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    // 1. Exact displayName match (case-insensitive)
    final exact = players.where(
      (p) => p.displayName.toLowerCase() == q,
    ).toList();
    if (exact.isNotEmpty) return exact;

    // 2. Exact nickname match
    final byNickname = players.where(
      (p) => p.nicknames?.any((n) => n.toLowerCase() == q) ?? false,
    ).toList();
    if (byNickname.isNotEmpty) return byNickname;

    // 3. Prefix match on displayName
    final prefix = players.where(
      (p) => p.displayName.toLowerCase().startsWith(q),
    ).toList();
    if (prefix.isNotEmpty) return prefix;

    // 4. Contains match
    final contains = players.where(
      (p) => p.displayName.toLowerCase().contains(q),
    ).toList();
    if (contains.isNotEmpty) return contains;

    // 5. Nickname prefix / contains
    final nickPrefix = players.where(
      (p) => p.nicknames?.any((n) => n.toLowerCase().startsWith(q)) ?? false,
    ).toList();
    if (nickPrefix.isNotEmpty) return nickPrefix;

    final nickContains = players.where(
      (p) => p.nicknames?.any((n) => n.toLowerCase().contains(q)) ?? false,
    ).toList();
    if (nickContains.isNotEmpty) return nickContains;

    // 6. Levenshtein distance <= 2
    final fuzzy = <(Player, int)>[];
    for (final p in players) {
      final dist = _levenshtein(p.displayName.toLowerCase(), q);
      if (dist <= 2) fuzzy.add((p, dist));
    }
    if (fuzzy.isNotEmpty) {
      fuzzy.sort((a, b) => a.$2.compareTo(b.$2));
      return fuzzy.map((e) => e.$1).toList();
    }

    return [];
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final prev = List<int>.generate(b.length + 1, (i) => i);
    final curr = List<int>.filled(b.length + 1, 0);

    for (int i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,      // deletion
          curr[j - 1] + 1,  // insertion
          prev[j - 1] + cost // substitution
        ].reduce(min);
      }
      prev.setAll(0, curr);
    }
    return curr[b.length];
  }
}
