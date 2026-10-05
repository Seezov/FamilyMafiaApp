import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';
import 'package:family_mafia_app/services/sheet_game_extras.dart';
import 'package:flutter_test/flutter_test.dart';

List<GamesDataSeason> rows(String path) => (jsonDecode(File(path).readAsStringSync()) as List)
    .cast<Map<String, dynamic>>()
    .map(GamesDataSeason.fromJson)
    .toList();

List<GamesDataSeason> season(int id) {
  final bundled = File('assets/raw/season$id.json');
  return rows(bundled.existsSync() ? bundled.path : 'assets/prefetched/season$id.json');
}

Iterable<GameComment> allComments(List<SheetGameExtras> e) => e.expand((g) => g.comments);

GameComment? find(List<SheetGameExtras> e, String textStart) =>
    allComments(e).where((c) => c.text.startsWith(textStart)).firstOrNull;

bool hasPrefetched(int id) => File('assets/prefetched/season$id.json').existsSync();

void main() {
  group('parseSeatList', () {
    test('single, dotted, comma and spaced lists', () {
      expect(parseSeatList('6'), [6]);
      expect(parseSeatList('10'), [10]);
      expect(parseSeatList('10.0'), [10]);
      expect(parseSeatList('6.9'), [6, 9]);
      expect(parseSeatList('3,6'), [3, 6]);
      expect(parseSeatList('3, 6'), [3, 6]);
    });
    test('not seats: dates, out of range, text, empty', () {
      expect(parseSeatList('2025-05-06T21:00:00.000Z'), isNull);
      expect(parseSeatList('28'), isNull);
      expect(parseSeatList('0'), isNull);
      expect(parseSeatList('Номер'), isNull);
      expect(parseSeatList(''), isNull);
    });
  });

  group('parseCommentText', () {
    test('seat prefixes with every separator', () {
      expect(parseCommentText('3 - виграв версію'), const [GameComment(seats: [3], text: 'виграв версію')]);
      expect(parseCommentText('10. Хаотично заголосував чорних'),
          const [GameComment(seats: [10], text: 'Хаотично заголосував чорних')]);
      expect(parseCommentText('3,6 - були мирні'), const [GameComment(seats: [3, 6], text: 'були мирні')]);
      expect(parseCommentText('8-голосував дона'), const [GameComment(seats: [8], text: 'голосував дона')]);
      expect(parseCommentText('6: промах'), const [GameComment(seats: [6], text: 'промах')]);
    });
    test('one cell, several lines', () {
      expect(parseCommentText('5 0.1 ОП\n1 0.6 вписався в 9ці\n'), const [
        GameComment(seats: [5], text: '0.1 ОП'),
        GameComment(seats: [1], text: '0.6 вписався в 9ці'),
      ]);
    });
    test('no prefix or a bad seat → whole-game comment', () {
      expect(parseCommentText('Закрили на 2в2'), const [GameComment(text: 'Закрили на 2в2')]);
      expect(parseCommentText('28 атака'), const [GameComment(text: '28 атака')]);
      expect(parseCommentText('2в2 закрили'), const [GameComment(text: '2в2 закрили')]);
    });
    test('keeps < & as written and trims', () {
      expect(parseCommentText('  4 - <b>&  '), const [GameComment(seats: [4], text: '<b>&')]);
    });
  });

  group('real snapshots', () {
    test('S0: standalone note row goes to the game before it', () {
      final e = sheetGameExtras(0, season(0));
      final c = find(e, 'Ничья, всем по 1 баллу')!;
      expect(c.seats, isEmpty);
      expect(e.first.comments, isEmpty);
    });
    test('S13: sidebar note', () {
      expect(find(sheetGameExtras(13, season(13)), 'Не правильно зарахувала відстріл')!.seats, isEmpty);
    });
    test('S18: «Додаткові бали:» multi-line, host chat ignored', () {
      final e = sheetGameExtras(18, season(18));
      expect(find(e, 'виграв версію, усі заповіти')!.seats, [3]);
      expect(find(e, 'зробив хід у 9-ті')!.seats, [6]);
      expect(allComments(e).where((c) => c.text.contains('сізоу')), isEmpty);
    });
    test('S21: pairs in B/C and H/I', () {
      final e = sheetGameExtras(21, season(21));
      expect(find(e, 'играл в черных, закрыл в угадайке')!.seats, [1]);
      expect(find(e, 'играла во всех черных')!.seats, [8]);
    });
    test('S26: pair in G/H', () {
      final e = sheetGameExtras(26, season(26));
      expect(find(e, 'Стала жертвою стратегії дона')!.seats, [10]);
      expect(find(e, 'Схватив Ская за волосся')!.seats, [5]);
    });
    test('S28: a number cell turned into a date → no seats', () {
      expect(find(sheetGameExtras(28, season(28)), 'голосували в чорних без балансу')!.seats, isEmpty);
    });
    test('S29: one cell with prefixed lines, and text in B', () {
      final e = sheetGameExtras(29, season(29));
      expect(find(e, '0.1 ОП')!.seats, [5]);
      expect(find(e, '0.6 вписався в 9ці')!.seats, [1]);
      expect(find(e, 'були мирні по столу')!.seats, [3, 6]);
    }, skip: !hasPrefetched(29));
    test('S30: «6.9» number cell → two seats', () {
      expect(find(sheetGameExtras(30, season(30)), 'Закрили на 2в2')!.seats, [6, 9]);
    }, skip: !hasPrefetched(30));
    test('labels are not comments', () {
      for (final id in [19, 22, 26]) {
        final texts = allComments(sheetGameExtras(id, season(id))).map((c) => c.text);
        for (final l in ['Номер', 'Коментарі до дод балів', 'Відстріл']) {
          expect(texts, isNot(contains(l)), reason: 'S$id $l');
        }
      }
    });
  });

  group('labels and tables', () {
    test('S25: «СТІЛ 1» / «СТІЛ 2» set the table, not a label', () {
      final e = sheetGameExtras(25, season(25));
      expect(e.where((g) => g.table == 1), isNotEmpty);
      expect(e.where((g) => g.table == 2), isNotEmpty);
      expect(e.map((g) => g.label).whereType<String>().where((l) => l.toLowerCase().contains('стіл')), isEmpty);
    });
    test('S27: stacked titles join, other titles are labels', () {
      final labels = sheetGameExtras(27, season(27)).map((g) => g.label).whereType<String>().toList();
      expect(labels, contains('Класичний вечір 1 · Гра 1'));
      expect(labels, contains('ФІНАЛ МІНІКАПІВ'));
    });
    test('S20: event label', () {
      expect(sheetGameExtras(20, season(20)).map((g) => g.label), contains('Міні міні-кап'));
    });
    test('the table sticks to later games of the same date only', () {
      GamesDataSeason r(Map<String, dynamic> m) => GamesDataSeason.fromJson(m);
      final raw = [
        r({'A': 'СТІЛ 2'}),
        r({'A': 'Дата', 'B': '2025-05-01', 'C': 'Ведучий'}),
        r({'A': 'Дата', 'B': '2025-05-01', 'C': 'Ведучий'}),
        r({'A': 'Дата', 'B': '2025-05-03', 'C': 'Ведучий'}),
      ];
      expect(sheetGameExtras(25, raw).map((g) => g.table), [2, 2, null]);
    });
  });
}
