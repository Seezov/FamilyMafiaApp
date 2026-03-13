enum Season {
  season0(id: 0, title: 'Season 0', jsonFile: 'season0.json', gameLimit: 17, gamesMultiplier: 0.25),
  season1(id: 1, title: 'Season 1', jsonFile: 'season1.json', gameLimit: 30, gamesMultiplier: 0.25),
  season2(id: 2, title: 'Season 2', jsonFile: 'season2.json', gameLimit: 50, gamesMultiplier: 0.02),
  season3(id: 3, title: 'Season 3', jsonFile: 'season3.json', gameLimit: 30, gamesMultiplier: 0.015),
  season4(id: 4, title: 'Season 4', jsonFile: 'season4.json', gameLimit: 40, gamesMultiplier: 0.007),
  season5(id: 5, title: 'Season 5', jsonFile: 'season5.json', gameLimit: 50, gamesMultiplier: 0.004),
  season6(id: 6, title: 'Season 6', jsonFile: 'season6.json', gameLimit: 70, gamesMultiplier: 0.004),
  season7(id: 7, title: 'Season 7', jsonFile: 'season7.json', gameLimit: 50, gamesMultiplier: 0.004),
  season8(id: 8, title: 'Season 8', jsonFile: 'season8.json', gameLimit: 40, gamesMultiplier: 0.004),
  season9(id: 9, title: 'Season 9', jsonFile: 'season9.json', gameLimit: 40, gamesMultiplier: 0.004),
  season10(id: 10, title: 'Season 10', jsonFile: 'season10.json', gameLimit: 40, gamesMultiplier: 0.004),
  season11(id: 11, title: 'Season 11', jsonFile: 'season11.json', gameLimit: 45, gamesMultiplier: 0.004),
  season12(id: 12, title: 'Season 12', jsonFile: 'season12.json', gameLimit: 50, gamesMultiplier: 0.004),
  season13(id: 13, title: 'Season 13', jsonFile: 'season13.json', gameLimit: 40, gamesMultiplier: 0.004),
  season14(id: 14, title: 'Season 14', jsonFile: 'season14.json', gameLimit: 58, gamesMultiplier: 0.004),
  season15(id: 15, title: 'Season 15', jsonFile: 'season15.json', gameLimit: 56, gamesMultiplier: 0.004),
  season16(id: 16, title: 'Season 16', jsonFile: 'season16.json', gameLimit: 58, gamesMultiplier: 0.004),
  season17(id: 17, title: 'Season 17', jsonFile: 'season17.json', gameLimit: 60, gamesMultiplier: 0.0),
  season18(id: 18, title: 'Season 18', jsonFile: 'season18.json', gameLimit: 55, gamesMultiplier: 0.0),
  season19(id: 19, title: 'Season 19', jsonFile: 'season19.json', gameLimit: 60, gamesMultiplier: 0.0),
  season20(id: 20, title: 'Season 20', jsonFile: 'season20.json', gameLimit: 60, gamesMultiplier: 0.0),
  season21(id: 21, title: 'Season 21', jsonFile: 'season21.json', gameLimit: 60, gamesMultiplier: 0.0),
  season22(id: 22, title: 'Season 22', jsonFile: 'season22.json', gameLimit: 60, gamesMultiplier: 0.0),
  season23(id: 23, title: 'Season 23', jsonFile: 'season23.json', gameLimit: 60, gamesMultiplier: 0.0),
  season24(id: 24, title: 'Season 24', jsonFile: 'season24.json', gameLimit: 42, gamesMultiplier: 0.0),
  season25(id: 25, title: 'Season 25', jsonFile: 'season25.json', gameLimit: 60, gamesMultiplier: 0.0),
  season26(id: 26, title: 'Season 26', jsonFile: 'season26.json', gameLimit: 60, gamesMultiplier: 0.0),
  season27(id: 27, title: 'Season 27', jsonFile: 'season27.json', gameLimit: 60, gamesMultiplier: 0.0),
  season28(id: 28, title: 'Season 28', jsonFile: 'season28.json', gameLimit: 55, gamesMultiplier: 0.0);

  const Season({
    required this.id,
    required this.title,
    required this.jsonFile,
    required this.gameLimit,
    required this.gamesMultiplier,
  });

  final int id;
  final String title;
  final String jsonFile;
  final int gameLimit;
  final double gamesMultiplier;

  static Season? findById(int id) {
    for (final s in Season.values) {
      if (s.id == id) return s;
    }
    return null;
  }

  String get assetPath => 'assets/raw/$jsonFile';
}
