// Run with: flutter test tool/export_site_data_test.dart
// Writes the site's JSON into site/data/ (override with SITE_DATA_DIR).
// Needs the assets/prefetched/ snapshot for remote seasons — see CLAUDE.md.
import 'dart:io';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/models/annual_event.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/prefetch_paths.dart';
import 'package:family_mafia_app/site_export/load_container.dart';
import 'package:family_mafia_app/site_export/site_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export site data', () async {
    final container = await loadSiteContainer();
    addTearDown(container.dispose);
    final out = Directory(Platform.environment['SITE_DATA_DIR'] ?? 'site/data');

    // CI's prefetch always writes it; a local run without a snapshot shows
    // the derived season events only.
    final annualFile = File('$prefetchedDir/$prefetchedAnnualEventsFile');
    final annualEvents = annualFile.existsSync()
        ? parseAnnualEvents(annualFile.readAsStringSync())
        : <AnnualEvent>[];
    final allstarsEvents =
        parseAllstars(File('assets/raw/allstars.json').readAsStringSync());
    await writeSiteData(container, out,
        annualEvents: annualEvents, allstarsEvents: allstarsEvents);

    final configs = container.read(loadedSeasonConfigsProvider);
    for (final c in configs) {
      expect(File('${out.path}/season/${c.id}.json').existsSync(), isTrue);
    }
    // ignore: avoid_print
    print('Wrote ${configs.length} seasons to ${out.absolute.path}');
  }, timeout: const Timeout(Duration(minutes: 10)));
}
