class SlotStats {
  final int slot;
  // (roleSheetValue, winRate%)
  final List<(String, double)> roleWr;

  const SlotStats({required this.slot, required this.roleWr});
}
