import 'package:family_mafia_app/models/player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayersRepository extends StateNotifier<List<Player>> {
  PlayersRepository() : super(const []);

  void addPlayers(List<Player> players) {
    state = [...state, ...players];
  }

  // Finds a player by displayName or any nickname. Creates a placeholder if not found.
  Player findPlayer(String name) {
    return state.firstWhere(
      (p) =>
          p.displayName == name ||
          (p.nicknames?.contains(name) ?? false),
      orElse: () => Player(id: -1, displayName: name),
    );
  }
}

final playersRepositoryProvider =
    StateNotifierProvider<PlayersRepository, List<Player>>(
  (ref) => PlayersRepository(),
);
