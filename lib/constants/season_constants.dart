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

/// Season 21+: the spreadsheet's Штраф column holds per-foul penalty points
/// (mostly -0.3, also -0.6, -0.8, …). Before it, minuses were only negative
/// доп (-0.4/-0.5), so the Penalties records compare seasons 21+ only.
const kPenaltyColumnFirstSeason = kAutoPointsMaxSeason + 1;

/// Season 30+: CI (compensation index) was redefined. Instead of a flat bonus
/// scaled by how often a player is killed first, each first-kill loss is topped
/// up to that player's own average point value in a red-role game
/// ("CI/I" in the club spreadsheet). Seasons 17-29 keep the old formula.
const kNewCiStartSeason = 30;

/// Season 31+: ratings are counted exactly by the club's rules — no sheet pass,
/// no per-row sheet quirks, and no intermediate ROUND (WR, СІ, coefficient).
/// Values are rounded only for display. Seasons up to 30 match the sheets.
const kExactRatingStartSeason = 31;

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
/// Players the season sheet leaves out of its rating (test/placeholder entries
/// or players it never listed, e.g. Савиола in season 1, ТВЛ in season 2),
/// so they get no rating row here either.
/// Key: seasonId, Value: list of player display names to exclude.
const kExcludedPlayers = <int, List<String>>{
  0: ['Рауль'],
  1: ['Савиола'],
  2: ['ТВЛ'],
  8: ['Рауль', 'Остин'],
  9: ['Рауль'],
};

/// Games the season sheets count although they are not a regular table (two
/// mafia, a don, a sheriff), keyed by season, as (date, host). Season 17,
/// 11.03.2023: nine civilians and an empty seat, all scored as a city win —
/// the "fake win" that put Железный second in the sheet.
final kSheetCountedIrregularGames = <int, List<(DateTime, String)>>{
  17: [(DateTime.utc(2023, 3, 11), 'Braun')],
};

/// Games with no result that the season sheet still counts (seasons 4-16 count
/// a seat by its Y flag): played, and lost by every seat. Keyed by season, as
/// (date, host, seat 1). Season 4, 30.11.2019: Остин and Vamos reach 80 and 48
/// games.
final kSheetCountedUnresolvedGames = <int, List<(DateTime, String, String)>>{
  4: [(DateTime.utc(2019, 11, 30), 'Vamos', 'KozZzka')],
};

/// Seats the season sheets count for nobody, keyed by season, as (date, name
/// as written). Season 18, 11.08.2023: "Red Fox", while his rating row looks
/// up "RedFox", so the sheet has him on 63 games, not 64.
final kSheetUncountedSeats = <int, List<(DateTime, String)>>{
  18: [(DateTime.utc(2023, 8, 11), 'Red Fox')],
};

/// Rows whose Балла за игру the season sheet rounds to other than 2 places
/// (seasons 5-15), keyed by season and display name. Season 12: Braun's row
/// alone has ROUND(…;7), which gives him 91.6 instead of 91.8.
const kSheetPpgDigits = <int, Map<String, int>>{
  12: {'Braun': 7},
};

/// Season 26's rating tab rounds WR and CI/I (ROUND(…;2), ROUND(…;3)) on every
/// row but its first 21, which keep them unrounded; display names of those.
const kSheetUnroundedRows = <int, Set<String>>{
  26: {
    'Braun', 'Don`Tright', 'Seezov', 'Floppy', 'Kulav', 'Green', 'Малишка',
    'Німфа', 'Rathma', 'Таті', 'Сирник', 'Хоттабич', 'Аватар', 'Серпень',
    'Лисиця', 'Шпак', 'Фрау', 'Фенікс', 'Залізний', 'Вітамінка', 'Мідас',
  },
};

/// Main-league ties on the coefficient, in the order the season sheets list
/// them. The sheets break these by hand (neither win rate, games nor the
/// unrounded coefficient explains all of them), so they are kept verbatim.
const kSheetTieOrder = <int, List<String>>{
  13: ['Majest', 'Green', 'Залізний', 'Кори'],
  14: ['Хоттабич', 'Floppy'],
  15: ['Braun', 'Хоттабич', 'Seezov', 'Majest', 'Don`Tright'],
};

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

/// ── Small league bounds ────────────────────────────────────────────────────
/// Default lower bound (inclusive) on games played for the small league.
///
/// The upper bound is always the season's own [SeasonConfig.gameLimit], so it
/// is never stored separately. Four seasons override this default: season 0
/// uses 8 (short first season, gameLimit 17), season 6 uses 30 (doubled
/// season), and seasons 12, 14 and 15 use 20.
const kDefaultSmallLeagueMinGames = 15;
