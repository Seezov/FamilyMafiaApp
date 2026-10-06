/// The one table shape the site renders. Text is formatted here, in Dart, the
/// way the app's widgets format it; the site only lays out and sorts.
class SiteColumn {
  const SiteColumn(this.label,
      {this.numeric = true, this.tip, this.group, this.phone = true});

  final String label;

  /// Right-aligned, tabular figures.
  final bool numeric;

  /// Header tooltip, for abbreviations.
  final String? tip;

  /// Shared header above adjacent columns, e.g. a role name.
  final String? group;

  /// Shown on phones; hidden columns move into the row's expandable details.
  final bool phone;

  Map<String, Object?> toJson() => {
        'label': label,
        'numeric': numeric,
        if (tip != null) 'tip': tip,
        if (group != null) 'group': group,
        if (!phone) 'phone': false,
      };
}

class SiteCell {
  const SiteCell(this.t, {this.s, this.link, this.tone});

  /// Display text.
  final String t;

  /// Sort key; cells without one sort by text, after the ones that have one.
  final num? s;

  /// Player slug to link to.
  final String? link;

  /// `wr` (colour by [s] as a win rate), `pos`, `neg`.
  final String? tone;

  Map<String, Object?> toJson() => {
        't': t,
        if (s != null && s!.isFinite) 's': s,
        if (link != null) 'link': link,
        if (tone != null) 'tone': tone,
      };
}

class SiteTable {
  const SiteTable({
    required this.columns,
    required this.rows,
    this.title,
    this.empty,
    this.sortColumn,
    this.desc = true,
    this.showRank = false,
    this.collapsed,
    this.sortable = true,
  });

  final List<SiteColumn> columns;
  final List<List<SiteCell>> rows;
  final String? title;

  /// Shown instead of the table when [rows] is empty.
  final String? empty;

  /// Column the rows are initially sorted by; null keeps the given order.
  final int? sortColumn;
  final bool desc;
  final bool showRank;

  /// Rows shown before "Show all".
  final int? collapsed;

  /// False for a table whose order is the result (a final table): no
  /// clickable headers.
  final bool sortable;

  Map<String, Object?> toJson() {
    assert(rows.every((r) => r.length == columns.length),
        'every row needs ${columns.length} cells');
    return {
      if (title != null) 'title': title,
      if (empty != null) 'empty': empty,
      'columns': [for (final c in columns) c.toJson()],
      'rows': [
        for (final r in rows) [for (final c in r) c.toJson()]
      ],
      if (sortColumn != null) 'sortColumn': sortColumn,
      'desc': desc,
      'showRank': showRank,
      if (collapsed != null) 'collapsed': collapsed,
      if (!sortable) 'sortable': false,
    };
  }
}
