import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/overview_export.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:family_mafia_app/site_export/records_export.dart';
import 'package:family_mafia_app/site_export/season_export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Writes the site's JSON into [out], replacing whatever was there.
Future<void> writeSiteData(ProviderContainer container, Directory out) async {
  final x = ExportContext(container);
  if (out.existsSync()) out.deleteSync(recursive: true);

  void write(String path, Object? json) {
    File('${out.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  write('index.json', overviewJson(x));
  for (final season in x.seasons) {
    write('season/${season.id}.json', seasonJson(x, season));
  }
  write('players.json', playersJson(x));
  for (final p in x.players) {
    write('player/${x.slugs[p.id]}.json', playerJson(x, p));
  }
  write('records.json', recordsJson(x));
}
