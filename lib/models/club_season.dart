import 'package:family_mafia_app/services/firestore_service_ids.dart';

/// A club season created on /seasons/edit/ (Firestore `config/seasons`).
/// Seasons up to the JSON config's last id stay in `remote_config.json`;
/// these are appended after it. Pure Dart: the CI prefetch imports it.
class ClubSeason {
  const ClubSeason({
    required this.id,
    required this.title,
    required this.smallLeagueMinGames,
    required this.startDate,
  });

  final int id;
  final String title;
  final int smallLeagueMinGames;

  /// 'YYYY-MM-DD': from this day /host/ offers the season by default.
  final String startDate;

  Map<String, Object?> toJson() => {
        'id': id, 'title': title, 'smallLeagueMinGames': smallLeagueMinGames, 'startDate': startDate,
      };

  /// The `SeasonConfig` JSON the app loads: a Firestore season with the
  /// top-3 threshold rule, like season 31's.
  Map<String, Object?> toConfigJson() => {
        'id': id,
        'title': title,
        'gameLimitRule': 'top3',
        'gamesMultiplier': 0.0,
        'smallLeagueMinGames': smallLeagueMinGames,
        'source': 'firestore',
        'projectId': kFirebaseProjectIdForSeasons,
      };
}

const kMaxClubSeasons = 100;

List<ClubSeason> parseClubSeasons(Object? list) {
  if (list is! List) throw const FormatException('seasons: not a list');
  return [
    for (final (i, s) in list.indexed)
      if (s is Map &&
          s['id'] is int &&
          s['title'] is String &&
          s['smallLeagueMinGames'] is int &&
          s['startDate'] is String)
        ClubSeason(
          id: s['id'] as int,
          title: s['title'] as String,
          smallLeagueMinGames: s['smallLeagueMinGames'] as int,
          startDate: s['startDate'] as String,
        )
      else
        throw FormatException('seasons: entry $i needs int id, string title, int smallLeagueMinGames, string startDate'),
  ];
}

final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

bool _realDate(String s) {
  final m = _date.firstMatch(s);
  if (m == null) return false;
  final (y, mo, d) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  final dt = DateTime.utc(y, mo, d);
  return dt.year == y && dt.month == mo && dt.day == d;
}

List<String> clubSeasonErrors(List<ClubSeason> seasons, {required int lastJsonId}) {
  final errors = <String>[];
  if (seasons.length > kMaxClubSeasons) errors.add('${seasons.length} seasons, the limit is $kMaxClubSeasons');
  for (final (i, s) in seasons.indexed) {
    final want = lastJsonId + 1 + i;
    if (s.id != want) errors.add('season ${s.id}: expected id $want');
    final t = s.title.trim().length;
    if (t < 1 || t > 40) errors.add('season ${s.id}: title must be 1–40 characters');
    if (s.smallLeagueMinGames < 1 || s.smallLeagueMinGames > 100) {
      errors.add('season ${s.id}: small league minimum must be 1–100');
    }
    if (!_realDate(s.startDate)) errors.add('season ${s.id}: start date "${s.startDate}" is not a YYYY-MM-DD date');
  }
  return errors;
}

void checkClubSeasons(List<ClubSeason> seasons, {required int lastJsonId}) {
  final errors = clubSeasonErrors(seasons, lastJsonId: lastJsonId);
  if (errors.isNotEmpty) throw FormatException('config/seasons: ${errors.join('; ')}');
}

int lastSeasonId(List<Map<String, dynamic>> jsonSeasons) =>
    jsonSeasons.fold(-1, (m, s) => (s['id'] as int) > m ? s['id'] as int : m);

List<Map<String, dynamic>> appendClubSeasons(List<Map<String, dynamic>> jsonSeasons, List<ClubSeason> extra) {
  final ids = {for (final s in jsonSeasons) s['id']};
  return [
    ...jsonSeasons,
    for (final s in extra)
      if (!ids.contains(s.id)) s.toConfigJson(),
  ];
}
