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

  return best.values.toList()
    ..sort((a, b) {
      final c = b.length.compareTo(a.length);
      return c != 0 ? c : a.player.displayName.compareTo(b.player.displayName);
    });
}
