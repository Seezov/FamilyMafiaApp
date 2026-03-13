class GamesDataSeason {
  final String a;
  final String b;
  final String c;
  final String d;
  final String e;
  final String f;
  final String g;
  final String h;
  final String i;
  final String j;

  const GamesDataSeason({
    this.a = '',
    this.b = '',
    this.c = '',
    this.d = '',
    this.e = '',
    this.f = '',
    this.g = '',
    this.h = '',
    this.i = '',
    this.j = '',
  });

  // Uses toString() on every field so int/double values in the JSON
  // (e.g. column A row numbers) don't cause a type cast error.
  factory GamesDataSeason.fromJson(Map<String, dynamic> json) {
    String s(String key) => json[key]?.toString() ?? '';
    return GamesDataSeason(
      a: s('A'), b: s('B'), c: s('C'), d: s('D'), e: s('E'),
      f: s('F'), g: s('G'), h: s('H'), i: s('I'), j: s('J'),
    );
  }
}
