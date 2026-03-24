part of '../chat_engine.dart';

// ── Regex patterns ────────────────────────────────────────────────────────

final _seasonNumRe = RegExp(r'(?:season|сезон)\s*(\d+)', caseSensitive: false);
final _sShortRe = RegExp(r'\bs(\d+)\b', caseSensitive: false);

final _compareRe = RegExp(
  r'(?:compare|сравни)\s+(.+?)\s+(?:and|и|vs\.?|versus)\s+(.+)',
  caseSensitive: false,
);

final _topNRe = RegExp(
  r'(?:top|топ)\s*(\d+)\s*(.*)',
  caseSensitive: false,
);

final _bestCategoryRe = RegExp(
  r'(?:best|лучши[йе])\s+(sheriff|sheriffs?|don|dons?|civilian|civilians?|mafia|mafias?|players?|шериф[ыа]?|дон[ыа]?|мирн(?:ый|ые)|мафи[яи])',
  caseSensitive: false,
);

final _recordPatterns = <String, RegExp>{
  'most_games': RegExp(r'most\s+games|больше\s+всех\s+игр', caseSensitive: false),
  'highest_rating': RegExp(r'highest\s+rating|лучший\s+рейтинг', caseSensitive: false),
  'best_winrate': RegExp(r'best\s+win\s*rate|лучший\s+винрейт', caseSensitive: false),
  'most_killed': RegExp(r'most\s+(?:killed|first.?kill)|чаще\s+убивали', caseSensitive: false),
};

final _playerStatKeywords = RegExp(
  r'\b(games?|wins?|win\s*rate|rating|role|roles?|stats?|игр[ыа]?|побед|рейтинг|рол[ьи])\b',
  caseSensitive: false,
);

final _helpRe = RegExp(
  r'^\s*(?:help|помощь|\?|what\s+can\s+you\s+do|что\s+ты\s+умеешь)\s*[?]?\s*$',
  caseSensitive: false,
);

final _seasonQueryKeywords = RegExp(
  r'\b(who\s+won|winner|mvp|best\s+sheriff|best\s+don|best\s+civilian|best\s+mafia|stats?|games?|players?|победитель|мвп|статистика)\b',
  caseSensitive: false,
);

// ── Parser ────────────────────────────────────────────────────────────────

