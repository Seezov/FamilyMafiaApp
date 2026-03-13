import 'package:family_mafia_app/models/season_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SeasonRepository extends StateNotifier<Map<int, SeasonStats>> {
  SeasonRepository() : super(const {});

  void addSeason(int seasonId, SeasonStats stats) {
    state = {...state, seasonId: stats};
  }

  SeasonStats? getSeason(int seasonId) => state[seasonId];
}

final seasonRepositoryProvider =
    StateNotifierProvider<SeasonRepository, Map<int, SeasonStats>>(
  (ref) => SeasonRepository(),
);
