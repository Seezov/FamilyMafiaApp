import 'dart:math';

export 'package:family_mafia_app/enums/game_limit_rule.dart' show SeasonThreshold;
import 'package:family_mafia_app/enums/game_limit_rule.dart';
import 'package:family_mafia_app/services/stats/accomplishments.dart';

/// The sheet's «Поточний поріг»: the three highest rating-game counts,
/// averaged, × 0.6 − 5 (missing players count 0). Rounded to 6 decimals so
/// float noise never lifts an exact integer over the next `ceil`.
double formulaThreshold(Iterable<int> ratingGames) {
  final top = ratingGames.toList()..sort((a, b) => b.compareTo(a));
  final sum = top.take(3).fold(0, (s, g) => s + g);
  return (((sum / 3) * 0.6 - 5) * 1e6).round() / 1e6;
}

/// See [GameLimitRule]. A player is in the main league with
/// `gamesPlayed >= formula`, i.e. `>= ceil(formula)`.
SeasonThreshold effectiveThreshold({
  required GameLimitRule rule,
  required int? configured,
  required Iterable<int> ratingGames,
  required List<DateTime> gameDates,
  required DateTime now,
}) {
  if (rule == GameLimitRule.fixed) {
    return (gameLimit: configured!, formula: null, live: false);
  }
  final formula = formulaThreshold(ratingGames);
  final rounded = max(0, formula.ceil());
  final live = seasonInProgress(gameDates, now: now);
  return (
    gameLimit: live ? rounded : configured ?? rounded,
    formula: formula,
    live: live,
  );
}
