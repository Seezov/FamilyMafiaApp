import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/services/empty_seasons.dart';
import 'package:flutter_test/flutter_test.dart';

SeasonConfig _c(int id, SeasonSource source) =>
    SeasonConfig(id: id, title: 'S$id', gameLimit: 10, smallLeagueMinGames: 15, gamesMultiplier: 0, source: source);

void main() {
  const fs = FirestoreSource(projectId: 'p');
  const empty = '{"format":"firestore","games":[]}';
  const one = '{"format":"firestore","games":[{"id":"a"}]}';

  test('only a firestore snapshot without games is empty', () {
    expect(isEmptyFirestoreSnapshot(empty), isTrue);
    expect(isEmptyFirestoreSnapshot(one), isFalse);
    expect(isEmptyFirestoreSnapshot('[["1","Rathma"]]'), isFalse);
    expect(isEmptyFirestoreSnapshot('{"values": []}'), isFalse);
  });

  test('latestWithGames skips an empty newest firestore season', () async {
    final configs = [_c(31, const BundledSource(jsonFile: 'season31.json')), _c(32, fs)];
    final r = await latestWithGames(configs, (c) async => c.id == 32 ? empty : one);
    expect(r!.$1.id, 31);
  });

  test('latestWithGames keeps a firestore season with games', () async {
    final r = await latestWithGames([_c(31, fs), _c(32, fs)], (c) async => one);
    expect(r!.$1.id, 32);
  });

  test('latestWithGames: null when nothing loads', () async {
    expect(await latestWithGames([_c(32, fs)], (c) async => null), isNull);
  });
}
