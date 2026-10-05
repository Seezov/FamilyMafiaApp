import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/games_data_season.dart';

/// What a season sheet says about a game outside its 10/14 parsed rows: the
/// host's comments, the event title above it, and the table it was played at.
class SheetGameExtras {
  const SheetGameExtras({this.comments = const [], this.label, this.table});
  final List<GameComment> comments;
  final String? label;
  final int? table;
}

const _kCommentsHeader = 'Коментарі до дод балів';
const _kExtraPointsHeader = 'Додаткові бали:';
const _kLabels = {
  'Номер', _kCommentsHeader, _kExtraPointsHeader, 'Відстріл', 'Голоси', 'Гравець',
};

final _letter = RegExp(r'\p{L}', unicode: true);
final _seatList = RegExp(r'^\d{1,2}(?:\s*[.,]\s*\d{1,2})*$');
final _prefix = RegExp(r'^(\d{1,2}(?:\s*,\s*\d{1,2})*)\s*(?:[-–—:.)]\s*|\s+)(.+)$', dotAll: true);
final _tableLabel = RegExp(r'(?:^|\s)(?:([12])\s*(?:-?ий)?\s*стіл|стіл\s*([12]))(?:$|[\s,])', caseSensitive: false);
final _onlyTable = RegExp(r'^\s*(?:[12]\s*(?:-?ий)?\s*стіл|стіл\s*[12])\s*$', caseSensitive: false);

final _isoDate = RegExp(r'^\d{4}-\d\d-\d\d(?:T|$)');

bool _isText(String s) {
  final t = s.trim();
  // A seat number the sheet turned into a date is no text.
  return t.isNotEmpty && !_isoDate.hasMatch(t) && _letter.hasMatch(t) && !_kLabels.contains(t) && !t.startsWith('Голосування');
}

/// Seats named by a «Номер» cell: `6`, `10.0`, `6.9`, `3,6`, `3, 6`. Null when
/// the cell is not seat numbers 1–10 — a date the sheet made of «6,5», say.
List<int>? parseSeatList(String cell) {
  var s = cell.trim();
  if (RegExp(r'^\d{1,2}\.0$').hasMatch(s)) s = s.substring(0, s.length - 2);
  if (!_seatList.hasMatch(s)) return null;
  final seats = s.split(RegExp(r'\s*[.,]\s*')).map(int.parse).toSet().toList();
  return seats.every((n) => n >= 1 && n <= 10) ? seats : null;
}

/// A comment cell with no seat number beside it: each line may start with
/// seats (`3 - …`, `10. …`, `3,6 - …`, `5 0.1 ОП`); lines without valid seats
/// are about the whole game.
List<GameComment> parseCommentText(String text) => [
      for (final raw in text.split('\n'))
        if (raw.trim().isNotEmpty) _line(raw.trim()),
    ];

GameComment _line(String line) {
  final m = _prefix.firstMatch(line);
  if (m != null) {
    final seats = parseSeatList(m.group(1)!);
    final rest = m.group(2)!.trim();
    if (seats != null && rest.isNotEmpty) return GameComment(seats: seats, text: rest);
  }
  return GameComment(text: line);
}

List<String> _cols(GamesDataSeason r) =>
    [r.a, r.b, r.c, r.d, r.e, r.f, r.g, r.h, r.i, r.j, r.k, r.l, r.m, r.n, r.o, r.p, r.q];

bool _onlyA(GamesDataSeason r) {
  final c = _cols(r);
  return c.first.trim().isNotEmpty && c.skip(1).every((v) => v.trim().isEmpty);
}

