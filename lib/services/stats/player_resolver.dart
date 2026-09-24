import 'package:family_mafia_app/models/player.dart';

/// Maps a raw sheet name to its canonical [Player] the same way the loader
/// does (`displayName` or any nickname), with a lookup table instead of a scan.
class PlayerResolver {
  PlayerResolver(List<Player> players) {
    for (final p in players) {
      _byName.putIfAbsent(p.displayName, () => p);
      for (final n in p.nicknames ?? const <String>[]) {
        _byName.putIfAbsent(n, () => p);
      }
    }
  }

  final _byName = <String, Player>{};

  Player resolve(String raw) =>
      _byName[raw] ?? Player(id: -1, displayName: raw);
}

/// Stable identity for grouping: the player id, or the raw name for players
/// missing from players.json.
String personKey(Player p) =>
    p.id >= 0 ? 'id:${p.id}' : 'name:${p.displayName}';
