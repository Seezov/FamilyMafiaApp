import 'package:family_mafia_app/widgets/sortable_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Row = ({String name, int games});

Widget _app(List<_Row> rows, {int? collapsed, bool showExpandToggle = true}) => MaterialApp(
      home: Scaffold(
        body: SortableTable<_Row>(
          columns: [
            SortableColumn(label: 'Name', width: 90, text: (r) => r.name),
            SortableColumn(label: 'Games', width: 60, text: (r) => '${r.games}', sortValue: (r) => r.games),
          ],
          rows: rows,
          initialSortIndex: 1,
          collapsedRowCount: collapsed,
          showExpandToggle: showExpandToggle,
        ),
      ),
    );

typedef _WideRow = ({String name, int x, int y});

Widget _wideApp(List<_WideRow> rows, {required int columnCount, required int initialSortIndex}) => MaterialApp(
      home: Scaffold(
        body: SortableTable<_WideRow>(
          key: const ValueKey('wide-table'),
          columns: [
            SortableColumn(label: 'Name', width: 90, text: (r) => r.name),
            SortableColumn(label: 'X', width: 60, text: (r) => '${r.x}', sortValue: (r) => r.x),
            if (columnCount == 3) SortableColumn(label: 'Y', width: 60, text: (r) => '${r.y}', sortValue: (r) => r.y),
          ],
          rows: rows,
          initialSortIndex: initialSortIndex,
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

  testWidgets('showExpandToggle: false collapses rows with no Show all button', (t) async {
    await t.pumpWidget(_app(rows, collapsed: 2, showExpandToggle: false));
    expect(find.text('A'), findsNothing);
    expect(find.textContaining('Show all'), findsNothing);
  });

  testWidgets('resets sort when columns list changes on the same state', (t) async {
    const wideRows = [
      (name: 'A', x: 1, y: 30),
      (name: 'B', x: 3, y: 10),
      (name: 'C', x: 2, y: 20),
    ];

    await t.pumpWidget(_wideApp(wideRows, columnCount: 3, initialSortIndex: 2));
    var names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['A', 'C', 'B']); // descending by y: 30, 20, 10

    await t.pumpWidget(_wideApp(wideRows, columnCount: 2, initialSortIndex: 1));
    await t.pump();

    expect(t.takeException(), isNull);
    names = t.widgetList<Text>(find.textContaining(RegExp(r'^[ABC]$'))).map((w) => w.data).toList();
    expect(names, ['B', 'C', 'A']); // descending by x: 3, 2, 1
  });

  testWidgets('tied values keep their input order (stable sort), even above 32 rows', (t) async {
    // Dart's default List.sort switches from insertion sort (stable, <=32
    // elements) to an unstable dual-pivot quicksort above 32 elements, so
    // this needs more than 32 rows to actually exercise the bug.
    final manyRows = [
      for (var i = 0; i < 40; i++) (name: 'r${i.toString().padLeft(2, '0')}', games: i ~/ 8),
    ];
    // 5 tie groups of 8 rows each, sharing games = 0..4. Input order within
    // each group is ascending index; a stable sort must preserve that after
    // sorting descending by games.
    final expected = [
      for (var group = 4; group >= 0; group--)
        for (var i = group * 8; i < group * 8 + 8; i++) 'r${i.toString().padLeft(2, '0')}',
    ];

    // 40 rows don't fit the default 600px test viewport; the table itself
    // isn't scrollable, so grow the surface instead of asserting on layout.
    t.view.physicalSize = const Size(800, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_app(manyRows));
    final names = t
        .widgetList<Text>(find.textContaining(RegExp(r'^r\d\d$')))
        .map((w) => w.data)
        .toList();
    expect(names, expected);
  });
}
