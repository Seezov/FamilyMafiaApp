import 'dart:convert';

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/screens/debug/debug_providers.dart';

/// A single player's slot x role matrix, keyed by display name.
typedef PlayerMatrix = ({String name, List<SlotRoleRow> matrix});

/// The payload rendered into the exported HTML file: the global slot/role
/// matrix plus every player's matrix for offline search filtering.
typedef StatsExportData = ({
  DateTime generatedAt,
  List<SlotRoleRow> globalMatrix,
  List<PlayerMatrix> players,
});

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _pct(double v) => '${(v * 100).toStringAsFixed(1)}%';

String _roleLabel(Role role) => switch (role) {
      Role.sheriff => 'Sheriff',
      Role.don => 'Don',
      Role.civilian => 'Civilian',
      Role.mafia => 'Mafia',
    };

/// Renders the tbody rows for a slot x role matrix (used for the initial,
/// no-JS default view). The client re-renders the same markup on search.
String _renderRows(List<SlotRoleRow> rows) {
  final buf = StringBuffer();
  for (final row in rows) {
    buf.write('<tr><th>Slot ${row.slot}</th>');
    var totPlayed = 0;
    var totWins = 0;
    for (final role in kMatrixRoles) {
      final c = row.cells[role]!;
      totPlayed += c.played;
      totWins += c.wins;
      buf.write(c.played == 0
          ? '<td class="dim">—</td>'
          : '<td>${_pct(c.winRate)}<span class="frac">'
              '${c.wins}/${c.played}</span></td>');
    }
    final totWr = totPlayed == 0 ? 0.0 : totWins / totPlayed;
    buf.write(totPlayed == 0
        ? '<td class="dim">—</td>'
        : '<td class="tot">${_pct(totWr)}<span class="frac">'
            '$totWins/$totPlayed</span></td>');
    buf.write('</tr>');
  }
  return buf.toString();
}

/// Flattens a matrix to nested arrays: 10 rows, each 4 `[played, wins]` pairs
/// in [kMatrixRoles] order.
List<List<List<int>>> _rowsToArrays(List<SlotRoleRow> rows) => [
      for (final row in rows)
        [
          for (final role in kMatrixRoles)
            [row.cells[role]!.played, row.cells[role]!.wins],
        ],
    ];

/// Builds a self-contained HTML document (inline CSS/JS, no external assets)
/// showing the win-rate-by-slot-&-role matrix with a player search that
/// filters the matrix to a single player (or global when empty), matching the
/// app's Statistics screen.
String buildStatsHtml(StatsExportData data) {
  final payload = {
    'global': _rowsToArrays(data.globalMatrix),
    'players': {
      for (final pm in data.players) pm.name: _rowsToArrays(pm.matrix),
    },
  };
  // Escape `<` so the JSON can never terminate the surrounding <script> tag.
  final json = jsonEncode(payload).replaceAll('<', r'\u003c');

  final buf = StringBuffer();
  buf.writeln('<!DOCTYPE html>');
  buf.writeln('<html lang="en"><head>');
  buf.writeln('<meta charset="utf-8">');
  buf.writeln('<meta name="viewport" content="width=device-width, '
      'initial-scale=1">');
  buf.writeln('<title>Family Mafia — Stats</title>');
  buf.writeln('<style>$_css</style>');
  buf.writeln('</head><body>');

  buf.writeln('<header><h1>Family Mafia</h1>'
      '<p class="sub">Win rate by slot &amp; role · generated '
      '${data.generatedAt.toLocal().toString().split('.').first}</p></header>');

  buf.writeln('<main>');
  buf.writeln('<div class="searchbar">'
      '<input id="search" list="players" placeholder="Search player…" '
      'autocomplete="off">'
      '<button id="clear" type="button" aria-label="Clear">×</button>'
      '</div>');
  buf.writeln('<datalist id="players">');
  for (final pm in data.players) {
    buf.writeln('<option value="${_esc(pm.name)}"></option>');
  }
  buf.writeln('</datalist>');

  buf.writeln('<p class="sel" id="sel">All players</p>');

  buf.writeln('<div class="scroll"><table>');
  buf.writeln('<thead><tr><th>Slot</th>');
  for (final role in kMatrixRoles) {
    buf.writeln('<th>${_roleLabel(role)}</th>');
  }
  buf.writeln('<th>Total</th></tr></thead>');
  buf.writeln('<tbody id="mbody">${_renderRows(data.globalMatrix)}</tbody>');
  buf.writeln('</table></div>');
  buf.writeln('</main>');

  buf.writeln('<script>var DATA=$json;\n$_js</script>');
  buf.writeln('</body></html>');
  return buf.toString();
}

