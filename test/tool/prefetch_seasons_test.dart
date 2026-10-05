import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/prefetch_seasons.dart' as prefetch;

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(Uri uri) respond;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
          Future<void>? cancelFuture) async =>
      respond(options.uri);

  @override
  void close({bool force = false}) {}
}

ResponseBody _body(String body, [int status = 200]) => ResponseBody.fromString(
      body,
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

const _configUrl = 'https://config.test/remote_config.json';
const _config = '{"seasons": ['
    '{"id": 1, "title": "Season 1", "gameLimit": 30, "gamesMultiplier": 0.25, "source": "bundled", "jsonFile": "season1.json"},'
    '{"id": 28, "title": "Season 28", "gameLimit": 60, "gamesMultiplier": 0.0, "source": "remote", "spreadsheetId": "sheetA", "sheetName": "Sheet1", "range": "A:J"},'
    '{"id": 29, "title": "Season 29", "gameLimit": 60, "gamesMultiplier": 0.0, "source": "remote", "spreadsheetId": "sheetB", "sheetName": "My Sheet", "range": "A:J"}'
    '], "tournaments": []}';

Dio _dio({bool failSheetB = false}) => Dio()
  ..httpClientAdapter = _FakeAdapter((uri) {
    if (uri.host == 'config.test') return _body(_config);
    if (uri.path.contains('/sheetA/')) {
      return _body(jsonEncode({'values': [['1', 'Rathma'], ['2', 'Joi']]}));
    }
    if (uri.path.contains('/sheetB/')) {
      if (failSheetB) return _body('{"error": "quota"}', 500);
      return _body(jsonEncode({'values': [['3']]}));
    }
    return _body('{}', 404);
  });

void main() {
  late Directory out;

  setUp(() => out = Directory.systemTemp.createTempSync('prefetch_test'));
  tearDown(() => out.deleteSync(recursive: true));

  test('writes the config and every remote season in the mobile-cache format', () async {
    final ids = await prefetch.prefetchSeasons(
        dio: _dio(), apiKey: 'k', configUrl: _configUrl, outDir: out);

    expect(ids, [28, 29]);
    expect(File('${out.path}/remote_config.json').readAsStringSync(), _config);
    expect(jsonDecode(File('${out.path}/season28.json').readAsStringSync()), [
      {'A': '1', 'B': 'Rathma'},
      {'A': '2', 'B': 'Joi'},
    ]);
    expect(jsonDecode(File('${out.path}/season29.json').readAsStringSync()), [
      {'A': '3'},
    ]);
    expect(File('${out.path}/season1.json').existsSync(), isFalse,
        reason: 'bundled seasons ship in assets/raw already');
  });

  test('one failing sheet throws and leaves no partial snapshot behind', () async {
    await expectLater(
      prefetch.prefetchSeasons(
          dio: _dio(failSheetB: true), apiKey: 'k', configUrl: _configUrl, outDir: out),
      throwsA(isA<DioException>()),
    );
    expect(out.listSync(), isEmpty);
  });

  test('snapshots firestore seasons too (no API key needed for them)', () async {
    const config = '{"seasons": ['
        '{"id": 32, "title": "Season 32", "gameLimit": 40, "gamesMultiplier": 0.0, "source": "firestore", "projectId": "p1"}'
        '], "tournaments": []}';
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter((uri) {
        if (uri.host == 'config.test') return _body(config);
        if (uri.path.endsWith(':runQuery')) {
          return _body(jsonEncode([
            {'document': {'name': 'x/games/g1', 'fields': {'season': {'integerValue': '32'}}}},
          ]));
        }
        return _body('{}', 404);
      });

    final ids = await prefetch.prefetchSeasons(
        dio: dio, apiKey: 'k', configUrl: _configUrl, outDir: out);

    expect(ids, [32]);
    final snap = jsonDecode(File('${out.path}/season32.json').readAsStringSync());
    expect(snap, {'format': 'firestore', 'games': [{'id': 'g1', 'season': 32}]});
  });

  group('config/club', () {
    const clubDoc = {
      'fields': {
        'tournaments': {'arrayValue': {'values': [
          {'mapValue': {'fields': {
            'season': {'integerValue': '31'}, 'type': {'stringValue': 'minicap'},
            'name': {'stringValue': 'Cup'}, 'games': {'integerValue': '4'},
            'podium': {'arrayValue': {}},
          }}},
        ]}},
      },
    };
    const noTournaments = '{"seasons": ['
        '{"id": 1, "title": "Season 1", "gameLimit": 30, "gamesMultiplier": 0.25, "source": "bundled", "jsonFile": "season1.json"}'
        ']}';
    const withTournaments = '{"seasons": [], "tournaments": []}';

    Dio dio({required String config, required bool club}) => Dio()
      ..httpClientAdapter = _FakeAdapter((uri) {
        if (uri.host == 'config.test') return _body(config);
        if (uri.path.endsWith('/documents/config/club')) {
          return club ? _body(jsonEncode(clubDoc)) : _body('{}', 404);
        }
        return _body('{}', 404);
      });

    test('is snapshotted when it exists', () async {
      await prefetch.prefetchSeasons(
          dio: dio(config: noTournaments, club: true), apiKey: 'k', configUrl: _configUrl, outDir: out);
      expect(jsonDecode(File('${out.path}/club_config.json').readAsStringSync()), {
        'tournaments': [
          {'season': 31, 'type': 'minicap', 'name': 'Cup', 'games': 4, 'podium': []},
        ],
        'rejectedCandidates': [],
        'gameLimits': {},
      });
    });

    test('missing is fine while the config still has its tournaments', () async {
      await prefetch.prefetchSeasons(
          dio: dio(config: withTournaments, club: false), apiKey: 'k', configUrl: _configUrl, outDir: out);
      expect(File('${out.path}/club_config.json').existsSync(), isFalse);
      expect(File('${out.path}/remote_config.json').existsSync(), isTrue);
    });

    test('missing after the config lost its tournaments fails, writing nothing', () async {
      await expectLater(
        prefetch.prefetchSeasons(
            dio: dio(config: noTournaments, club: false), apiKey: 'k', configUrl: _configUrl, outDir: out),
        throwsFormatException,
      );
      expect(out.listSync(), isEmpty);
    });
  });
}
