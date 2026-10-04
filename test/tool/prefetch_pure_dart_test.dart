import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CI runs the prefetch with plain `dart run`, where Flutter (dart:ui) does not
// exist. `flutter test` would not notice a Flutter import, so walk the graph.
final _import = RegExp(r'''^\s*(?:import|export|part)\s+'([^']+)'\s*''', multiLine: true);

Set<String> _flutterImports(String entry) {
  final seen = <String>{};
  final offenders = <String>{};
  final queue = [File(entry).absolute.path];
  while (queue.isNotEmpty) {
    final path = queue.removeLast();
    if (!seen.add(path)) continue;
    for (final m in _import.allMatches(File(path).readAsStringSync())) {
      final uri = m.group(1)!;
      if (uri.startsWith('package:flutter') || uri == 'dart:ui') {
        offenders.add('$path → $uri');
      } else if (uri.startsWith('package:family_mafia_app/')) {
        queue.add(File('lib/${uri.substring('package:family_mafia_app/'.length)}').absolute.path);
      } else if (!uri.contains(':')) {
        queue.add(File('${File(path).parent.path}/$uri').absolute.path);
      }
    }
  }
  return offenders;
}

void main() {
  test('tool/prefetch_seasons.dart pulls in no Flutter library', () {
    expect(_flutterImports('tool/prefetch_seasons.dart'), isEmpty);
  });
}
