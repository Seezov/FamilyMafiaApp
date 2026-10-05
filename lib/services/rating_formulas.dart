import 'dart:math';

import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/services/season_loader.dart';

// ── Pure rating formula functions ─────────────────────────────────────────
// Extracted from SeasonLoaderService for reuse and testability.

/// Standings order: higher rating first. Equal ratings keep the club's sheet
/// order ([kSheetTieOrder]), and otherwise stay in input order, as the
/// Android app's stable sort left them.
List<RatingPlayerStats> sortByRating(Iterable<RatingPlayerStats> ratings) {
  final indexed = ratings.toList().asMap().entries.toList()
    ..sort((a, b) {
      final byRating = compareByRating(a.value, b.value);
      return byRating != 0 ? byRating : a.key.compareTo(b.key);
    });
  return [for (final e in indexed) e.value];
}

/// [sortByRating]'s order for two players; 0 when the sheets don't separate them.
int compareByRating(RatingPlayerStats a, RatingPlayerStats b) {
  final byRating = b.ratingCoefficient.compareTo(a.ratingCoefficient);
  if (byRating != 0) return byRating;
  final order = kSheetTieOrder[a.seasonId];
  if (order == null) return 0;
  int rank(RatingPlayerStats p) {
    final i = order.indexOf(p.player.displayName);
    return i < 0 ? order.length : i;
  }
  return rank(a).compareTo(rank(b));
}

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
    return winByRoleSum - loseByRoleSum + penaltyPoints + bestMovePoints + additionalPoints;
  }
  if (seasonId <= kMidFormatMaxSeason) {
    return winByRoleSum + additionalPoints + bestMovePoints + penaltyPoints;
  }
  if (seasonId <= kLegacyMaxSeason) {
    return winByRoleSum + additionalPoints + bestMovePoints;
  }
  return additionalPoints + autoAdditionalPoints + penaltyPoints + bestMovePoints + ci;
}

/// Whether the season sheet's row for [player] rounds WR and CI/I.
bool _sheetRowRounds(int seasonId, String player) =>
    !(kSheetUnroundedRows[seasonId]?.contains(player) ?? false);

double calculateCiForGame(
  int firstKilledCityLost,
  int firstKilled,
  int gamesPlayed,
  int seasonId, {
  String player = '',
}) {
  if (seasonId <= kLegacyMaxSeason) return 0.0;
  if (seasonId <= 18) return kCiEarlyValue;

  final r = firstKilled / gamesPlayed;
  if (seasonId <= kAutoPointsMaxSeason) {
    // The sheet's CI/I: ROUND(IF(ПУ/Ігри > 0.399; 0.4; ПУ/Ігри * 5/2 * 0.4); 3).
    return _sheetRound(
        r > kCiFirstKillThreshold ? kCiFactorMid : r * 5 / 2 * kCiFactorMid, 3);
  }
  // The sheet's CI/I: ROUND(IF(ПУ/Ігри > 0.399; 0.5; ПУ/Ігри * 1.25); 3).
  final ciForGame = r > kCiFirstKillThreshold ? kCiFactorNew : r * kCiMultiplierNew;
  return _sheetRowRounds(seasonId, player) ? _sheetRound(ciForGame, 3) : ciForGame;
}

