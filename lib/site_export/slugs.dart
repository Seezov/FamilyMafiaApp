import 'package:family_mafia_app/models/player.dart';

// Ukrainian national transliteration (simplified: no word-initial forms),
// plus the Russian letters that appear in older sheets.
const _latin = {
  'а': 'a', 'б': 'b', 'в': 'v', 'г': 'h', 'ґ': 'g', 'д': 'd', 'е': 'e',
  'є': 'ie', 'ж': 'zh', 'з': 'z', 'и': 'y', 'і': 'i', 'ї': 'i', 'й': 'i',
  'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r',
  'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 'ч': 'ch',
  'ш': 'sh', 'щ': 'shch', 'ь': '', 'ю': 'iu', 'я': 'ia',
  'ы': 'y', 'э': 'e', 'ъ': '', 'ё': 'io',
  "'": '', '’': '', 'ʼ': '',
};

/// Lowercase Latin words joined by hyphens; empty when nothing is left.
String slugify(String name) {
  final out = StringBuffer();
  for (final ch in name.toLowerCase().split('')) {
    out.write(_latin[ch] ?? ch);
  }
  return out
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Player id → URL slug. Empty slugs become `player-<n>` and colliding ones
/// `<slug>-<n>`, n counting from 1 in list order: ids are list positions, which
/// a merge or the roster import shifts, so they must not reach the URL.
/// Throws if the result is somehow not unique.
Map<int, String> assignSlugs(List<Player> players) {
  final base = {
    for (final p in [...players]..sort((a, b) => a.id.compareTo(b.id)))
      p.id: slugify(p.displayName).isEmpty ? 'player' : slugify(p.displayName),
  };
  final counts = <String, int>{};
  for (final s in base.values) {
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final seen = <String, int>{};
  final slugs = {
    for (final MapEntry(key: id, value: s) in base.entries)
      id: s == 'player' || counts[s]! > 1 ? '$s-${seen[s] = (seen[s] ?? 0) + 1}' : s,
  };
  if (slugs.values.toSet().length != slugs.length) {
    throw StateError('Duplicate player slugs: $slugs');
  }
  return slugs;
}