const _js = '''
(function () {
  var body = document.getElementById('mbody');
  var sel = document.getElementById('sel');
  var input = document.getElementById('search');
  function cell(p, w, tot) {
    if (p === 0) return '<td class="dim">—</td>';
    var c = tot ? ' class="tot"' : '';
    return '<td' + c + '>' + (w / p * 100).toFixed(1) + '%' +
      '<span class="frac">' + w + '/' + p + '</span></td>';
  }
  function render(rows) {
    var h = '';
    for (var i = 0; i < rows.length; i++) {
      var c = rows[i], tp = 0, tw = 0;
      h += '<tr><th>Slot ' + (i + 1) + '</th>';
      for (var r = 0; r < 4; r++) {
        tp += c[r][0]; tw += c[r][1];
        h += cell(c[r][0], c[r][1], false);
      }
      h += cell(tp, tw, true) + '</tr>';
    }
    body.innerHTML = h;
  }
  function apply() {
    var q = input.value.trim();
    if (DATA.players[q]) { render(DATA.players[q]); sel.textContent = q; }
    else { render(DATA.global); sel.textContent = 'All players'; }
  }
  input.addEventListener('input', apply);
  document.getElementById('clear').addEventListener('click', function () {
    input.value = '';
    apply();
  });
})();
''';

const _css = '''
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body { margin: 0; font-family: -apple-system, Segoe UI, Roboto, sans-serif;
  background: #f4fbf8; color: #161d1b; line-height: 1.5; }
header { background: linear-gradient(135deg,#00695c,#00897b); color: #fff;
  padding: 28px 20px; }
header h1 { margin: 0; font-size: 1.7rem; }
header .sub { margin: 6px 0 0; opacity: .85; font-size: .85rem; }
main { max-width: 860px; margin: 0 auto; padding: 20px; }
.searchbar { display: flex; gap: 8px; align-items: center; }
.searchbar input { flex: 1; padding: 12px 14px; font-size: 1rem;
  border: 1px solid #b7c4bf; border-radius: 10px; background: #fff;
  color: inherit; }
.searchbar input:focus { outline: 2px solid #00897b; border-color: #00897b; }
.searchbar button { width: 44px; height: 44px; border: 1px solid #b7c4bf;
  border-radius: 10px; background: #fff; font-size: 1.3rem; cursor: pointer;
  color: #3f4946; }
.sel { margin: 12px 0 8px; font-weight: 600; color: #00695c; }
.scroll { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; background: #fff;
  border-radius: 12px; overflow: hidden; box-shadow: 0 1px 3px rgba(0,0,0,.08); }
th, td { padding: 8px 10px; text-align: center; font-size: .85rem;
  border-bottom: 1px solid #e3e9e6; }
thead th { background: #d9ede8; font-weight: 700; }
tbody th { text-align: left; font-weight: 600; white-space: nowrap; }
td .frac { display: block; font-size: .7rem; color: #3f4946; }
td.tot { font-weight: 800; }
td.dim { color: #9aa8a1; }
@media (prefers-color-scheme: dark) {
  body { background: #0e1513; color: #dde4e1; }
  table { background: #1a211f; box-shadow: none; }
  thead th { background: #23302c; }
  th, td { border-color: #2a322f; }
  td .frac { color: #a4b0ab; }
  .sel { color: #7ad0c0; }
  .searchbar input, .searchbar button { background: #1a211f;
    border-color: #2f4f48; }
}
''';
