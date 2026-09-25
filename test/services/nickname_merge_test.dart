import 'dart:io';

import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a player listed under two nicknames gets one season row', () {
    // Season 21 has both "Малишка" and "Малышка" in its games.
    final rows = seasonRatingsForTest(
      const SeasonMeta(21, 60, 0.0),
      File('assets/raw/players.json').readAsStringSync(),
      File('assets/raw/season21.json').readAsStringSync(),
    );
    final mal = rows.where((r) => r.player.displayName == 'Малишка').toList();
    expect(mal, hasLength(1));
    expect(rows.where((r) => r.player.displayName == 'Малышка'), isEmpty);
  });
}
