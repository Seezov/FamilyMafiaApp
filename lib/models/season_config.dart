import 'package:family_mafia_app/constants/season_constants.dart';
import 'package:family_mafia_app/enums/game_limit_rule.dart';

/// Describes a season and where its data comes from (bundled asset or Google Sheets).
class SeasonConfig {
  final int id;
  final String title;
  final int gameLimit;
  final int smallLeagueMinGames;
  final double gamesMultiplier;
  final SeasonSource source;
  final GameLimitRule gameLimitRule;

  /// Whether [gameLimit] is a set value: from the config, or for a top3
  /// season the admin's final value (`config/club.gameLimits`).
  final bool gameLimitSet;

  /// Filled by the loader (see `effectiveThreshold`): the formula value of a
  /// top3 season, and whether the season is still being played.
  final double? thresholdFormula;
  final bool thresholdLive;

  const SeasonConfig({
    required this.id,
    required this.title,
    required this.gameLimit,
    required this.smallLeagueMinGames,
    required this.gamesMultiplier,
    required this.source,
    this.gameLimitRule = GameLimitRule.fixed,
    this.gameLimitSet = true,
    this.thresholdFormula,
    this.thresholdLive = false,
  });

  factory SeasonConfig.fromJson(Map<String, dynamic> json) {
    final rule = GameLimitRule.parse(json['gameLimitRule'] as String?);
    final limit = json['gameLimit'] as int?;
    if (limit == null && rule == GameLimitRule.fixed) {
      throw FormatException('Season ${json['id']}: gameLimit is missing');
    }
    final sourceType = json['source'] as String;
    final SeasonSource source = switch (sourceType) {
      'remote' => RemoteSource(
          spreadsheetId: json['spreadsheetId'] as String,
          sheetName: json['sheetName'] as String,
          range: json['range'] as String,
        ),
      'firestore' => FirestoreSource(projectId: json['projectId'] as String),
      _ => BundledSource(jsonFile: json['jsonFile'] as String),
    };

    return SeasonConfig(
      id: json['id'] as int,
      title: json['title'] as String,
      gameLimit: limit ?? 0,
      gameLimitRule: rule,
      gameLimitSet: limit != null,
      smallLeagueMinGames: json['smallLeagueMinGames'] as int? ??
          kDefaultSmallLeagueMinGames,
      gamesMultiplier: (json['gamesMultiplier'] as num).toDouble(),
      source: source,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'title': title,
      if (gameLimitSet) 'gameLimit': gameLimit,
      if (gameLimitRule == GameLimitRule.top3) 'gameLimitRule': 'top3',
      'smallLeagueMinGames': smallLeagueMinGames,
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
      case FirestoreSource(:final projectId):
        map['source'] = 'firestore';
        map['projectId'] = projectId;
    }
    return map;
  }

  SeasonConfig _copy({required int gameLimit, required bool gameLimitSet,
          required double? thresholdFormula, required bool thresholdLive}) =>
      SeasonConfig(
        id: id,
        title: title,
        gameLimit: gameLimit,
        smallLeagueMinGames: smallLeagueMinGames,
        gamesMultiplier: gamesMultiplier,
        source: source,
        gameLimitRule: gameLimitRule,
        gameLimitSet: gameLimitSet,
        thresholdFormula: thresholdFormula,
        thresholdLive: thresholdLive,
      );

  /// This config with the loader's effective threshold.
  SeasonConfig withThreshold(SeasonThreshold t) => _copy(
      gameLimit: t.gameLimit,
      gameLimitSet: gameLimitSet,
      thresholdFormula: t.formula,
      thresholdLive: t.live);

  /// This config with an admin's final threshold.
  SeasonConfig withAdminLimit(int limit) => _copy(
      gameLimit: limit,
      gameLimitSet: true,
      thresholdFormula: thresholdFormula,
      thresholdLive: thresholdLive);

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

/// Games recorded on the site's /host/ page (season 32+), read over the
/// Firestore REST API.
class FirestoreSource extends SeasonSource {
  final String projectId;
  const FirestoreSource({required this.projectId});
}

/// [configs] with admins' final thresholds from `config/club.gameLimits`;
/// only top3 seasons take them.
List<SeasonConfig> applyAdminLimits(
        List<SeasonConfig> configs, Map<int, int> limits) =>
    [
      for (final c in configs)
        if (c.gameLimitRule == GameLimitRule.top3 && limits[c.id] != null)
          c.withAdminLimit(limits[c.id]!)
        else
          c,
    ];
