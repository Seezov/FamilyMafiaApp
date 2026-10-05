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

Map<String, dynamic> _season(Map<String, dynamic> id) => {'mapValue': {'fields': {
      'id': id,
      'title': {'stringValue': 'Season 32'},
      'smallLeagueMinGames': {'integerValue': '15'},
      'startDate': {'stringValue': '2026-12-01'},
    }}};

void main() {
  test('reads the seasons', () async {
    final s = await _svc(200, {'fields': {'seasons': {'arrayValue': {'values': [_season({'integerValue': '32'})]}}}})
        .fetchClubSeasons('p');
    expect(s!.single.toJson(), {'id': 32, 'title': 'Season 32', 'smallLeagueMinGames': 15, 'startDate': '2026-12-01'});
  });

  test('a missing document is null', () async {
    expect(await _svc(404, {'error': {'code': 404}}).fetchClubSeasons('p'), isNull);
  });

  test('a wrong type throws FormatException', () async {
    await expectLater(
        _svc(200, {'fields': {'seasons': {'arrayValue': {'values': [_season({'stringValue': '32'})]}}}}).fetchClubSeasons('p'),
        throwsFormatException);
  });
}
