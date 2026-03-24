import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiChatService {
  final String apiKey;
  late final GenerativeModel _model;
  late final ChatSession _chat;
  bool _initialized = false;

  GeminiChatService({required this.apiKey}) {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 4096,
      ),
    );
  }

  /// Initializes the chat session with a system prompt containing all club data.
  void initialize({
    required List<Player> players,
    required List<Game> games,
    required Map<int, List<RatingPlayerStats>> ratings,
    required Map<int, SeasonStats> seasons,
    required List<SeasonConfig> configs,
  }) {
    final systemPrompt = _buildSystemPrompt(
      players: players,
      games: games,
      ratings: ratings,
      seasons: seasons,
      configs: configs,
    );

    _chat = _model.startChat(history: [
      Content.text(systemPrompt),
      Content.model([TextPart(
        'Understood! I have the complete club data loaded. '
        'Ask me anything about players, seasons, ratings, or records.',
      )]),
    ]);

    _initialized = true;
  }

  bool get isInitialized => _initialized;

  /// Sends a user message and returns the bot response.
  Future<String> sendMessage(String message) async {
    if (!_initialized) return 'Chat not initialized. Please wait for data to load.';

    try {
      final response = await _chat.sendMessage(Content.text(message));
      return response.text ?? 'No response generated.';
    } on GenerativeAIException catch (e) {
      return 'Error: ${e.message}';
    } catch (e) {
      return 'Something went wrong. Please try again.';
    }
  }

  String _buildSystemPrompt({
    required List<Player> players,
    required List<Game> games,
    required Map<int, List<RatingPlayerStats>> ratings,
    required Map<int, SeasonStats> seasons,
    required List<SeasonConfig> configs,
  }) {
    final buf = StringBuffer();

    buf.writeln('You are a helpful assistant for a Mafia club stats app.');
    buf.writeln('You answer questions about players, games, seasons, and ratings.');
    buf.writeln('Be concise and use the data below to answer accurately.');
    buf.writeln('Format numbers to 2 decimal places where appropriate.');
    buf.writeln('If you don\'t have enough data to answer, say so.');
    buf.writeln();

    // Season configs
    buf.writeln('=== SEASONS ===');
    for (final c in configs) {
      buf.writeln('Season ${c.id}: "${c.title}", gameLimit=${c.gameLimit}');
    }
    buf.writeln();

    // Season summaries with awards
    buf.writeln('=== SEASON SUMMARIES ===');
    for (final c in configs) {
      final ss = seasons[c.id];
      if (ss == null) continue;

      final seasonGames = games.where((g) => g.seasonId == c.id).toList();
      int cityWins = 0, decided = 0;
      for (final g in seasonGames) {
        if (g.cityWon == true) { cityWins++; decided++; }
        else if (g.cityWon == false) { decided++; }
      }

      final qualified = ss.playerStats
          .where((p) => p.gamesPlayed >= c.gameLimit)
          .toList();
      final winner = qualified.isNotEmpty ? qualified.first : null;

      buf.write('S${c.id}: ${seasonGames.length} games, ');
      if (decided > 0) buf.write('cityWR=${(cityWins / decided * 100).roundTo(1)}%, ');
      if (winner != null) buf.write('winner=${winner.player.displayName}(${winner.ratingCoefficient.roundTo(2)}), ');

      // Awards
      final mvp = _findPlayer(players, ss.mvpPlayerId);
      final bestSheriff = _findPlayer(players, ss.bestSheriffPlayerId);
      final bestDon = _findPlayer(players, ss.bestDonPlayerId);
      final bestCiv = _findPlayer(players, ss.bestCivilianPlayerId);
      final bestMaf = _findPlayer(players, ss.bestMafiaPlayerId);
      if (mvp != null) buf.write('MVP=${mvp.displayName}, ');
      if (bestSheriff != null) buf.write('bestSheriff=${bestSheriff.displayName}, ');
      if (bestDon != null) buf.write('bestDon=${bestDon.displayName}, ');
      if (bestCiv != null) buf.write('bestCivilian=${bestCiv.displayName}, ');
      if (bestMaf != null) buf.write('bestMafia=${bestMaf.displayName}');
      buf.writeln();
    }
    buf.writeln();

    // Player ratings per season (compact)
    buf.writeln('=== PLAYER RATINGS BY SEASON ===');
    buf.writeln('Format: PlayerName: S<id>=rating(games/wins) ...');

    // Group by player
    final playerRatings = <int, List<(int seasonId, RatingPlayerStats stats)>>{};
    for (final entry in ratings.entries) {
      for (final ps in entry.value) {
        if (ps.gamesPlayed == 0) continue;
        playerRatings.putIfAbsent(ps.player.id, () => []);
        playerRatings[ps.player.id]!.add((entry.key, ps));
      }
    }

    for (final entry in playerRatings.entries) {
      final seasonData = entry.value;
      if (seasonData.isEmpty) continue;
      final name = seasonData.first.$2.player.displayName;
      buf.write('$name: ');
      for (final (sid, ps) in seasonData) {
        buf.write('S$sid=${ps.ratingCoefficient.roundTo(2)}'
            '(${ps.gamesPlayed}g/${ps.wins}w/${(ps.winRate * 100).roundTo(1)}%wr'
            '/add=${ps.additionalPoints.roundTo(2)}'
            '/pen=${ps.penaltyPoints.roundTo(2)}'
            '/bm=${ps.bestMovePoints.roundTo(2)}'
            '/fk=${ps.firstKilled}) ');
      }
      buf.writeln();

      // Role stats for this player (all-time)
      final roleGames = <String, int>{};
      final roleWins = <String, int>{};
      for (final (_, ps) in seasonData) {
        for (final (rv, c) in ps.gamesForRole) {
          roleGames[rv] = (roleGames[rv] ?? 0) + c;
        }
        for (final (rv, w) in ps.winByRole) {
          roleWins[rv] = (roleWins[rv] ?? 0) + w;
        }
      }
      final roleParts = <String>[];
      for (final role in Role.values) {
        final g = roleGames[role.sheetValue] ?? 0;
        final w = roleWins[role.sheetValue] ?? 0;
        if (g > 0) roleParts.add('${role.name}=$g/$w');
      }
      if (roleParts.isNotEmpty) {
        buf.writeln('  roles(games/wins): ${roleParts.join(', ')}');
      }
    }

    return buf.toString();
  }

  Player? _findPlayer(List<Player> players, int id) {
    return players.where((p) => p.id == id).firstOrNull;
  }
}