/// A player's season CI (СІ) before season 30. Seasons 19-20 have their own
/// sheet formula, ROUND(IF(ПУ/Ігри > 0.399; 0.4 * ПУП; ПУ/Ігри * ПУП); 3);
/// otherwise it is CI/I * ПУП.
double calculateCi(
  double ciForGame,
  int firstKilledCityLost,
  int firstKilled,
  int gamesPlayed,
  int seasonId,
) {
  if (seasonId > 18 && seasonId <= kAutoPointsMaxSeason) {
    final r = firstKilled / gamesPlayed;
    return _sheetRound(
        r > kCiFirstKillThreshold
            ? kCiFactorMid * firstKilledCityLost
            : r * firstKilledCityLost,
        3);
  }
  return ciForGame * firstKilledCityLost;
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

/// [removalPoints] is the (negative) sum of removal deductions — 4 fouls or
/// disqualification — already included in [additionalPoints]/[penaltyPoints].
/// They count toward the rating but not toward MVP.
double calculateMvp(
  int seasonId,
  int gamesPlayed,
  double additionalPoints,
  double bestMovePoints,
  double penaltyPoints,
  double winPoints, {
  double removalPoints = 0.0,
}) {
  if (seasonId <= kOldFormatMaxSeason) return (winPoints / gamesPlayed).roundTo(3);
  return ((additionalPoints + bestMovePoints + penaltyPoints - removalPoints) /
          gamesPlayed)
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
    // The sheet: ROUND((Балы / Игр) * 100 + 25% * Игр), a whole number.
    return (winPoints / gamesPlayed * 100 + gamesPlayed * m).roundToDouble();
  } else if (id <= kMidFormatMaxSeason) {
    // The sheet: ROUND(ROUND(Балы / Игр; 2) + Игр * m; 2).
    return ((winPoints / gamesPlayed).roundTo(2) + gamesPlayed * m).roundTo(2);
  } else if (id == 4) {
    // The sheet: ROUND(ROUND(Балы / Игр; 2) + Игр * 0.007; 3) * 100.
    result =
        ((winPoints / gamesPlayed).roundTo(2) + gamesPlayed * m).roundTo(3) * 100;
  } else if (id < kLegacyMaxSeason) {
    final ppgDigits = kSheetPpgDigits[id]?[player] ?? 2;
    result = ((winPoints / gamesPlayed).roundTo(ppgDigits) +
                gamesPlayed * (winRate * 100).roundTo(2) / 100 * m)
            .roundTo(3) *
        100;
  } else if (id == kLegacyMaxSeason) {
    // Season 16's sheet keeps Бал/игру and WR at full precision: ROUND(…;4)*100.
    result =
        (winPoints / gamesPlayed + gamesPlayed * winRate * m).roundTo(4) * 100;
  } else {
    // Season 17+ sheets: ROUND(WR;2) (except [kSheetUnroundedRows]), then the
    // whole coefficient ROUND(…;4). Season 17's "fake win" for Железный (an
    // 11.03.2023 game with every seat a civilian) is in the season data.
    final wr = _sheetRowRounds(id, player)
        ? _sheetRound(winRate * 100, 2)
        : winRate * 100;
    final avg = winPoints / gamesPlayed;
    if (id == kNewRatingStartSeason) {
      result = wr + avg + ci + bestMovePoints + autoAdditionalPoints + additionalPoints;
    } else if (id <= kAutoPointsMaxSeason) {
      final gamesWithoutAutoPoints =
          gamesPlayed - (autoAdditionalPoints / kAutoPointsPenaltyFactor).round();
      result = wr + avg + ci + bestMovePoints + additionalPoints -
          gamesWithoutAutoPoints * kAutoPointsPenaltyFactor;
    } else {
      result = wr + avg + ci + bestMovePoints + additionalPoints + penaltyPoints;
    }
    return _sheetRound(result, 4);
  }

  return result.roundTo(3);
}

// ── Опорна 5 (ОП) — port of the season-30 sheet formula ──────────────────
// supportFive: signed slots, positive = called red, negative = called black.
// Only the first-killed player (ПУ) gets this value.

const _supportMafiaSuccess = [0.0, 0.25, 0.55, 0.9, 0.9, 0.9];
const _supportMafiaMiss = [0.0, -0.1, -0.25, -0.45, -1.45, -2.45];
const _supportCityMiss = [0.0, -0.1, -0.2, -0.35, -0.55, -0.8];

double calculateSupportFivePoints(List<int> supportFive, List<String> roles) {
  final guesses = supportFive.where((g) => g != 0).toList();
  if (guesses.isEmpty) return -0.1;
  bool isBlack(int g) =>
      Role.findByValue(roles[g.abs() - 1])?.isBlack ?? false;
  final nMaf = guesses.where((g) => g < 0).length;
  final kMaf = guesses.where((g) => g < 0 && isBlack(g)).length;
  final nCit = guesses.where((g) => g > 0).length;
  final kCit = guesses.where((g) => g > 0 && !isBlack(g)).length;
  return _supportMafiaSuccess[kMaf] +
      (_supportMafiaMiss[nMaf] - _supportMafiaMiss[kMaf]) +
      0.1 * kCit +
      (_supportCityMiss[nCit] - _supportCityMiss[kCit]);
}
