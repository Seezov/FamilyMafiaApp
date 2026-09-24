import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every JSON source of season configs, in priority order: the remote config
/// is fetched at runtime and wins, the bundled asset is the offline fallback.
/// (The `Season` enum is the last-resort fallback below both.)
const _configPaths = [
  'remote_config.json',
  'assets/raw/season_config.json',
];

/// Parses a season-config JSON file (same shape as `remote_config.json` and
/// `assets/raw/season_config.json`) into `SeasonConfig`s, applying the same
/// defaulting logic the app uses at runtime (`SeasonConfig.fromJson`).
List<SeasonConfig> _loadConfigFile(String path) {
  final json = File(path).readAsStringSync();
  final map = jsonDecode(json) as Map<String, dynamic>;
  final seasons = (map['seasons'] as List).cast<Map<String, dynamic>>();
  return seasons.map((e) => SeasonConfig.fromJson(e)).toList();
}

/// The parsed configs of one file, keyed by season id.
Map<int, SeasonConfig> _configsById(String path) {
  final configs = _loadConfigFile(path);
  final byId = {for (final c in configs) c.id: c};
  expect(byId.length, configs.length, reason: 'duplicate season id in $path');
  return byId;
}

/// The three scalars every source duplicates, as one comparable value.
({int gameLimit, double gamesMultiplier, int smallLeagueMinGames}) _fields(
  SeasonConfig config,
) =>
    (
      gameLimit: config.gameLimit,
      gamesMultiplier: config.gamesMultiplier,
      smallLeagueMinGames: config.smallLeagueMinGames,
    );

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
  });

  // Each season's numbers are duplicated across three sources: the remote
  // config (highest priority, changeable server-side with no app release), the
  // bundled asset, and the `Season` enum. These tests keep the three in step
  // and hold the small-league invariant over the sources the enum cannot.
  group('season config sources', () {
    test('the lower bound is below the game limit in every JSON config', () {
      for (final path in _configPaths) {
        for (final config in _loadConfigFile(path)) {
          expect(config.smallLeagueMinGames, lessThan(config.gameLimit),
              reason: 'season ${config.id} in $path');
        }
      }
    });

    test('both JSON sources describe exactly the same set of seasons', () {
      final idsPerFile = {
        for (final path in _configPaths) path: _configsById(path).keys.toSet(),
      };
      final [first, second] = _configPaths;
      expect(idsPerFile[first], idsPerFile[second],
          reason: 'season ids differ between $first and $second');
    });

    test('every season in the enum is present in both JSON sources', () {
      final enumIds = Season.values.map((s) => s.id).toSet();
      for (final path in _configPaths) {
        final fileIds = _configsById(path).keys.toSet();
        expect(fileIds.containsAll(enumIds), isTrue,
            reason: 'seasons ${enumIds.difference(fileIds).toList()} '
                'are missing from $path');
      }
    });

    test('the JSON sources agree with each other on every shared season', () {
      final [first, second] = _configPaths;
      final a = _configsById(first);
      final b = _configsById(second);
      for (final id in a.keys.toSet().intersection(b.keys.toSet())) {
        expect(_fields(a[id]!), _fields(b[id]!),
            reason: 'season $id differs between $first and $second');
      }
    });

    test('the JSON sources agree with the enum on every season it knows', () {
      for (final path in _configPaths) {
        final byId = _configsById(path);
        for (final season in Season.values) {
          final config = byId[season.id];
          // Presence is asserted separately; skip here so a missing season
          // reports as one failure rather than two.
          if (config == null) continue;
          expect(_fields(config), _fields(season.toConfig()),
              reason: 'season ${season.id} in $path differs from the enum');
        }
      }
      // Seasons 29-30 live only in the JSON sources; that asymmetry is allowed.
      expect(Season.findById(29), isNull);
    });

    test('both config files list the same tournaments', () {
      String tournamentsOf(String path) => jsonEncode(
          (jsonDecode(File(path).readAsStringSync()) as Map)['tournaments']);
      expect(tournamentsOf('remote_config.json'),
          tournamentsOf('assets/raw/season_config.json'));
    });
  });
}
