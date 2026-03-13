class YearStats {
  final String player;
  final int gamesPlayed;
  final double totalWr;
  final double civWr;
  final double mafWr;
  final double sherWr;
  final double donWr;
  final double firstKilled;
  final double averageAddPoints;
  final double averageAddPointsCiv;
  final double averageAddPointsMaf;
  final double averageAddPointsSher;
  final double averageAddPointsDon;

  const YearStats({
    required this.player,
    required this.gamesPlayed,
    required this.totalWr,
    required this.civWr,
    required this.mafWr,
    required this.sherWr,
    required this.donWr,
    required this.firstKilled,
    required this.averageAddPoints,
    required this.averageAddPointsCiv,
    required this.averageAddPointsMaf,
    required this.averageAddPointsSher,
    required this.averageAddPointsDon,
  });
}
