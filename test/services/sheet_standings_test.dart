import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/enums/season.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Main-league top places as the club's season sheets rank them.
List<String> mainLeague(int id, int take) {
  final season = Season.values.firstWhere((s) => s.id == id);
  return seasonStandingsForTest(
    SeasonMeta(id, season.gameLimit, season.gamesMultiplier),
    File('assets/raw/players.json').readAsStringSync(),
    File('assets/raw/${season.jsonFile}').readAsStringSync(),
  )
      .where((p) => p.gamesPlayed >= season.gameLimit)
      .take(take)
      .map((p) => p.player.displayName)
      .toList();
}

void main() {
  // Ties on the coefficient, ordered by hand in the sheets.
  test('season 13: Majest above Green on 75.0, Залізний above Кори on 72.8', () {
    expect(mainLeague(13, 8).sublist(4), ['Majest', 'Green', 'Залізний', 'Кори']);
  });

  test('season 14: Хоттабыч above Floppy on 77.2', () {
    expect(mainLeague(14, 8).sublist(5), ['Хоттабич', 'Floppy', 'Green']);
  });

  test('season 15: Braun wins on 83.2; Seezov, Majest, Don`Tright on 77.2', () {
    expect(mainLeague(15, 8), [
      'Braun', 'Хоттабич', 'Floppy', 'Победун', 'Red Fox',
      'Seezov', 'Majest', 'Don`Tright',
    ]);
  });

  test('season 16: the sheet formula puts Радо above Аглая', () {
    expect(mainLeague(16, 8).sublist(5), ['Луна', 'Радо', 'Аглая']);
  });

  // The +1 correction for Железный must survive the nickname merge
  // (his rows are under the display name Залізний).
  test('season 17: Залізний second, Red Fox third', () {
    expect(mainLeague(17, 3), ['Don`Tright', 'Залізний', 'Red Fox']);
  });

  // The sheet counts a game where Бал > -1 and a win where Бал = 1.
  test('season 17: games and wins as the sheet counts them', () {
    final season = Season.values.firstWhere((s) => s.id == 17);
    final rows = seasonStandingsForTest(
      SeasonMeta(17, season.gameLimit, season.gamesMultiplier),
      File('assets/raw/players.json').readAsStringSync(),
      File('assets/raw/${season.jsonFile}').readAsStringSync(),
    );
    ({int games, int wins}) of(String name) {
      final p = rows.firstWhere((r) => r.player.displayName == name);
      return (games: p.gamesPlayed, wins: p.wins);
    }

    expect(of('Луна'), (games: 77, wins: 36)); // blank Бал on 05.03.2023
    expect(of('Найт'), (games: 118, wins: 52)); // Бал 1 in a mafia win
    expect(of('Залізний'), (games: 86, wins: 49)); // the 11.03.2023 game
  });

  test("season 18: Red Fox on the sheet's 63 games", () {
    final season = Season.values.firstWhere((s) => s.id == 18);
    final rows = seasonStandingsForTest(
      SeasonMeta(18, season.gameLimit, season.gamesMultiplier),
      File('assets/raw/players.json').readAsStringSync(),
      File('assets/raw/${season.jsonFile}').readAsStringSync(),
    );
    final fox = rows.firstWhere((r) => r.player.displayName == 'Red Fox');
    expect(fox.gamesPlayed, 63);
    expect(fox.ratingCoefficient, closeTo(60.67, 0.005));
  });

  test("season 12: Braun on 91.6, his row's own rounding", () {
    final season = Season.values.firstWhere((s) => s.id == 12);
    final rows = seasonStandingsForTest(
      SeasonMeta(12, season.gameLimit, season.gamesMultiplier),
      File('assets/raw/players.json').readAsStringSync(),
      File('assets/raw/${season.jsonFile}').readAsStringSync(),
    );
    expect(rows.firstWhere((r) => r.player.displayName == 'Braun').ratingCoefficient,
        closeTo(91.6, 1e-9));
  });

  test('season 4: the result-less 30.11.2019 game counts, as a loss', () {
    final season = Season.values.firstWhere((s) => s.id == 4);
    final rows = seasonStandingsForTest(
      SeasonMeta(4, season.gameLimit, season.gamesMultiplier),
      File('assets/raw/players.json').readAsStringSync(),
      File('assets/raw/${season.jsonFile}').readAsStringSync(),
    );
    ({int games, double rating}) of(String name) {
      final p = rows.firstWhere((r) => r.player.displayName == name);
      return (games: p.gamesPlayed, rating: p.ratingCoefficient);
    }

    expect(of('Остин').games, 80);
    expect(of('Остин').rating, closeTo(114.0, 1e-9));
    expect(of('Vamos').games, 48);
    expect(of('Vamos').rating, closeTo(97.6, 1e-9));
  });

  // Small leagues follow the club's rules, not the sheets' slips.
  group('small leagues by the rules', () {
    RatingPlayerStats row(int id, String name) {
      final season = Season.values.firstWhere((s) => s.id == id);
      return seasonStandingsForTest(
        SeasonMeta(id, season.gameLimit, season.gamesMultiplier),
        File('assets/raw/players.json').readAsStringSync(),
        File('assets/raw/${season.jsonFile}').readAsStringSync(),
      ).firstWhere((r) => r.player.displayName == name);
    }

    test('season 17: the all-civilian game does not count (sheet: 26)', () {
      expect(row(17, 'Nemo').gamesPlayed, 25);
    });

    test('season 17: Бал 1 in a mafia win is a loss (sheet counts a win)', () {
      final p = row(17, 'Капібара');
      expect(p.gamesPlayed, 51);
      expect(p.ratingCoefficient, 62.9886);
    });

    test('season 27: a seat with a blank Бал still played (sheet: 43)', () {
      expect(row(27, 'Мідас').gamesPlayed, 44);
    });

    test('season 4: the result-less game is not a game (sheet: 20)', () {
      expect(row(4, 'Joi').gamesPlayed, 19);
    });

    test('season 5: 23/40 = 0.575 rounds to 0.58, as ROUND does', () {
      expect(row(5, 'Seezov').ratingCoefficient, 66.0);
    });
  });

  // Seasons 17+ are cut into 14-row games, so one stray row would shift every
  // later game silently.
  test('bundled seasons 17-28 are whole 14-row games', () {
    for (var id = 17; id <= 28; id++) {
      final rows = (jsonDecode(File('assets/raw/season$id.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>()
          .where((r) => '${r['A'] ?? ''}'.isNotEmpty && '${r['C'] ?? ''}'.isNotEmpty)
          .toList();
      expect(rows.length % 14, 0, reason: 'season $id');
      for (var i = 0; i < rows.length; i += 14) {
        expect(rows[i]['A'], 'Дата', reason: 'season $id row $i');
        expect(rows[i + 13]['A'], 'Перемога:', reason: 'season $id row ${i + 13}');
      }
    }
  });
}
