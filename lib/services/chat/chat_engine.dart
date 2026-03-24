import 'dart:math' show min;

import 'package:family_mafia_app/enums/role.dart';
import 'package:family_mafia_app/extensions/double_extensions.dart';
import 'package:family_mafia_app/models/chat_message.dart';
import 'package:family_mafia_app/models/game.dart';
import 'package:family_mafia_app/models/player.dart';
import 'package:family_mafia_app/models/query_intent.dart';
import 'package:family_mafia_app/models/rating_player_stats.dart';
import 'package:family_mafia_app/models/season_config.dart';
import 'package:family_mafia_app/models/season_stats.dart';

part 'src/player_resolver.dart';
part 'src/query_parser.dart';
part 'src/intent_handlers.dart';
part 'src/response_formatter.dart';

class ChatEngine {
  final List<Player> players;
  final List<Game> games;
  final Map<int, List<RatingPlayerStats>> ratings;
  final Map<int, SeasonStats> seasons;
  final List<SeasonConfig> configs;

  ChatEngine({
    required this.players,
    required this.games,
    required this.ratings,
    required this.seasons,
    required this.configs,
  });

  ChatMessage process(String query) {
    final intent = _parseQuery(query);
    final response = _handleIntent(intent);
    return ChatMessage(
      sender: MessageSender.bot,
      text: response.text,
      timestamp: DateTime.now(),
      suggestions: response.suggestions,
    );
  }
}
