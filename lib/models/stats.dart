// (slot, wins, total) per slot
class Stats {
  final String playerName;
  final String role;
  final int gamesPlayed;
  final List<(int, int, int)> slotToWr;

  const Stats({
    required this.playerName,
    required this.role,
    required this.gamesPlayed,
    required this.slotToWr,
  });
}
