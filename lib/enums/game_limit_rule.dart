/// A season's effective main-league threshold: the int limit every league
/// split compares against, the formula value (top3 seasons only) and whether
/// it is still moving (season in progress). See `effectiveThreshold`.
typedef SeasonThreshold = ({int gameLimit, double? formula, bool live});

/// How a season's main-league threshold is set.
enum GameLimitRule {
  /// `gameLimit` from the config.
  fixed,

  /// The sheet's «Поточний поріг» formula while the season is played; at the
  /// end the admin's value (Firestore `config/club.gameLimits`) or the
  /// rounded-up formula.
  top3;

  static GameLimitRule parse(String? s) => s == 'top3' ? top3 : fixed;
}
