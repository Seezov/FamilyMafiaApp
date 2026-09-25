import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/services/stats/records.dart';
import 'package:family_mafia_app/services/stats/win_streaks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RecordCategory {
  mvp('MVP'), roles('Roles'), games('Games'), hosts('Hosts'),
  firstKilled('ПУ'), penalties('Penalties'), streaks('Streaks');

  const RecordCategory(this.label);
  final String label;

  bool get hasPeriod => this == mvp || this == roles || this == hosts;
  bool get hasAllTime => this == games || this == hosts;
}

final recordCategoryProvider = StateProvider<RecordCategory>((ref) => RecordCategory.mvp);
final recordPeriodProvider = StateProvider<PointsPeriod>((ref) => PointsPeriod.modern);
final recordAllTimeProvider = StateProvider<bool>((ref) => false);
final recordRoleProvider = StateProvider<Role>((ref) => Role.don);

final recordsInputProvider = Provider<RecordsInput>((ref) => RecordsInput(
      ratings: ref.watch(ratingRepositoryProvider),
      configs: ref.watch(loadedSeasonConfigsProvider),
      games: ref.watch(gamesRepositoryProvider),
      resolver: ref.watch(playerResolverProvider),
    ));

final winStreaksProvider = Provider<List<WinStreak>>((ref) =>
    bestWinStreaks(ref.watch(gamesRepositoryProvider), ref.watch(playerResolverProvider)));
