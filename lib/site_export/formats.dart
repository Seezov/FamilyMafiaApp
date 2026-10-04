import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';

/// The formats the app's widgets use, so the site shows the same text.
String pct0(double v) => '${(v * 100).toStringAsFixed(0)}%';
String pct1(double v) => '${(v * 100).roundTo(1)}%';
String f2(double v) => v.toStringAsFixed(2);
String signed2(double v) => '${v > 0 ? '+' : ''}${v.toStringAsFixed(2)}';
String rounded(double v, int decimals) => v.roundTo(decimals).toString();
String seasonLabel(int? s) => s == null ? 'All time' : 'S$s';

/// City first, then mafia — the column order of the season ratings table.
const kRoleOrder = [Role.civilian, Role.sheriff, Role.mafia, Role.don];

String roleLabel(Role r) => switch (r) {
      Role.civilian => 'Civilian',
      Role.sheriff => 'Sheriff',
      Role.mafia => 'Mafia',
      Role.don => 'Don',
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
