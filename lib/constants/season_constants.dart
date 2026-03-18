// ── Season format boundaries ──────────────────────────────────────────────
// The club's rating system evolved over 29+ seasons. Each boundary marks where
// the spreadsheet schema or rating formula changed. Game JSON files use
// different column layouts on each side of these boundaries.

/// Seasons 0-1: The original format. 10-column rows, simple win multipliers
/// (don/sheriff 4x, others 3x). Rating = avg win points * 100 + games * multiplier.
const kOldFormatMaxSeason = 1;

/// Seasons 2-3: Transitional format. 14-column rows introduced. Win multiplier
/// dropped to 2x for all roles. Rating = avg win points + games * multiplier.
const kMidFormatMaxSeason = 3;

/// Seasons 4-16: Stable "legacy" era. Same 14-column layout as 2-3 but win
/// multiplier = 1x, and rating formula adds winRate-based weighting.
/// Season 4 is a special case with its own coefficient formula (x100 scaling).
const kLegacyMaxSeason = 16;

/// Season 17+: New rating system. Win-by-role no longer contributes directly.
/// Rating = winRate*100 + avgWinPoints + CI + bestMove + additional + penalty.
/// Also the season where autoAdditionalPoints were introduced.
const kNewRatingStartSeason = 17;

/// Seasons 18-20: The "autoAdditionalPoints" era. Players received auto bonus
/// points (0.3 per game with auto points). Rating deducts games without auto
/// points x 0.3. Season 17 is excluded because it had a different formula.
const kAutoPointsMaxSeason = 20;

/// Seasons up to 28: No protocol data. Season 29+ added protocol entries
/// (night kill guesses) as a new data column in the spreadsheet.
const kPreProtocolMaxSeason = 28;

/// ── Game data parsing ─────────────────────────────────────────────────────
/// Each game's raw data is a fixed number of rows in the JSON. The chunk size
/// changed when the spreadsheet added metadata rows (best moves, first killed).

/// Seasons 0-16: Each game = 10 rows (one per player slot, no metadata rows).
const kOldChunkSize = 10;

/// Seasons 17+: Each game = 14 rows (10 player slots + rows for game metadata
/// like best move points, first killed, additional points).
const kNewChunkSize = 14;

/// ── Win-by-role multipliers ───────────────────────────────────────────────
/// In early seasons, winning gave bonus points scaled by role difficulty.
/// Don and Sheriff are harder to play (1 of each per game), so they got higher
/// multipliers. These multipliers feed into winPoints calculation.

/// Seasons 0-1: Don/Sheriff wins worth 4 points each.
const kWinMultiplierDonSheriffOld = 4;

/// Seasons 0-1: Civilian/Mafia wins worth 3 points each.
const kWinMultiplierOtherOld = 3;

/// Seasons 2-3: All roles worth 2 points per win.
const kWinMultiplierMid = 2;

/// Seasons 4-16: All roles worth 1 point per win.
const kWinMultiplierLegacy = 1;

/// ── CI (Compensation Index) ───────────────────────────────────────────────
/// CI compensates players who get killed first at night (first kill). Being
/// killed first removes you from the game early, hurting your stats. CI gives
/// back some rating to account for this disadvantage.

/// Seasons 17-18: Flat CI of 0.1 per game regardless of first-kill frequency.
const kCiEarlyValue = 0.1;

/// If a player's first-kill ratio (firstKilled / gamesPlayed) exceeds this
/// threshold, they get the maximum CI compensation. Value 0.399 means "killed
/// first in ~40%+ of games" -- these players need full compensation.
const kCiFirstKillThreshold = 0.399;

/// Seasons 19-20: Max CI factor. If ratio > threshold, CI = 0.4 * cityLostCount.
/// If ratio <= threshold, CI = ratio * 5/2 * 0.4 (proportional compensation).
const kCiFactorMid = 0.4;

/// Seasons 21+: Max CI for high first-kill ratio. Simplified to flat 0.5.
const kCiFactorNew = 0.5;

/// Seasons 21+: CI multiplier for proportional compensation (ratio * 1.25).
const kCiMultiplierNew = 1.25;

/// ── Player exclusions ─────────────────────────────────────────────────────
/// Some players in early seasons were test/placeholder entries that should be
/// excluded from rating calculations. These are hardcoded per season.
/// Key: seasonId, Value: list of player display names to exclude.
const kExcludedPlayers = <int, List<String>>{
  0: ['Рауль'],
  8: ['Рауль', 'Остин'],
  9: ['Рауль'],
};

/// ── Historical corrections ────────────────────────────────────────────────
/// In season 17, player "Железный" (Iron Man) had a data entry error that
/// resulted in a missing win. Rather than fix the source data, a +1 rating
/// correction was applied in the formula. This is the only per-player override.
const kIronManPlayer = 'Железный';
const kIronManBonus = 1;

/// ── Percentile & leaderboard thresholds ───────────────────────────────────
/// Role percentiles compare a player's win rate in a specific role against all
/// other players. Only players with enough games are included to avoid
/// small-sample distortions.

/// Minimum games played as a specific role to be included in that role's
/// percentile ranking (e.g., need 10+ games as Don to get a Don percentile).
const kMinRoleGames = 10;

/// Minimum total rating games across all seasons to be included in any
/// percentile calculation. 140 games ~ 2-3 full seasons of regular play.
const kMinTotalGames = 140;

/// Dashboard leaderboard: same threshold as percentiles for consistency.
const kDashboardMinRatingGames = 140;

/// Number of players shown in each dashboard leaderboard category.
const kDashboardTopN = 10;

/// ── Auto points penalty ───────────────────────────────────────────────────
/// In seasons 18-20, players received 0.3 auto additional points per game
/// where they met certain criteria. Games WITHOUT auto points are penalized
/// by deducting 0.3 per such game from the final rating.
const kAutoPointsPenaltyFactor = 0.3;
