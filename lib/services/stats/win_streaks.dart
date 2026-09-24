import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';

class WinStreak {
  final Player player;
  final int length;
  final int fromSeason;
  final int toSeason;

  const WinStreak({
    required this.player,
    required this.length,
    required this.fromSeason,
    required this.toSeason,
  });

  String get seasonsLabel =>
      fromSeason == toSeason ? 'S$fromSeason' : 'S$fromSeason–S$toSeason';
}

/// Each player's longest run of consecutive rating-game wins. Games are
/// ordered by season, then by their order in the season sheet; the run may
/// cross season boundaries.
List<WinStreak> bestWinStreaks(List<Game> games, PlayerResolver resolver) {
  final ordered = games.indexed.where((e) => e.$2.isRatingGame()).toList()
    ..sort((a, b) {
      final c = a.$2.seasonId.compareTo(b.$2.seasonId);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });

  final current = <String, (Player, int, int)>{}; // key → (player, len, fromSeason)
  final best = <String, WinStreak>{};
  final totalGames = <String, int>{}; // key → all-time rating games (for tie-breaks)

  void close(String key, int toSeason) {
    final cur = current.remove(key);
    if (cur == null || cur.$2 == 0) return;
    final prev = best[key];
    if (prev == null || cur.$2 > prev.length) {
      best[key] = WinStreak(player: cur.$1, length: cur.$2, fromSeason: cur.$3, toSeason: toSeason);
    }
  }

  final lastSeason = <String, int>{};
  for (final (_, g) in ordered) {
    final excluded = kExcludedPlayers[g.seasonId] ?? const <String>[];
    for (final raw in g.players) {
      if (raw.startsWith('_blank_') || excluded.contains(raw)) continue;
      final player = resolver.resolve(raw);
      final key = personKey(player);
      totalGames[key] = (totalGames[key] ?? 0) + 1;
      if (g.hasPlayerWon(raw)) {
        final cur = current[key];
        current[key] = cur == null ? (player, 1, g.seasonId) : (cur.$1, cur.$2 + 1, cur.$3);
        lastSeason[key] = g.seasonId;
      } else {
        close(key, lastSeason[key] ?? g.seasonId);
      }
    }
  }
  for (final key in current.keys.toList()) {
    close(key, lastSeason[key]!);
  }

  final entries = best.entries.toList()
    ..sort((a, b) {
      final c = b.value.length.compareTo(a.value.length);
      if (c != 0) return c;
      // Product-owner decision: a tied streak length favors the player with
      // fewer all-time rating games (the more impressive streak), before
      // falling back to name.
      final g = (totalGames[a.key] ?? 0).compareTo(totalGames[b.key] ?? 0);
      if (g != 0) return g;
      return a.value.player.displayName.compareTo(b.value.player.displayName);
    });
  return [for (final e in entries) e.value];
}
