import 'package:family_mafia_app/screens/debug/debug_providers.dart';
import 'package:family_mafia_app/services/html_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

SlotRoleRow _row(int slot, int played, int wins) => (
      slot: slot,
      cells: {
        for (final r in kMatrixRoles)
          r: (
            played: played,
            wins: wins,
            winRate: played == 0 ? 0.0 : wins / played,
          ),
      },
    );

StatsExportData _data({
  List<SlotRoleRow>? globalMatrix,
  List<PlayerMatrix>? players,
}) =>
    (
      generatedAt: DateTime(2026, 7, 15, 10, 30),
      globalMatrix: globalMatrix ?? [_row(1, 4, 2)],
      players: players ?? const [],
    );

void main() {
  group('buildStatsHtml', () {
    test('produces a self-contained HTML document', () {
      final html = buildStatsHtml(_data());
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<style>'));
      // Self-contained: no external stylesheet references.
      expect(html, isNot(contains('<link')));
      expect(html, isNot(contains('src=')));
      expect(html.trim(), endsWith('</html>'));
    });

    test('renders the global slot/role matrix with a per-slot total column',
        () {
      final html = buildStatsHtml(_data(globalMatrix: [_row(3, 10, 5)]));
      expect(html, contains('<th>Total</th>'));
      expect(html, contains('Slot 3'));
      // Each of 4 roles has 5/10; the total sums to 20/40.
      expect(html, contains('20/40'));
      expect(html, contains('50.0%'));
    });

    test('renders empty matrix cells as a dash', () {
      final html = buildStatsHtml(_data(globalMatrix: [_row(2, 0, 0)]));
      expect(html, contains('class="dim">—'));
    });

    test('includes a player search field', () {
      final html = buildStatsHtml(_data());
      expect(html, contains('id="search"'));
      expect(html, contains('list="players"'));
    });

    test('embeds each player as a datalist option and in the JSON data', () {
      final html = buildStatsHtml(_data(players: [
        (name: 'Seezov', matrix: [_row(1, 8, 6)]),
      ]));
      expect(html, contains('<option value="Seezov">'));
      expect(html, contains('var DATA='));
      // Player matrix embedded as [played, wins] pairs.
      expect(html, contains('"Seezov"'));
      expect(html, contains('[8,6]'));
    });

    test('escapes HTML-special characters in player option names', () {
      final html = buildStatsHtml(_data(players: [
        (name: '<b>a&b</b>', matrix: [_row(1, 1, 1)]),
      ]));
      expect(html, contains('value="&lt;b&gt;a&amp;b&lt;/b&gt;"'));
      expect(html, isNot(contains('<option value="<b>a&b</b>">')));
    });

    test('escapes < in embedded JSON so it cannot terminate the script', () {
      final html = buildStatsHtml(_data(players: [
        (name: '</script>', matrix: [_row(1, 1, 1)]),
      ]));
      expect(html, isNot(contains('"</script>"')));
      expect(html, contains(r'\u003c'));
    });
  });
}
