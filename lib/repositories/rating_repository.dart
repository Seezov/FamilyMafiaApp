import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RatingRepository
    extends StateNotifier<Map<int, List<RatingPlayerStats>>> {
  RatingRepository() : super(const {});

  void addRatings(Season season, List<RatingPlayerStats> ratings) {
    state = {...state, season.id: ratings};
  }

  List<RatingPlayerStats> getRatings(int seasonId) =>
      state[seasonId] ?? const [];
}

final ratingRepositoryProvider =
    StateNotifierProvider<RatingRepository, Map<int, List<RatingPlayerStats>>>(
  (ref) => RatingRepository(),
);
