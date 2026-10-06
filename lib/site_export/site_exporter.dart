import 'dart:convert';
import 'dart:io';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/models/annual_event.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/services/season_data_service.dart';
import 'package:family_mafia_app/services/season_loader.dart';
import 'package:family_mafia_app/site_export/allstars_export.dart';
import 'package:family_mafia_app/site_export/annual_export.dart';
import 'package:family_mafia_app/site_export/debug_export.dart';
import 'package:family_mafia_app/site_export/export_context.dart';
import 'package:family_mafia_app/site_export/games_export.dart';
import 'package:family_mafia_app/site_export/overview_export.dart';
import 'package:family_mafia_app/site_export/players_export.dart';
import 'package:family_mafia_app/site_export/records_export.dart';
import 'package:family_mafia_app/site_export/season_export.dart' as season_export;
import 'package:family_mafia_app/site_export/tournaments_export.dart';
import 'package:family_mafia_app/site_export/unresolved_export.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Writes the site's JSON into [out], replacing whatever was there.
///
/// [seasonJson] supplies a season's raw JSON for the games pages (default: the
/// app's own bundled / cached data).
Future<void> writeSiteData(ProviderContainer container, Directory out,
    {Future<String?> Function(SeasonConfig)? seasonJson,
    List<AnnualEvent> annualEvents = const [],
    List<AllstarsEvent> allstarsEvents = const []}) async {
  final x = ExportContext(container);
  if (out.existsSync()) out.deleteSync(recursive: true);

  void write(String path, Object? json) {
    File('${out.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(json));
  }

  write('index.json', overviewJson(x));
  for (final season in x.seasons) {
    write('season/${season.id}.json', season_export.seasonJson(x, season));
  }
  // The repositories hold rating games only; the game browser shows them all,
  // so it parses each season's JSON again, the same way the loader does.
  final load = seasonJson ??
      SeasonDataService(
        sheetsService: null,
        cacheService: container.read(seasonCacheServiceProvider),
      ).loadSeasonJson;
  final resolver = x.read(playerResolverProvider);
  for (final season in x.seasons) {
    final json = await load(season);
    if (json == null) throw StateError('Season ${season.id}: no JSON for the games page');
    write('games/${season.id}.json', gamesJson(x, season, browserGames(season.id, json, resolver)));
  }
  write('players.json', playersJson(x));
  write('unresolved.json', unresolvedJson(x));
  for (final p in x.players) {
    write('player/${x.slugs[p.id]}.json', playerJson(x, p));
  }
  write('records.json', recordsJson(x));
  write('tournaments.json', tournamentsJson(x));
  write('annual.json', annualJson(x, annualEvents));
  write('allstars.json', allstarsJson(x, allstarsEvents));
  write('debug.json', debugJson(x));
}