extension _QueryParser on ChatEngine {
  QueryIntent _parseQuery(String raw) {
    final query = raw.trim();
    if (query.isEmpty) return const HelpIntent();

    // Help
    if (_helpRe.hasMatch(query)) return const HelpIntent();

    // Compare
    final compareMatch = _compareRe.firstMatch(query);
    if (compareMatch != null) {
      return ComparePlayersIntent(
        player1Query: compareMatch.group(1)!.trim(),
        player2Query: compareMatch.group(2)!.trim(),
      );
    }

    // Extract season number if present
    int? seasonId;
    var m = _seasonNumRe.firstMatch(query);
    if (m != null) {
      seasonId = int.tryParse(m.group(1)!);
    } else {
      m = _sShortRe.firstMatch(query);
      if (m != null) seasonId = int.tryParse(m.group(1)!);
    }

    // Record queries (no season context needed)
    for (final entry in _recordPatterns.entries) {
      if (entry.value.hasMatch(query)) {
        return RecordIntent(recordType: entry.key);
      }
    }

    // Top N / leaderboard
    final topMatch = _topNRe.firstMatch(query);
    if (topMatch != null) {
      final n = int.tryParse(topMatch.group(1)!) ?? 5;
      final rest = topMatch.group(2)!.trim().toLowerCase();
      return LeaderboardIntent(
        topN: n,
        category: _resolveCategory(rest),
        seasonId: seasonId,
      );
    }

    // "best <role>" leaderboard
    final bestMatch = _bestCategoryRe.firstMatch(query);
    if (bestMatch != null) {
      // Check if this is a season award query ("best sheriff season 20")
      if (seasonId != null) {
        final cat = bestMatch.group(1)!.toLowerCase();
        final questionType = _categoryToAwardType(cat);
        if (questionType != null) {
          return SeasonQueryIntent(seasonId: seasonId, questionType: questionType);
        }
      }
      return LeaderboardIntent(
        topN: 5,
        category: _resolveCategory(bestMatch.group(1)!.toLowerCase()),
        seasonId: seasonId,
      );
    }

    // Season-specific queries (must have a season number)
    if (seasonId != null) {
      // Check for season query keywords
      if (_seasonQueryKeywords.hasMatch(query)) {
        String? questionType;
        final q = query.toLowerCase();
        if (q.contains('who won') || q.contains('winner') || q.contains('победитель')) {
          questionType = 'winner';
        } else if (q.contains('mvp') || q.contains('мвп')) {
          questionType = 'mvp';
        } else if (q.contains('best sheriff') || q.contains('лучший шериф')) {
          questionType = 'best_sheriff';
        } else if (q.contains('best don') || q.contains('лучший дон')) {
          questionType = 'best_don';
        } else if (q.contains('best civilian') || q.contains('лучший мирн')) {
          questionType = 'best_civilian';
        } else if (q.contains('best mafia') || q.contains('лучшая мафи')) {
          questionType = 'best_mafia';
        }
        return SeasonQueryIntent(seasonId: seasonId, questionType: questionType);
      }

      // "<player> season N" — player stats in a season
      final withoutSeason = query
          .replaceAll(_seasonNumRe, '')
          .replaceAll(_sShortRe, '')
          .trim();
      if (withoutSeason.isNotEmpty) {
        final playerName = _cleanPlayerQuery(withoutSeason);
        if (playerName.isNotEmpty && resolvePlayer(playerName) != null) {
          return PlayerStatsIntent(playerQuery: playerName, seasonId: seasonId);
        }
      }

      // Pure season overview
      return SeasonQueryIntent(seasonId: seasonId);
    }

    // Player stats queries
    if (_playerStatKeywords.hasMatch(query)) {
      final playerName = _extractPlayerName(query);
      if (playerName.isNotEmpty) {
        final statType = _extractStatType(query);
        return PlayerStatsIntent(playerQuery: playerName, statType: statType);
      }
    }

    // Bare player name lookup
    final cleaned = _cleanPlayerQuery(query);
    if (cleaned.isNotEmpty) {
      final candidates = resolvePlayerCandidates(cleaned);
      if (candidates.isNotEmpty) {
        return PlayerStatsIntent(playerQuery: cleaned);
      }
    }

    return UnknownIntent(originalQuery: query);
  }

  String _extractPlayerName(String query) {
    var name = query
        .replaceAll(_playerStatKeywords, '')
        .replaceAll(_seasonNumRe, '')
        .replaceAll(_sShortRe, '')
        .replaceAll(RegExp(r"[''`]s\b"), '')
        .replaceAll(RegExp(r'\b(how\s+many|what\s+is|what|did|does|do|has|have|play|played|the|of|for|in|a|an|сколько|какой|какая)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'[?!.,;:]'), '')
        .trim();
    // Collapse multiple spaces
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name;
  }

  String _cleanPlayerQuery(String query) {
    return query
        .replaceAll(RegExp(r"[''`]s\b"), '')
        .replaceAll(RegExp(r'[?!.,;:]'), '')
        .trim();
  }

  String? _extractStatType(String query) {
    final q = query.toLowerCase();
    if (q.contains('win') && q.contains('rate') || q.contains('винрейт')) return 'winrate';
    if (q.contains('rating') || q.contains('рейтинг')) return 'rating';
    if (q.contains('role') || q.contains('рол')) return 'role';
    if (q.contains('game') || q.contains('игр')) return 'games';
    return null;
  }

  String? _resolveCategory(String text) {
    final t = text.toLowerCase().trim();
    if (t.isEmpty || t.contains('player') || t.contains('overall') || t.contains('игрок')) return 'overall';
    if (t.contains('sheriff') || t.contains('шериф')) return 'sheriff';
    if (t.contains('don') || t.contains('дон')) return 'don';
    if (t.contains('civilian') || t.contains('мирн')) return 'civilian';
    if (t.contains('mafia') || t.contains('мафи')) return 'mafia';
    if (t.contains('game') || t.contains('игр')) return 'games';
    return 'overall';
  }

  String? _categoryToAwardType(String cat) {
    if (cat.contains('sheriff') || cat.contains('шериф')) return 'best_sheriff';
    if (cat.contains('don') || cat.contains('дон')) return 'best_don';
    if (cat.contains('civilian') || cat.contains('мирн')) return 'best_civilian';
    if (cat.contains('mafia') || cat.contains('мафи')) return 'best_mafia';
    return null;
  }
}
