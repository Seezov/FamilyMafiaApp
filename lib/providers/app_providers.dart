import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads all season data from assets. Watch this provider to know when the
/// app data is ready. Throws on JSON/logic errors.
final appDataProvider = FutureProvider<void>((ref) async {
  final loader = SeasonLoaderService(
    ref.read(playersRepositoryProvider.notifier),
    ref.read(gamesRepositoryProvider.notifier),
    ref.read(ratingRepositoryProvider.notifier),
    ref.read(seasonRepositoryProvider.notifier),
  );
  await loader.loadAll();
});
