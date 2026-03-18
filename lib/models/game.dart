import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/game_values.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'game.freezed.dart';

@freezed
class Game with _$Game {
  const Game._();

  const factory Game({
    required int seasonId,
    required List<String> players,
    required List<String> roles,
    // true = city won, false = mafia won, null = non-rating game
    bool? cityWon,
    required int firstKilled,
    required double bestMovePoints,
    required List<int> bestMove,
    List<double>? additionalPoints,
    List<double>? penaltyPoints,
    List<double>? autoAdditionalPoints,
    List<double>? protocolAdditionalPoints,
    List<double>? protocolPenaltyPoints,
    List<String>? wonByPlayer,
    List<ProtocolEntry>? protocol, // ordered by kill order (index 0 = first killed)
    List<int>? supportFive, // up to 5 signed ints: abs=slot, positive=red, negative=black
  }) = _Game;

  int getPlayerSlot(String player) => players.indexOf(player);

  String getPlayerRole(String player) => roles[players.indexOf(player)];

  bool hasPlayerWon(String player) {
    if (wonByPlayer != null) {
      return GameValues.yes.sheetValues
          .contains(wonByPlayer![players.indexOf(player)]);
    }
    final won = cityWon;
    if (won == null) return false;
    final role = Role.findByValue(getPlayerRole(player));
    if (role == null) return false;
    return role.isBlack ? !won : won;
  }

  ProtocolEntry? getProtocolEntryForSlot(int slot) =>
      protocol?.cast<ProtocolEntry?>().firstWhere(
            (e) => e!.killedSlot == slot,
            orElse: () => null,
          );

  List<int> getPlayerProtocolColors(int slot) =>
      getProtocolEntryForSlot(slot)?.colorGuesses ?? [];

  bool isFirstKilled(String player) =>
      players.indexOf(player) + 1 == firstKilled;

  bool isRatingGame() => cityWon != null;

  double getPlayerAdditionalPoints(String player) =>
      additionalPoints?[players.indexOf(player)] ?? 0.0;

  double getPlayerAutoAdditionalPoints(String player) =>
      autoAdditionalPoints?[players.indexOf(player)] ?? 0.0;

  double getPlayerPenaltyPoints(String player) =>
      penaltyPoints?[players.indexOf(player)] ?? 0.0;

  double getPlayerProtocolAdditionalPoints(String player) =>
      protocolAdditionalPoints?[players.indexOf(player)] ?? 0.0;

  double getPlayerProtocolPenaltyPoints(String player) =>
      protocolPenaltyPoints?[players.indexOf(player)] ?? 0.0;

  // Validates game has correct role composition (seasons 2+)
  bool isNormalGame() {
    if (seasonId <= kOldFormatMaxSeason) return true;
    // Ignore placeholder names when checking uniqueness
    final real = players.where((p) => !p.startsWith('_blank_')).toList();
    return roles.where((r) => Role.mafia.sheetValues.contains(r)).length == 2 &&
        roles.where((r) => Role.sheriff.sheetValues.contains(r)).length == 1 &&
        roles.where((r) => Role.don.sheetValues.contains(r)).length == 1 &&
        real.length == real.toSet().length;
  }

  bool isRegularGame() =>
      wonByPlayer?.contains(GameValues.no.sheetValues.first) == true &&
      wonByPlayer!.contains(GameValues.yes.sheetValues.first);
}

extension GameListExtensions on List<Game> {
  List<Game> gamesForRole(String player, Role role) => where(
        (g) => role.sheetValues.contains(g.getPlayerRole(player)),
      ).toList();

  Set<String> getPlayersList(int seasonId) {
    final all = expand((g) => g.players).toSet();
    final excluded = kExcludedPlayers[seasonId];
    return all.where((p) {
      if (p.startsWith('_blank_')) return false;
      if (excluded != null && excluded.contains(p)) return false;
      return true;
    }).toSet();
  }
}
