import 'package:family_mafia_app/models/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GamesRepository extends StateNotifier<List<Game>> {
  GamesRepository() : super(const []);

  void addGames(List<Game> games) {
    state = [...state, ...games];
  }
}

final gamesRepositoryProvider =
    StateNotifierProvider<GamesRepository, List<Game>>(
  (ref) => GamesRepository(),
);
