import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/services/asset_season_cache_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app's real loading pipeline, set up like the web build: no keys, no
/// network, remote seasons and the config read from the `assets/prefetched/`
/// snapshot. Resolves once every season is loaded and percentiles are final.
Future<ProviderContainer> loadSiteContainer() async {
  final container = ProviderContainer(overrides: [
    // A local `.env.json` holds real keys; the export must never use them.
    envJsonProvider.overrideWith((ref) async => const <String, String>{}),
    seasonCacheServiceProvider
        .overrideWithValue(AssetSeasonCacheService(rootBundle)),
    // The build reads firestore seasons from the prefetched snapshot too.
    firestoreServiceProvider.overrideWithValue(null),
  ]);
  await container.read(appDataProvider.future);
  await container.read(clubConfigProvider.future);
  return container;
}
