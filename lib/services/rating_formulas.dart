import 'dart:math';

import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/services/season_loader.dart';

// ── Pure rating formula functions ─────────────────────────────────────────
// Extracted from SeasonLoaderService for reuse and testability.

int calculateWinByRole(int seasonId, String role, int wins) {
  if (seasonId <= kOldFormatMaxSeason) {
    return isDonOrSheriff(role)
        ? wins * kWinMultiplierDonSheriffOld
        : wins * kWinMultiplierOtherOld;
  }
  if (seasonId <= kMidFormatMaxSeason) return wins * kWinMultiplierMid;
  if (seasonId <= kLegacyMaxSeason) return wins * kWinMultiplierLegacy;
  return 0;
}

bool isDonOrSheriff(String role) {
  final r = Role.findByValue(role);
  return r == Role.don || r == Role.sheriff;
}

double calculateWinPoints(
  int seasonId,
  double additionalPoints,
  double bestMovePoints,
  double penaltyPoints,
  double ci,
  double autoAdditionalPoints,
  int winByRoleSum,
  int loseByRoleSum,
) {
  if (seasonId <= kOldFormatMaxSeason) {
    return winByRoleSum - loseByRoleSum + penaltyPoints + bestMovePoints;
  }
  if (seasonId <= kMidFormatMaxSeason) {
    return winByRoleSum + additionalPoints + bestMovePoints + penaltyPoints;
  }
  if (seasonId <= kLegacyMaxSeason) {
    return winByRoleSum + additionalPoints + bestMovePoints;
  }
  return additionalPoints + autoAdditionalPoints + penaltyPoints + bestMovePoints + ci;
}

double calculateCiForGame(
  int firstKilledCityLost,
  int firstKilled,
  int gamesPlayed,
  int seasonId,
) {
  if (seasonId <= kLegacyMaxSeason) return 0.0;
  if (seasonId <= 18) return kCiEarlyValue;

  final r = firstKilled / gamesPlayed;
  if (seasonId <= kAutoPointsMaxSeason) {
    return r > kCiFirstKillThreshold
        ? kCiFactorMid * firstKilledCityLost
        : r * 5 / 2 * kCiFactorMid;
  }
  return r > kCiFirstKillThreshold ? kCiFactorNew : r * kCiMultiplierNew;
}

// ── Season 30+ CI ─────────────────────────────────────────────────────────

/// Rounds the way the club spreadsheet's ROUND() does: half away from zero,
/// after collapsing binary float noise. Sheets keeps 15 significant digits, so
/// an average stored as 0.07499999999999998 rounds to 0.08, not to 0.07.
double _sheetRound(double value, int decimals) {
  final factor = pow(10, decimals).toDouble();
  final scaled = double.parse((value * factor).toStringAsPrecision(15));
  return scaled.round() / factor;
}

/// A player's average point value in a red-role game they were not first killed
/// in — the spreadsheet's "CI/I" column. Points here are доп + пр.дод + штраф +
/// пр.штраф; ОП is deliberately excluded.
double calculateAvgRedGamePoints(List<double> redGamePoints) {
  if (redGamePoints.isEmpty) return 0.0;
  return redGamePoints.reduce((a, b) => a + b) / redGamePoints.length;
}

/// Season 30+ compensation index — the spreadsheet's "СІ" column.
///
/// Every game the player was killed first in and lost is topped up to their own
/// average red-game value. A game where they already matched or beat that
/// average pays nothing, and a game they were penalised in still pays the full
/// average rather than a bonus.
double calculateCiTopUp(
  double avgRedGamePoints,
  List<double> firstKilledLossPoints,
) {
  final target = _sheetRound(avgRedGamePoints, 2);
  var total = 0.0;
  for (final scored in firstKilledLossPoints) {
    final topUp = target - (scored > 0 ? scored : 0.0);
    if (topUp > 0) total += topUp;
  }
  return _sheetRound(total, 2);
}

double calculateMvp(
  int seasonId,
  int gamesPlayed,
  double additionalPoints,
  double bestMovePoints,
  double penaltyPoints,
  double winPoints,
) {
  if (seasonId <= kOldFormatMaxSeason) return (winPoints / gamesPlayed).roundTo(3);
  return ((additionalPoints + bestMovePoints + penaltyPoints) / gamesPlayed)
      .roundTo(4);
}

double calculateRatingCoefficient({
  required String player,
  required double winPoints,
  required int gamesPlayed,
  required double winRate,
  required double ci,
  required double bestMovePoints,
  required double additionalPoints,
  required double penaltyPoints,
  required double autoAdditionalPoints,
  required SeasonMeta season,
}) {
  final id = season.id;
  final m = season.gamesMultiplier;
  double result;

  if (id <= kOldFormatMaxSeason) {
    result = (winPoints / gamesPlayed).roundTo(2) * 100 + gamesPlayed * m;
  } else if (id <= kMidFormatMaxSeason) {
    result = winPoints / gamesPlayed + gamesPlayed * m;
  } else if (id == 4) {
    result = (winPoints / gamesPlayed + gamesPlayed * m) * 100;
  } else if (id <= kLegacyMaxSeason) {
    result = ((winPoints / gamesPlayed).roundTo(2) +
            gamesPlayed *
                (winRate * 100).roundTo(2) /
                100 *
                m)
        .roundTo(3) *
        100;
  } else if (id == kNewRatingStartSeason) {
    // Season 17: +1 correction for "Железный" (historical fake win)
    result = winRate * 100 +
        winPoints / gamesPlayed +
        ci +
        bestMovePoints +
        autoAdditionalPoints +
        additionalPoints +
        (player == kIronManPlayer ? kIronManBonus : 0);
  } else if (id <= kAutoPointsMaxSeason) {
    final gamesWithoutAutoPoints =
        gamesPlayed - (autoAdditionalPoints / kAutoPointsPenaltyFactor).round();
    result = winRate * 100 +
        winPoints / gamesPlayed +
        ci +
        bestMovePoints +
        additionalPoints -
        gamesWithoutAutoPoints * kAutoPointsPenaltyFactor;
  } else if (id < kNewCiStartSeason) {
    result = winRate * 100 +
        winPoints / gamesPlayed +
        ci +
        bestMovePoints +
        additionalPoints +
        penaltyPoints;
  } else {
    // Season 30+ mirrors the spreadsheet exactly: ROUND(WR;2) and ROUND(Бал;4).
    return _sheetRound(
      _sheetRound(winRate * 100, 2) +
          winPoints / gamesPlayed +
          ci +
          bestMovePoints +
          additionalPoints +
          penaltyPoints,
      4,
    );
  }

  return result.roundTo(3);
}
