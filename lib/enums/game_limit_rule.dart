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
