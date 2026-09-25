import 'package:family_mafia_app/navigation/app_tabs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('appTabsFor', () {
    test('web shows only the read-only stats tabs', () {
      expect(appTabsFor(isWeb: true).map((t) => t.label),
          ['Season', 'Players', 'Dashboard', 'Records']);
    });

    test('mobile keeps all six tabs in the existing order', () {
      expect(appTabsFor(isWeb: false).map((t) => t.label),
          ['Season', 'Players', 'Dashboard', 'Records', 'Chat', 'Debug']);
    });

    test('Season stays at index 0 on both platforms (other screens jump there)', () {
      expect(appTabsFor(isWeb: true).first.label, 'Season');
      expect(appTabsFor(isWeb: false).first.label, 'Season');
    });
  });

  group('visibleTabIndex', () {
    test('keeps an in-range index', () => expect(visibleTabIndex(2, 4), 2));
    test('clamps an index the platform does not have to the last tab',
        () => expect(visibleTabIndex(5, 4), 3));
    test('clamps a negative index to 0', () => expect(visibleTabIndex(-1, 4), 0));
  });
}
