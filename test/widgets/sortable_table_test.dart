import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Row = ({String name, int games});

Widget _app(List<_Row> rows, {int? collapsed}) => MaterialApp(
      home: Scaffold(
        body: SortableTable<_Row>(
          columns: [
            SortableColumn(label: 'Name', width: 90, text: (r) => r.name),
            SortableColumn(label: 'Games', width: 60, text: (r) => '${r.games}', sortValue: (r) => r.games),
          ],
          rows: rows,
          initialSortIndex: 1,
          collapsedRowCount: collapsed,
        ),
      ),
    );

void main() {
  const rows = [(name: 'A', games: 1), (name: 'B', games: 3), (name: 'C', games: 2)];

  testWidgets('sorts descending by the initial column', (t) async {
    await t.pumpWidget(_app(rows));
    final names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['B', 'C', 'A']);
  });

  testWidgets('tapping the header flips the direction', (t) async {
    await t.pumpWidget(_app(rows));
    await t.tap(find.textContaining('Games'));
    await t.pump();
    final names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['A', 'C', 'B']);
  });

  testWidgets('collapses to N rows with a Show all button', (t) async {
    await t.pumpWidget(_app(rows, collapsed: 2));
    expect(find.text('A'), findsNothing);
    await t.tap(find.text('Show all (3)'));
    await t.pump();
    expect(find.text('A'), findsOneWidget);
  });
}
