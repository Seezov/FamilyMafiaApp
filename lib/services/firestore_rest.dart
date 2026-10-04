// Firestore REST helpers. Pure Dart on purpose: tool/prefetch_seasons.dart
// runs with plain `dart run` in CI, where Flutter is not available.

const firestoreSnapshotFormat = 'firestore';

/// Firestore REST typed values (`{"integerValue": "3"}` …) → plain JSON.
Map<String, dynamic> decodeFirestoreFields(Map<String, dynamic> fields) =>
    fields.map((k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)));

Object? _decodeValue(Map<String, dynamic> v) {
  if (v.containsKey('stringValue')) return v['stringValue'];
  if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
  if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
  if (v.containsKey('booleanValue')) return v['booleanValue'];
  if (v.containsKey('timestampValue')) return v['timestampValue'];
  if (v.containsKey('arrayValue')) {
    final values = (v['arrayValue'] as Map)['values'] as List? ?? const [];
    return values.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
  }
  if (v.containsKey('mapValue')) {
    final f = (v['mapValue'] as Map)['fields'] as Map<String, dynamic>? ?? const {};
    return decodeFirestoreFields(f);
  }
  return null; // nullValue and anything unknown
}
