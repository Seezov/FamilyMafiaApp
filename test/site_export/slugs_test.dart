import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/site_export/slugs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ukrainian and Russian letters are transliterated', () {
    expect(slugify('Олександр Сізов'), 'oleksandr-sizov');
    expect(slugify('Юлія Щербак'), 'iuliia-shcherbak');
    expect(slugify('Аркадий Эйдельман'), 'arkadyi-eidelman');
    expect(slugify("Мар'яна"), 'mariana');
    expect(slugify('Марʼяна'), 'mariana');
  });

  test('Latin, digits and punctuation', () {
    expect(slugify('DJ Max 2000!'), 'dj-max-2000');
    expect(slugify('...'), '');
  });

  test('every player gets a unique, non-empty slug', () {
    const players = [
      Player(id: 1, displayName: 'Саша'),
      Player(id: 2, displayName: 'саша'),
      Player(id: 3, displayName: 'Оля'),
      Player(id: 4, displayName: '???'),
    ];
    final slugs = assignSlugs(players);
    expect(slugs[1], 'sasha-1');
    expect(slugs[2], 'sasha-2');
    expect(slugs[3], 'olia');
    expect(slugs[4], 'player-4');
    expect(slugs.values.toSet(), hasLength(4));
  });
}
