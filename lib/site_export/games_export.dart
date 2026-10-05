import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/screens/home/home_providers.dart';
import 'package:family_mafia_app/site_export/export_context.dart';

/// The sheet's name for the best-move points column of [seasonId].
String autoLabel(int seasonId) =>
    seasonId <= kLegacyMaxSeason ? 'ЛХ' : seasonId <= kPreProtocolMaxSeason ? 'КХ' : 'ОП';

String _day(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _role(String cell) => switch (Role.findByValue(cell.trim())) {
      Role.civilian => 'civilian',
      Role.sheriff => 'sheriff',
      Role.mafia => 'mafia',
      Role.don => 'don',
      null => cell.trim(),
    };

/// Rounded to 2 decimals; null for zero so the key is left out.
double? _pts(double? v) => v == null || v.roundTo(2) == 0 ? null : v.roundTo(2);

List<Map<String, Object>> _colors(List<int> signed) =>
    [for (final c in signed) {'seat': c.abs(), 'black': c < 0}];

Map<String, Object?> _compact(Map<String, Object?> m) =>
    {for (final e in m.entries) if (e.value != null) e.key: e.value};

/// One season's games for /season/N/games/, grouped by day in sheet order.
Map<String, Object?> gamesJson(ExportContext x, SeasonConfig season, List<Game> allGames) {
  // Empty template blocks (every seat a placeholder) are not games.
  final games = [for (final g in allGames) if (!g.players.every((p) => p.startsWith('_blank_'))) g];
  final resolver = x.read(playerResolverProvider);
  final onSite = {for (final p in x.players) p.id};
  String? slugOf(String name) {
    final p = resolver.resolve(name);
    return onSite.contains(p.id) ? x.slugs[p.id] : null;
  }

  Map<String, Object?> seat(Game g, int i) {
    final raw = g.players[i];
    final blank = raw.startsWith('_blank_');
    final slug = blank ? null : slugOf(raw);
    final won = !blank && g.isRatingGame() && g.hasPlayerWon(raw);
    final bm = g.firstKilled == i + 1 ? g.bestMovePoints : null;
    final parts = [
      won ? 1.0 : 0.0,
      g.additionalPoints?[i] ?? 0, g.autoAdditionalPoints?[i] ?? 0, bm ?? 0,
      g.penaltyPoints?[i] ?? 0, g.protocolAdditionalPoints?[i] ?? 0, g.protocolPenaltyPoints?[i] ?? 0,
    ];
    return _compact({
      'n': i + 1,
      'player': blank ? null : raw,
      'slug': slug,
      'key': blank ? null : (slug ?? raw),
      'role': _role(g.roles[i]),
      'fouls': (g.fouls?[i] ?? 0) == 0 ? null : g.fouls![i],
      'won': won ? true : null,
      'add': _pts(g.additionalPoints?[i]),
      'ad': _pts(g.autoAdditionalPoints?[i]),
      'bm': _pts(bm),
      'pen': _pts(g.penaltyPoints?[i]),
      'prAdd': _pts(g.protocolAdditionalPoints?[i]),
      'prPen': _pts(g.protocolPenaltyPoints?[i]),
      'total': _pts(parts.fold<double>(0, (a, b) => a + b)),
    });
  }

  final byDay = <String?, List<Game>>{};
  for (final g in games) {
    byDay.putIfAbsent(g.date == null ? null : _day(g.date!), () => []).add(g);
  }
  final keys = [...byDay.keys.whereType<String>(), if (byDay.containsKey(null)) null];

  Map<String, Object?> game(Game g, String id, int n) => _compact({
                'id': id,
                'n': n,
                'table': g.table,
                'label': g.label,
                'host': g.host,
                'result': switch (g.cityWon) { true => 'city', false => 'mafia', null => 'unrated' },
                'seats': [for (var i = 0; i < g.players.length; i++) seat(g, i)],
                'firstKilled': g.firstKilled == 0 ? null : g.firstKilled,
                'bestMove': g.bestMove.where((s) => s > 0).isEmpty ? null : g.bestMove.where((s) => s > 0).toList(),
                'bestMovePoints': _pts(g.firstKilled == 0 ? null : g.bestMovePoints),
                'supportFive': g.supportFive == null ? null : _colors(g.supportFive!),
                'protocol': g.protocol == null
                    ? null
                    : [
                        for (final p in g.protocol!)
                          _compact({'killed': p.killedSlot, 'version': p.sheriffVersion, 'colors': _colors(p.colorGuesses)}),
                      ],
                'comments': g.comments == null
                    ? null
                    : [for (final c in g.comments!) {'seats': c.seats, 'text': c.text}],
              });

  final days = <Map<String, Object?>>[];
  for (final d in keys) {
    final counters = <int, int>{}; // per table: n = order within the date and table
    final out = <Map<String, Object?>>[];
    final dayGames = byDay[d]!;
    for (var i = 0; i < dayGames.length; i++) {
      final g = dayGames[i];
      final t = g.table ?? 1;
      final n = counters[t] = (counters[t] ?? 0) + 1;
      out.add(d == null ? game(g, 'g-x-$i', i + 1) : game(g, 'g-$d-$t-$n', n));
    }
    days.add({'date': d, 'games': out});
  }

  final players = <String, String>{};
  for (final g in games) {
    for (final p in g.players.where((p) => !p.startsWith('_blank_'))) {
      players.putIfAbsent(slugOf(p) ?? p, () => p);
    }
  }
  return {
    'season': season.id,
    'autoLabel': autoLabel(season.id),
    'players': [
      for (final e in players.entries.toList()..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase())))
        {'name': e.value, 'key': e.key},
    ],
    'hosts': ({for (final g in games) if (g.host != null) g.host!}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()))),
    'days': days,
  };
}
