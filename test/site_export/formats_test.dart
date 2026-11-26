import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/site_export/formats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('number formats match the app widgets', () {
    expect(pct0(0.546), '55%');
    expect(pct1(0.6123), '61.2%');
    expect(f2(1.0), '1.00');
    expect(signed2(0.5), '+0.50');
    expect(signed2(-0.25), '-0.25');
    expect(signed2(0), '0.00');
    expect(rounded(2.41666, 2), '2.42');
    expect(seasonLabel(null), 'За весь час');
    expect(seasonLabel(21), 'S21');
  });

  test('initials follow the profile screen', () {
    expect(initials('Олександр Сізов'), 'ОС');
    expect(initials('Sasha'), 'S');
    expect(initials('  '), '?');
  });

  test('role sums accept every sheet spelling of a role', () {
    const games = [('Мирний', 3), ('Мирный', 2), ('Дон', 1)];
    expect(roleCount(games, Role.civilian), 5);
    expect(roleCount(games, Role.sheriff), 0);
    expect(rolePoints(const [('Дон', 0.5), ('Дон', 0.25)], Role.don), 0.75);
  });

  test('Ukrainian labels and plurals', () {
    expect(gamesCount(1), '1 гра');
    expect(gamesCount(3), '3 гри');
    expect(gamesCount(5), '5 ігор');
    expect(gamesCount(11), '11 ігор');
    expect(gamesCount(22), '22 гри');
    expect(placeLabel(0), '1 місце');
    expect(seasonTitle('Season 31'), 'Сезон 31');
    expect(seasonTitle('Осінь 2026'), 'Осінь 2026');
    expect(roleLabel(Role.civilian), 'Мирний');
  });
}
