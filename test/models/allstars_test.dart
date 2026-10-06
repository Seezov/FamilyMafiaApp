import 'package:family_mafia_app/models/allstars.dart';
import 'package:flutter_test/flutter_test.dart';

const _json = '''
{"events": [{
  "year": 2019, "name": "RB", "date": null, "hostLabel": "Ведучий", "host": null,
  "source": null, "gameCount": 1,
  "columns": [{"label": "Балы"}, {"label": "Ci", "tip": "Компенсація"}],
  "standings": [{"player": "A", "values": ["1", "0"]}],
  "nominations": null,
  "games": [{"firstKilled": 2, "seats": [
    {"player": "A", "role": "civilian", "add": 0.3, "bestMove": 0},
    {"player": "B", "role": "don", "add": -0.5, "bestMove": 0.4}]}]
}]}''';

void main() {
  test('parses an event with games', () {
    final e = parseAllstars(_json).single;
    expect(e.year, 2019);
    expect(e.host, isNull);
    expect(e.columns[1].tip, 'Компенсація');
    expect(e.standings.single.values, ['1', '0']);
    expect(e.nominations, isNull);
    final g = e.games.single;
    expect(g.firstKilled, 2);
    expect(g.seats[1].role, AllstarsRole.don);
    expect(g.seats[1].add, -0.5);
    expect(AllstarsRole.sheriff.isRed, isTrue);
    expect(AllstarsRole.don.isRed, isFalse);
  });

  test('a standings row with the wrong number of values names the year', () {
    final bad = _json.replaceFirst('"values": ["1", "0"]', '"values": ["1"]');
    expect(() => parseAllstars(bad),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', contains('2019'))));
  });

  test('an unknown role names the year', () {
    final bad = _json.replaceFirst('"don"', '"boss"');
    expect(() => parseAllstars(bad), throwsA(isA<FormatException>()));
  });
}
