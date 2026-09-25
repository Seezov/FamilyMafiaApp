// lib/services/stats/game_points.dart
import 'dart:math';

import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/game.dart';

/// A доп of exactly -2 marks a disqualification wherever it appears in the
/// доп column (seen in seasons 4-5), not a minus the host handed out.
const kDisqualificationPoints = -2.0;

/// Points the host handed out in a game. ЛИ (2-3) and доп (4+) share the
/// `additionalPoints` column; minuses come from negative доп (4-20) and the
/// Штраф column (21+). АД, protocol points and the host's own score are
/// deliberately left out, and so are removals ([slotRemoval]): those are a
/// rule, not the host's judgement.
extension GamePoints on Game {
  double slotPlus(int slot) => max(additionalPoints?[slot] ?? 0.0, 0.0);

  double slotMinus(int slot) {
    var minus = 0.0;
    // In seasons 4+, count negative additional points (except disqualification)
    if (seasonId > kMidFormatMaxSeason) {
      final add = additionalPoints?[slot] ?? 0.0;
      if (add < 0 && add != kDisqualificationPoints) minus += add;
    }
    // Penalty column counts as minus when negative, except the 4-foul removal
    // it holds in seasons 2-3.
    final pen = seasonId > kMidFormatMaxSeason ? (penaltyPoints?[slot] ?? 0.0) : 0.0;
    if (pen < 0) minus += pen;
    return minus;
  }

  /// The rating deduction for being removed from the game: -1 for 4 fouls in
  /// the penalty column (seasons 0-3) or a -2 disqualification доп (4+).
  /// Still part of the rating, but kept out of MVP and host minuses.
  double slotRemoval(int slot) {
    if (seasonId <= kMidFormatMaxSeason) {
      return min(penaltyPoints?[slot] ?? 0.0, 0.0);
    }
    final add = additionalPoints?[slot] ?? 0.0;
    return add == kDisqualificationPoints ? add : 0.0;
  }

  double get hostPlus =>
      [for (var i = 0; i < players.length; i++) slotPlus(i)].fold(0.0, (a, b) => a + b);

  double get hostMinus =>
      [for (var i = 0; i < players.length; i++) slotMinus(i)].fold(0.0, (a, b) => a + b);
}
