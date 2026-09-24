// lib/services/stats/points_period.dart

/// The two доп systems all-time records are split by. Seasons 0-1 had no
/// доп at all and belong to neither.
enum PointsPeriod {
  /// Seasons 2-3: the host picked ЛИ 1 (1 point) and up to two ЛИ 2 (0.5).
  li(2, 3, 'Seasons 2–3'),

  /// Seasons 4 onward: per-player доп from the host.
  modern(4, 1 << 30, 'Seasons 4+');

  const PointsPeriod(this.firstSeason, this.lastSeason, this.label);

  final int firstSeason;
  final int lastSeason;
  final String label;

  bool contains(int seasonId) =>
      seasonId >= firstSeason && seasonId <= lastSeason;
}
