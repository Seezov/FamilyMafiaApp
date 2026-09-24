import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses a season-config JSON file (same shape as `remote_config.json` and
/// `assets/raw/season_config.json`) into `SeasonConfig`s, applying the same
/// defaulting logic the app uses at runtime (`SeasonConfig.fromJson`).
List<SeasonConfig> _loadConfigFile(String path) {
  final json = File(path).readAsStringSync();
  final map = jsonDecode(json) as Map<String, dynamic>;
  final seasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  return seasons.map((e) => SeasonConfig.fromJson(e)).toList();
}

void main() {
  group('Season.smallLeagueMinGames', () {
    test('season 0 uses 8 (short first season, gameLimit 17)', () {
      expect(Season.findById(0)!.smallLeagueMinGames, 8);
    });

    test('season 6 uses 30 (doubled season)', () {
      expect(Season.findById(6)!.smallLeagueMinGames, 30);
    });

    test('seasons 12, 14 and 15 use 20', () {
      for (final id in [12, 14, 15]) {
        expect(Season.findById(id)!.smallLeagueMinGames, 20,
            reason: 'season $id');
      }
    });

    test('every other season uses 15', () {
      const overridden = {0, 6, 12, 14, 15};
      for (final season in Season.values) {
        if (overridden.contains(season.id)) continue;
        expect(season.smallLeagueMinGames, 15, reason: 'season ${season.id}');
      }
    });

    test('the lower bound is always below the game limit', () {
      for (final season in Season.values) {
        expect(season.smallLeagueMinGames, lessThan(season.gameLimit),
            reason: 'season ${season.id}');
      }
    });

    test('toConfig carries the lower bound through', () {
      expect(Season.findById(6)!.toConfig().smallLeagueMinGames, 30);
    });

    test(
        'remote_config.json and assets/raw/season_config.json agree with '
        'the Season enum for every season they share', () {
      for (final path in [
        'remote_config.json',
        'assets/raw/season_config.json',
      ]) {
        final configs = _loadConfigFile(path);
        for (final config in configs) {
          final season = Season.findById(config.id);
          if (season == null) continue; // e.g. remote-only seasons 29, 30
          expect(config.smallLeagueMinGames, season.smallLeagueMinGames,
              reason: 'season ${config.id} in $path');
        }
      }
    });
  });
}
