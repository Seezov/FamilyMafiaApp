import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/protocol_entry.dart';
import 'package:family_mafia_app/services/firestore_games.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> seat(String player, String role,
        {double add = 0, double pen = 0, int fouls = 0}) =>
    {'player': player, 'role': role, 'fouls': fouls, 'additional': add,
     'penalty': pen, 'protocolAdditional': 0, 'protocolPenalty': 0};

Map<String, dynamic> doc({String date = '2026-12-03', int table = 1, int n = 1,
        String result = 'city'}) => {
      'season': 32, 'date': date, 'table': table, 'gameNumber': n,
      'host': 'Серпень',
      'seats': [
        seat('Німфа', 'Мирний'), seat('Таті', 'Мирний', add: 0.3),
        seat('Фенікс', 'Мирний'), seat('Green', 'Шериф', add: 0.5),
        seat('NSpace', 'Мафія'), seat('Сирник', 'Мирний', pen: -0.5, fouls: 3),
        seat('Seezov', 'Дон', add: 0.4), seat('Флекс', 'Мирний'),
        seat('Вітамінка', 'Мафія'), seat('Шпак', 'Мирний'),
      ],
      'firstKilled': 6,
      'supportFive': [1, 5, 7],
      'protocol': [
        {'slot': 6, 'version': 4, 'color': {'slot': 5, 'black': true}},
        {'slot': 2, 'version': null, 'color': null},
      ],
      'result': result,
      'comments': [],
    };

void main() {
  group('decodeFirestoreFields', () {
    test('decodes every value type used by games', () {
      final fields = {
        's': {'stringValue': 'x'},
        'i': {'integerValue': '32'},
        'd': {'doubleValue': 0.3},
        'b': {'booleanValue': true},
        'n': {'nullValue': null},
        't': {'timestampValue': '2026-12-03T20:00:00Z'},
        'a': {'arrayValue': {'values': [{'integerValue': '1'}, {'integerValue': '-5'}]}},
        'e': {'arrayValue': {}},
        'm': {'mapValue': {'fields': {'slot': {'integerValue': '5'}}}},
      };
      expect(decodeFirestoreFields(fields), {
        's': 'x', 'i': 32, 'd': 0.3, 'b': true, 'n': null,
        't': '2026-12-03T20:00:00Z', 'a': [1, -5], 'e': [], 'm': {'slot': 5},
      });
    });
  });

  group('gameFromFirestore', () {
    final g = gameFromFirestore(32, doc());

    test('seats, roles, points, fouls', () {
      expect(g.players.first, 'Німфа');
      expect(g.roles[3], 'Шериф');
      expect(g.additionalPoints![1], 0.3);
      expect(g.penaltyPoints![5], -0.5);
      expect(g.fouls![5], 3);
      expect(g.protocolAdditionalPoints, hasLength(10));
    });
    test('result → cityWon', () {
      expect(g.cityWon, true);
      expect(gameFromFirestore(32, doc(result: 'mafia')).cityWon, false);
      expect(gameFromFirestore(32, doc(result: 'unrated')).cityWon, null);
    });
    test('ОП computed for the first killed from Опорна 5', () {
      expect(g.firstKilled, 6);
      expect(g.bestMovePoints, closeTo(-0.15, 1e-9));
      expect(g.supportFive, [1, 5, 7]);
    });
    test('no first killed → 0 ОП', () {
      final d = doc()..['firstKilled'] = 0;
      expect(gameFromFirestore(32, d).bestMovePoints, 0.0);
    });
    test('protocol keeps one colour as a signed guess and the version', () {
      expect(g.protocol, [
        const ProtocolEntry(killedSlot: 6, colorGuesses: [-5], sheriffVersion: 4),
        const ProtocolEntry(killedSlot: 2),
      ]);
    });
    test('host and date', () {
      expect(g.host, 'Серпень');
      expect(g.date, DateTime.utc(2026, 12, 3));
    });
    test('is a normal game', () => expect(g.isNormalGame(), true));
  });

  group('gamesFromFirestoreSnapshot', () {
    test('sorts by date, table, game number', () {
      final games = gamesFromFirestoreSnapshot(32, {
        'format': 'firestore',
        'games': [
          doc(date: '2026-12-10', n: 1),
          doc(date: '2026-12-03', table: 2, n: 1),
          doc(date: '2026-12-03', table: 1, n: 2),
          doc(date: '2026-12-03', table: 1, n: 1),
        ],
      });
      expect(games.map((g) => g.date!.day), [3, 3, 3, 10]);
    });
    test('empty season → no games', () {
      expect(gamesFromFirestoreSnapshot(32, {'format': 'firestore', 'games': []}), isEmpty);
    });
  });

  group('season JSON dispatch', () {
    test('a firestore snapshot string parses through the loader', () {
      final json = jsonEncode({'format': 'firestore', 'games': [doc()]});
      expect(parseSeasonJsonForTest(32, json).single.host, 'Серпень');
    });
  });

  group('bad documents never break a season', () {
    test('malformed games are skipped, good ones kept', () {
      final noPlayer = doc(n: 2)..['seats'] = [for (final s in doc()['seats'] as List) Map.of(s as Map)..remove('player')];
      final badRole = doc(n: 3)..['seats'] = [for (final s in doc()['seats'] as List) {...(s as Map), 'role': 'Шпигун'}];
      final badSupport = doc(n: 4)..['supportFive'] = [11];
      final badProtocol = doc(n: 5)..['protocol'] = [{'version': 4}];
      final nineSeats = doc(n: 6)..['seats'] = (doc()['seats'] as List).sublist(0, 9);
      final games = gamesFromFirestoreSnapshot(32, {
        'format': 'firestore',
        'games': [doc(n: 1), noPlayer, badRole, badSupport, badProtocol, nineSeats],
      });
      expect(games, hasLength(1));
    });

    test('one player entered under two nicknames skips that game instead of throwing', () {
      final dup = doc(n: 2)
        ..['seats'] = [
          for (final (i, s) in (doc()['seats'] as List).indexed)
            {...(s as Map), if (i == 0) 'player': 'Малишка', if (i == 1) 'player': 'Малышка'},
        ];
      final json = jsonEncode({'format': 'firestore', 'games': [doc(n: 1), dup]});
      final rows = seasonRatingsForTest(
          const SeasonMeta(32, 40, 0.0), File('assets/raw/players.json').readAsStringSync(), json);
      expect(rows.where((r) => r.player.displayName == 'Німфа').single.gamesPlayed, 1);
    });
  });

  group('comments and table', () {
    test('maps comments to seats, slot 0 to the whole game, and the table', () {
      final d = doc(table: 2)
        ..['comments'] = [
          {'slot': 6, 'text': 'Зняв 1, заповіт зняти 10'},
          {'slot': 0, 'text': 'Закрили на 2в2'},
          {'slot': 3, 'text': '   '},
          {'slot': 4},
        ];
      final g = gameFromFirestore(32, d);
      expect(g.table, 2);
      expect(g.comments, const [
        GameComment(seats: [6], text: 'Зняв 1, заповіт зняти 10'),
        GameComment(seats: [], text: 'Закрили на 2в2'),
      ]);
      expect(g.label, isNull);
    });

    test('no comments → null', () {
      expect(gameFromFirestore(32, doc()).comments, isNull);
    });
  });
}
