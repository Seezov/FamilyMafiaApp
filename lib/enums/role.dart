enum Role {
  sheriff(sheetValues: ['Шериф'], isBlack: false, chanceToDraw: 0.1),
  don(sheetValues: ['Дон'], isBlack: true, chanceToDraw: 0.1),
  civilian(sheetValues: ['Мирный', 'Мирний'], isBlack: false, chanceToDraw: 0.6),
  mafia(sheetValues: ['Мафия', 'Мафія'], isBlack: true, chanceToDraw: 0.2);

  const Role({
    required this.sheetValues,
    required this.isBlack,
    required this.chanceToDraw,
  });

  final List<String> sheetValues;
  final bool isBlack;
  final double chanceToDraw;

  // The canonical single value (last in list) used as map key
  String get sheetValue => sheetValues.last;

  static Role? findByValue(String value) {
    for (final role in Role.values) {
      if (role.sheetValues.contains(value)) return role;
    }
    return null;
  }
}
