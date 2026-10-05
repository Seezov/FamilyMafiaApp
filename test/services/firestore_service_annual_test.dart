import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:family_mafia_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.respond);
  final ResponseBody Function(Uri uri) respond;
  final seen = <Uri>[];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o.uri);
    return respond(o.uri);
  }
  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body) => ResponseBody.fromString(jsonEncode(body), 200,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

Map<String, dynamic> _doc(String id, String name) => {
      'name': 'projects/p/databases/(default)/documents/events/$id',
      'fields': {
        'year': {'integerValue': '2026'},
        'kind': {'stringValue': 'series'},
        'name': {'stringValue': name},
        'date': {'nullValue': null},
        'results': {'arrayValue': {'values': [
          {'mapValue': {'fields': {'player': {'stringValue': 'A'}, 'place': {'integerValue': '1'}}}}
        ]}},
        'updatedByEmail': {'stringValue': 'admin@x.com'},
      },
    };

void main() {
  test('reads every page and keeps only event fields', () async {
    final fake = _Fake((uri) => uri.queryParameters['pageToken'] == null
        ? _json({'documents': [_doc('a1', 'One')], 'nextPageToken': 't2'})
        : _json({'documents': [_doc('b2', 'Two')]}));
    final json = await FirestoreService(dio: Dio()..httpClientAdapter = fake).fetchAnnualEvents('p');
    final list = jsonDecode(json) as List;
    expect(list.map((e) => e['id']), ['a1', 'b2']);
    expect((list.first as Map).containsKey('updatedByEmail'), isFalse);
    expect(list.first['results'], [{'player': 'A', 'place': 1}]);
    expect(fake.seen.length, 2);
  });

  test('an empty collection is an empty list', () async {
    final fake = _Fake((_) => _json({}));
    expect(await FirestoreService(dio: Dio()..httpClientAdapter = fake).fetchAnnualEvents('p'), '[]');
  });
}
