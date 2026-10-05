import 'dart:math';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:family_mafia_app/site_export/export_context.dart';

/// Digits/slashes/dots only, as filtered on /host/.
final _junk = RegExp(r'^[\d/\\.]+$');

/// Game names that resolve to no roster entry, for /players/edit/. The
/// loader has already replaced every resolved name with its display name.
List<Map<String, Object>> unresolvedNames(Iterable<Game> games, PlayerResolver resolver) {
  final count = <String, int>{};
  final last = <String, int>{};
  for (final g in games) {
    for (final raw in g.players) {
      final n = raw.trim();
      if (n.length < 2 || n.startsWith('_blank_') || _junk.hasMatch(n)) continue;
      if (resolver.resolve(n).id >= 0) continue;
      count[n] = (count[n] ?? 0) + 1;
      last[n] = max(last[n] ?? 0, g.seasonId);
    }
  }
  final names = count.keys.toList()
    ..sort((a, b) => count[b]!.compareTo(count[a]!) != 0 ? count[b]!.compareTo(count[a]!) : a.compareTo(b));
  return [for (final n in names) {'name': n, 'games': count[n]!, 'lastSeason': last[n]!}];
}

Map<String, Object?> unresolvedJson(ExportContext x) => {
      'names': unresolvedNames(x.read(gamesRepositoryProvider), x.read(playerResolverProvider)),
    };
