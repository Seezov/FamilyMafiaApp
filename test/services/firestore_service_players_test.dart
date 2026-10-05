import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.status, this.body);
  final int status;
  final Object body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode(body), status,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  @override
  void close({bool force = false}) {}
}

FirestoreService _svc(int status, Object body) => FirestoreService(dio: Dio()..httpClientAdapter = _Fake(status, body));

Map<String, dynamic> _entry(Map<String, dynamic> name, [List<String> nicks = const []]) => {
      'mapValue': {'fields': {
        'name': name,
        'nicknames': {'arrayValue': {'values': [for (final n in nicks) {'stringValue': n}]}},
      }},
    };

void main() {
  test('returns the app players.json shape: own name kept among nicknames, empty ones left out', () async {
    final json = await _svc(200, {'fields': {
      'players': {'arrayValue': {'values': [
        _entry({'stringValue': 'Braun'}, ['Браун']),
        _entry({'stringValue': 'Joi'}),
      ]}},
      'updatedByEmail': {'stringValue': 'a@x.com'},
    }}).fetchPlayers('p');
    expect(jsonDecode(json!), [
      {'id': 0, 'displayName': 'Braun', 'nicknames': ['Braun', 'Браун']},
      {'id': 0, 'displayName': 'Joi'},
    ]);
  });

  test('a missing document is null', () async {
    expect(await _svc(404, {'error': {'code': 404}}).fetchPlayers('p'), isNull);
  });

  test('a malformed entry or a clash throws FormatException', () async {
    await expectLater(_svc(200, {'fields': {'players': {'arrayValue': {'values': [
      _entry({'integerValue': '1'}),
    ]}}}}).fetchPlayers('p'), throwsFormatException);
    await expectLater(_svc(200, {'fields': {'players': {'arrayValue': {'values': [
      _entry({'stringValue': 'A'}, ['b']), _entry({'stringValue': 'B'}),
    ]}}}}).fetchPlayers('p'), throwsFormatException);
  });
}
