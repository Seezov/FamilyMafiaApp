import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tournamentsWithBundledFallback', () {
    test('remote map with no "tournaments" key falls back to the bundled json', () {
      const remote = {'seasons': []};
      const bundled = '{"seasons": [], "tournaments": [{"season": 5, "type": "minicap", "name": "m", "games": 4}]}';
      final result = tournamentsWithBundledFallback(remote, bundled);
      expect(result.single.seasonId, 5);
      expect(result.single.type, TournamentType.minicap);
    });

    test('remote map that has a "tournaments" key (even empty) is never overridden', () {
      const remote = {'seasons': [], 'tournaments': <dynamic>[]};
      const bundled = '{"seasons": [], "tournaments": [{"season": 5, "type": "minicap", "name": "m", "games": 4}]}';
      expect(tournamentsWithBundledFallback(remote, bundled), isEmpty);
    });

    test('no bundled json available: no key falls back to no tournaments', () {
      const remote = {'seasons': []};
      expect(tournamentsWithBundledFallback(remote, null), isEmpty);
    });

    test('bundled json fails to parse: falls back to no tournaments, does not throw', () {
      const remote = {'seasons': []};
      expect(tournamentsWithBundledFallback(remote, 'not json'), isEmpty);
    });
  });
}
