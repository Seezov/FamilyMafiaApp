import 'package:flutter/material.dart';

class SortableColumn<T> {
  final String label;
  final double width;
  final String Function(T) text;
  final num Function(T)? sortValue;

  const SortableColumn({required this.label, required this.width, required this.text, this.sortValue});
}

/// A table whose first column stays put while the rest scroll sideways.
/// Tapping a sortable header sorts by it; tapping again flips the direction.
class SortableTable<T> extends StatefulWidget {
  final List<SortableColumn<T>> columns;
  final List<T> rows;
  final int initialSortIndex;
  final bool initialDescending;
  final int? collapsedRowCount;
  final bool showRank;

  /// Whether the collapsed table shows its own "Show all (N)" toggle. False
  /// when a surrounding screen already offers its own way to see every row
  /// (e.g. an "Expand" button), so the two controls don't duplicate.
  final bool showExpandToggle;

  const SortableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.initialSortIndex = 0,
    this.initialDescending = true,
    this.collapsedRowCount,
    this.showRank = false,
    this.showExpandToggle = true,
  });

  @override
  State<SortableTable<T>> createState() => _SortableTableState<T>();
}

class _SortableTableState<T> extends State<SortableTable<T>> {
  static const _rowHeight = 34.0;
  static const _rankWidth = 26.0;
  static const _medals = [Color(0xFFF9A825), Color(0xFF90A4AE), Color(0xFFBF8970)];

  late int _sortIndex = widget.initialSortIndex;
  late bool _desc = widget.initialDescending;
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant SortableTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.columns.length != oldWidget.columns.length ||
        widget.initialSortIndex != oldWidget.initialSortIndex) {
      _sortIndex = widget.initialSortIndex;
      _desc = widget.initialDescending;
      _expanded = false;
    }
    if (_sortIndex >= widget.columns.length) {
      _sortIndex = widget.initialSortIndex.clamp(0, widget.columns.length - 1);
    }
  }

  // List.sort is unstable above 32 elements (dual-pivot quicksort), which
  // would drop the name/season tie-break the pure functions already applied
  // to widget.rows. Sorting the (index, row) pairs and falling back to the
  // original index keeps ties in input order regardless of list size.
  List<T> get _sorted {
    final value = widget.columns[_sortIndex].sortValue;
    if (value == null) return widget.rows;
    final indexed = widget.rows.indexed.toList()
      ..sort((a, b) {
        final c = _desc ? value(b.$2).compareTo(value(a.$2)) : value(a.$2).compareTo(value(b.$2));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return [for (final (_, row) in indexed) row];
  }

  void _tap(int i) {
    if (widget.columns[i].sortValue == null) return;
    setState(() {
      if (_sortIndex == i) {
        _desc = !_desc;
      } else {
        _sortIndex = i;
        _desc = true;
      }
    });
  }

  Widget _header(int i) {
    final c = widget.columns[i];
    final active = i == _sortIndex;
    return InkWell(
      onTap: c.sortValue == null ? null : () => _tap(i),
      child: Container(
        width: c.width,
        height: _rowHeight,
        alignment: i == 0 ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          active ? '${c.label} ${_desc ? '▼' : '▲'}' : c.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF00897B) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _cell(int col, T row) {
    final c = widget.columns[col];
    final active = col == _sortIndex;
    return Container(
      width: c.width,
      height: _rowHeight,
      alignment: col == 0 ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0)))),
      child: Text(
        c.text(row),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: col == 0 || active ? FontWeight.w700 : FontWeight.w400,
          color: active ? const Color(0xFF004D40) : const Color(0xDD000000),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _rank(int index) => Container(
        width: _rankWidth,
        height: _rowHeight,
        alignment: Alignment.center,
        child: Text('${index + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: index < 3 ? _medals[index] : Colors.grey,
            )),
      );

  @override
  Widget build(BuildContext context) {
    final all = _sorted;
    final limit = widget.collapsedRowCount;
    final rows = (!_expanded && limit != null) ? all.take(limit).toList() : all;
    final rest = List.generate(widget.columns.length - 1, (i) => i + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showRank)
              Column(children: [
                const SizedBox(width: _rankWidth, height: _rowHeight),
                for (var i = 0; i < rows.length; i++) _rank(i),
              ]),
            Column(children: [_header(0), for (final r in rows) _cell(0, r)]),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [for (final i in rest) _header(i)]),
                    for (final r in rows) Row(children: [for (final i in rest) _cell(i, r)]),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (limit != null && all.length > limit && widget.showExpandToggle)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? 'Show less' : 'Show all (${all.length})'),
          ),
      ],
    );
  }
}
