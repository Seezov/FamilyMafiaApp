import 'package:family_mafia_app/models/allstars.dart';
import 'package:family_mafia_app/services/stats/allstars_nominations.dart';
import 'package:flutter_test/flutter_test.dart';

AllstarsSeat s(String p, AllstarsRole r, {double add = 0, double bm = 0}) =>
    AllstarsSeat(player: p, role: r, add: add, bestMove: bm);

const civ = AllstarsRole.civilian, sher = AllstarsRole.sheriff,
    maf = AllstarsRole.mafia, don = AllstarsRole.don;

List<(String, double)> rows(List<NominationRow> l) => [for (final r in l) (r.player, r.value)];

void main() {
  test('MVP sums additional and best-move points, penalties included', () {
    final games = [
      AllstarsGame(firstKilled: 1, seats: [s('A', civ, add: 0.3, bm: 0.4), s('B', maf, add: 0.5)]),
      AllstarsGame(firstKilled: null, seats: [s('A', maf, add: -0.5), s('B', sher, add: 0.2)]),
    ];
    final n = computeNominations(games, ['A', 'B']);
    expect(rows(n[NominationKind.mvp]!).map((r) => (r.$1, r.$2.toStringAsFixed(2))),
        [('B', '0.70'), ('A', '0.20')]);
  });

  test('red counts civilian and sheriff games, mafia counts mafia and don', () {
    final games = [
      AllstarsGame(firstKilled: null, seats: [s('A', civ, add: 0.3), s('B', don, add: 0.4)]),
      AllstarsGame(firstKilled: null, seats: [s('A', sher, add: 0.2), s('B', maf, add: 0.1)]),
      AllstarsGame(firstKilled: null, seats: [s('A', maf, add: 0.6), s('B', civ, add: 0.1)]),
    ];
    final n = computeNominations(games, ['A', 'B']);
    expect(rows(n[NominationKind.bestRed]!).first.$1, 'A');
    expect(n[NominationKind.bestRed]!.first.value, closeTo(0.5, 1e-9));
    expect(rows(n[NominationKind.bestMafia]!).first.$1, 'A');
    expect(n[NominationKind.bestMafia]!.first.value, closeTo(0.6, 1e-9));
    expect(n[NominationKind.bestMafia]![1].value, closeTo(0.5, 1e-9));
  });

  test('first killed counts seats; players never killed first are left out', () {
    final games = [
      AllstarsGame(firstKilled: 2, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: 2, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: 1, seats: [s('A', civ), s('B', civ)]),
      AllstarsGame(firstKilled: null, seats: [s('C', civ), s('B', civ)]),
    ];
    final n = computeNominations(games, ['A', 'B', 'C']);
    expect(rows(n[NominationKind.firstKilled]!), [('B', 2.0), ('A', 1.0)]);
  });

  test('ties keep final-table order and a tie at 3rd shows every tied player', () {
    final games = [
      AllstarsGame(firstKilled: null, seats: [
        s('E', civ, add: 0.9), s('D', civ, add: 0.3), s('C', civ, add: 0.3),
        s('B', civ, add: 0.3), s('A', civ, add: 0.1),
      ]),
    ];
    final n = computeNominations(games, ['A', 'B', 'C', 'D', 'E']);
    expect(rows(n[NominationKind.mvp]!).map((r) => r.$1), ['E', 'B', 'C', 'D']);
  });

  test('names match the table case-insensitively for ordering', () {
    final games = [AllstarsGame(firstKilled: null, seats: [s('tina', civ, add: 0.3), s('Braun', civ, add: 0.3)])];
    final n = computeNominations(games, ['Tina', 'Braun']);
    expect(rows(n[NominationKind.mvp]!).map((r) => r.$1), ['tina', 'Braun']);
  });
}
