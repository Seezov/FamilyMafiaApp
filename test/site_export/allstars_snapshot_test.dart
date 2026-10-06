import 'dart:io';

import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:family_mafia_app/services/stats/player_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

/// The columns whose sum is each computed year's MVP.
const _mvpColumns = {
  2019: ['Допы', 'ЛХ'],
  2022: ['Допы', 'ЛХ'],
  2023: ['ДБ', 'КХ'],
};

double _num(String s) => s.trim().isEmpty ? 0 : double.parse(s.replaceAll(',', '.'));

void main() {
  final events = parseAllstars(File('assets/raw/allstars.json').readAsStringSync());

  test('the five events and their winners', () {
    expect({for (final e in events) e.year: e.standings.first.player}, {
      2019: 'Рауль',
      2022: 'Луна',
      2023: 'Seezov',
      2024: 'Braun',
      2025: 'Tina',
    });
  });

  test('official nominations only for federation years, games for the rest', () {
    for (final e in events) {
      expect(e.nominations == null, _mvpColumns.containsKey(e.year), reason: '${e.year}');
      expect(e.games.isEmpty, e.nominations != null, reason: '${e.year}');
    }
  });

  test('computed MVP equals the final table\'s additional + best-move columns', () {
    for (final e in events.where((e) => _mvpColumns.containsKey(e.year))) {
      final labels = [for (final c in e.columns) c.label];
      final [addCol, bmCol] = [for (final l in _mvpColumns[e.year]!) labels.indexOf(l)];
      final mvp = <String, double>{};
      for (final g in e.games) {
        for (final s in g.seats) {
          mvp[s.player.toLowerCase()] = (mvp[s.player.toLowerCase()] ?? 0) + s.add + s.bestMove;
        }
      }
      for (final s in e.standings) {
        final want = _num(s.values[addCol]) + _num(s.values[bmCol]);
        expect(mvp[s.player.toLowerCase()] ?? 0, closeTo(want, 0.011),
            reason: '${e.year} ${s.player}');
      }
      final n = computeNominations(e.games, [for (final s in e.standings) s.player]);
      expect(n[NominationKind.mvp], isNotEmpty, reason: '${e.year}');
    }
  });

  test('every final-table name is a roster player', () {
    final players = [
      for (final p in (jsonDecode(File('assets/raw/players.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>())
        Player.fromJson(p)
    ];
    final resolver = PlayerResolver(players);
    for (final e in events) {
      for (final s in e.standings) {
        expect(resolver.resolve(s.player).id, greaterThanOrEqualTo(0),
            reason: '${e.year}: «${s.player}» is not in assets/raw/players.json');
      }
    }
  });
}
