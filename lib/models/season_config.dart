/// Describes a season and where its data comes from (bundled asset or Google Sheets).
class SeasonConfig {
  final int id;
  final String title;
  final int gameLimit;
  final double gamesMultiplier;
  final SeasonSource source;

  const SeasonConfig({
    required this.id,
    required this.title,
    required this.gameLimit,
    required this.gamesMultiplier,
    required this.source,
  });

  factory SeasonConfig.fromJson(Map<String, dynamic> json) {
    final sourceType = json['source'] as String;
    final SeasonSource source;
    if (sourceType == 'remote') {
      source = RemoteSource(
        spreadsheetId: json['spreadsheetId'] as String,
        sheetName: json['sheetName'] as String,
        range: json['range'] as String,
      );
    } else {
      source = BundledSource(jsonFile: json['jsonFile'] as String);
    }

    return SeasonConfig(
      id: json['id'] as int,
      title: json['title'] as String,
      gameLimit: json['gameLimit'] as int,
      gamesMultiplier: (json['gamesMultiplier'] as num).toDouble(),
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      'gameLimit': gameLimit,
      'gamesMultiplier': gamesMultiplier,
    };
    switch (source) {
      case BundledSource(:final jsonFile):
        map['source'] = 'bundled';
        map['jsonFile'] = jsonFile;
      case RemoteSource(:final spreadsheetId, :final sheetName, :final range):
        map['source'] = 'remote';
        map['spreadsheetId'] = spreadsheetId;
        map['sheetName'] = sheetName;
        map['range'] = range;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonConfig &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

sealed class SeasonSource {
  const SeasonSource();
}

class BundledSource extends SeasonSource {
  final String jsonFile;
  const BundledSource({required this.jsonFile});

  String get assetPath => 'assets/raw/$jsonFile';
}

class RemoteSource extends SeasonSource {
  final String spreadsheetId;
  final String sheetName;
  final String range;
  const RemoteSource({
    required this.spreadsheetId,
    required this.sheetName,
    required this.range,
  });
}
