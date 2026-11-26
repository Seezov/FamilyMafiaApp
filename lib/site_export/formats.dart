import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/models/annual_event.dart';
import 'package:family_mafia_app/models/tournament.dart';
import 'package:family_mafia_app/services/stats/points_period.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';

/// The formats the app's widgets use, so the site shows the same text.
String pct0(double v) => '${(v * 100).toStringAsFixed(0)}%';
String pct1(double v) => '${(v * 100).roundTo(1)}%';
String f2(double v) => v.toStringAsFixed(2);
String signed2(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
String rounded(double v, int decimals) => v.roundTo(decimals).toString();
String seasonLabel(int? s) => s == null ? 'За весь час' : 'S$s';

/// City first, then mafia — the column order of the season ratings table.
const kRoleOrder = [Role.civilian, Role.sheriff, Role.mafia, Role.don];

String roleLabel(Role r) => switch (r) {
      Role.civilian => 'Мирний',
      Role.sheriff => 'Шериф',
      Role.mafia => 'Мафія',
      Role.don => 'Дон',
    };

/// Ukrainian plural: [one] for 1, 21…; [few] for 2–4, 22…; [many] otherwise.
String uaPlural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

/// «N гра / гри / ігор».
String gamesCount(int n) => '$n ${uaPlural(n, 'гра', 'гри', 'ігор')}';

/// «1 місце» for place index 0…2.
String placeLabel(int i) => '${i + 1} місце';

/// A season's title for the site: the config's «Season N» reads «Сезон N».
String seasonTitle(String title) => title.replaceFirstMapped(RegExp(r'^Season (\d+)$'), (m) => 'Сезон ${m[1]}');

/// Site-only Ukrainian names (the app keeps [TournamentType.label]).
String tournamentLabel(TournamentType t) => switch (t) {
      TournamentType.minicap => 'Мінікап',
      TournamentType.maxicap => 'Максікап',
      TournamentType.bigcap => 'Бігкап',
      TournamentType.marathon => 'Марафон',
      TournamentType.tournament => 'Турнір',
    };

String tournamentPlural(TournamentType t) => switch (t) {
      TournamentType.minicap => 'Мінікапи',
      TournamentType.maxicap => 'Максікапи',
      TournamentType.bigcap => 'Бігкапи',
      TournamentType.marathon => 'Марафони',
      TournamentType.tournament => 'Турніри',
    };

String pointsPeriodLabel(PointsPeriod p) => switch (p) {
      PointsPeriod.li => 'Сезони 2–3',
      PointsPeriod.modern => 'Сезони 4+',
    };

String annualKindLabel(AnnualKind k) => switch (k) {
      AnnualKind.tournament => 'Турнір',
      AnnualKind.series => 'Серія',
      AnnualKind.marathon => 'Марафон',
      AnnualKind.season => 'Сезон',
    };

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

int roleCount(List<(String, int)> perRole, Role role) => perRole
    .where((e) => role.sheetValues.contains(e.$1))
    .fold(0, (s, e) => s + e.$2);

double rolePoints(List<(String, double)> perRole, Role role) => perRole
    .where((e) => role.sheetValues.contains(e.$1))
    .fold(0.0, (s, e) => s + e.$2);
