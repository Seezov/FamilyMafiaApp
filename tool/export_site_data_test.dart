// Run with: flutter test tool/export_site_data_test.dart
// Writes the site's JSON into site/data/ (override with SITE_DATA_DIR).
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/site_export/load_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('export site data', () async {
    final container = await loadSiteContainer();
    addTearDown(container.dispose);

    final configs = container.read(loadedSeasonConfigsProvider);
    final ratings = container.read(ratingRepositoryProvider);
    expect(configs.length, greaterThan(20));
    expect(ratings.keys, containsAll(configs.map((c) => c.id)));
  }, timeout: const Timeout(Duration(minutes: 10)));
}
