enum GameValues {
  yes(sheetValues: ['Да']),
  no(sheetValues: ['Нет']),
  mafiaWon(sheetValues: ['Мафия', 'Мафія']),
  cityWon(sheetValues: ['Город', 'Місто']),
  nonRating(sheetValues: ['Не рейтинг']);

  const GameValues({required this.sheetValues});

  final List<String> sheetValues;
}