/// Comments in one row of a comment block (columns B..Q): a text cell whose
/// left neighbour is a seat list belongs to those seats; one whose left
/// neighbour holds anything else (a date) has no seats; one with an empty
/// left neighbour is split by line prefixes.
List<GameComment> _rowComments(GamesDataSeason r) {
  final c = _cols(r);
  final out = <GameComment>[];
  for (var i = 1; i < c.length; i++) {
    if (!_isText(c[i])) continue;
    // A short group word in the seat column («Мирнячки») with its text beside it.
    if (i + 1 < c.length && _isText(c[i + 1]) && c[i].trim().length <= 25 && !c[i].contains('\n')) {
      out.add(GameComment(text: '${c[i].trim()}: ${c[i + 1].trim()}'));
      i++;
      continue;
    }
    final left = i > 1 ? c[i - 1].trim() : '';
    // A label on the left («Додаткові бали:», «Номер») is no seat number either.
    if (left.isEmpty || _isText(left) || _kLabels.contains(left)) {
      out.addAll(parseCommentText(c[i]));
    } else {
      final seats = parseSeatList(left);
      out.add(GameComment(seats: seats ?? const [], text: c[i].trim()));
    }
  }
  return out;
}

/// One [SheetGameExtras] per game anchor in [raw] (unfiltered season rows),
/// in sheet order — the same games, in the same order, as the parser's chunks.
List<SheetGameExtras> sheetGameExtras(int seasonId, List<GamesDataSeason> raw) {
  if (seasonId <= kLegacyMaxSeason) return _legacy(seasonId, raw);
  return _modern(raw);
}

List<SheetGameExtras> _legacy(int seasonId, List<GamesDataSeason> raw) {
  final games = <List<GameComment>>[];
  for (final r in raw) {
    final seat = int.tryParse(r.a.trim());
    if (seat == 1) games.add([]);
    if (games.isEmpty) continue;
    if (seasonId <= kOldFormatMaxSeason) {
      if (seat == null && _onlyA(r) && _isText(r.a)) games.last.add(GameComment(text: r.a.trim()));
    } else if (seat != null && seat >= 4 && seat <= 8 && r.b.trim().isEmpty && _isText(r.c)) {
      games.last.add(GameComment(text: r.c.trim()));
    }
  }
  return [for (final c in games) SheetGameExtras(comments: c)];
}

List<SheetGameExtras> _modern(List<GamesDataSeason> raw) {
  final out = <SheetGameExtras>[];
  var comments = <GameComment>[];
  var inBlock = false;
  int? table;
  String? tableDate;
  var started = false;
  var prevAnchor = -1;

  void close() {
    if (!started) return;
    final last = out.removeLast();
    out.add(SheetGameExtras(comments: comments, label: last.label, table: last.table));
  }

  for (var i = 0; i < raw.length; i++) {
    final r = raw[i];
    if (r.a.trim() == 'Дата') {
      close();
      final date = r.b.trim();
      final titles = [
        for (var k = i - 3; k < i; k++)
          // Rows of the previous game's block are not this game's titles.
          if (k > prevAnchor && _onlyA(raw[k]) && _isText(raw[k].a)) raw[k].a.trim(),
      ];
      if (date != tableDate) table = null;
      final labels = <String>[];
      for (final t in titles) {
        final m = _tableLabel.firstMatch(t);
        if (m != null) {
          table = int.parse(m.group(1) ?? m.group(2)!);
          if (_onlyTable.hasMatch(t)) continue;
        }
        labels.add(t);
      }
      tableDate = date;
      out.add(SheetGameExtras(label: labels.isEmpty ? null : labels.join(' · '), table: table));
      started = true;
      prevAnchor = i;
      comments = [];
      inBlock = false;
      continue;
    }
    if (!started) continue;
    final cols = _cols(r);
    if (r.b.trim() == _kExtraPointsHeader) {
      // Seasons 17–18: the comments sit in this one row, after the label.
      comments.addAll(_rowComments(r));
      continue;
    }
    if (cols.any((v) => v.trim() == _kCommentsHeader)) {
      inBlock = true;
      continue;
    }
    if (inBlock && !_onlyA(r)) comments.addAll(_rowComments(r));
  }
  close();
  return out;
}
