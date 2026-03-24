import 'package:family_mafia_app/models/chat_message.dart';
import 'package:family_mafia_app/providers/app_providers.dart';
import 'package:family_mafia_app/repositories/games_repository.dart';
import 'package:family_mafia_app/repositories/players_repository.dart';
import 'package:family_mafia_app/repositories/rating_repository.dart';
import 'package:family_mafia_app/repositories/season_repository.dart';
import 'package:family_mafia_app/services/gemini_chat_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Gemini API key (same pattern as Sheets key) ─────────────────────────

const _dartDefineGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

final geminiApiKeyProvider = Provider<String?>((ref) {
  if (_dartDefineGeminiKey.isNotEmpty) return _dartDefineGeminiKey;
  final env = ref.watch(envJsonProvider).valueOrNull ?? {};
  final envKey = env['GEMINI_API_KEY'] ?? '';
  return envKey.isNotEmpty ? envKey : null;
});

// ── Gemini service singleton ────────────────────────────────────────────

final geminiChatServiceProvider = Provider<GeminiChatService?>((ref) {
  final apiKey = ref.watch(geminiApiKeyProvider);
  if (apiKey == null || apiKey.isEmpty) return null;
  return GeminiChatService(apiKey: apiKey);
});

// ── Chat state ──────────────────────────────────────────────────────────

final chatMessagesProvider = StateProvider<List<ChatMessage>>((ref) => [
      ChatMessage(
        sender: MessageSender.bot,
        text:
            'Hi! Ask me anything about players, seasons, or records.',
        timestamp: DateTime.now(),
        suggestions: [
          'Who is the best player?',
          'Tell me about the latest season',
          'Who has the highest win rate as sheriff?',
          'Compare the top 2 players',
        ],
      ),
    ]);

/// Whether a Gemini request is currently in-flight.
final chatLoadingProvider = StateProvider<bool>((ref) => false);

/// Sends a user query via Gemini (or shows error if no API key).
Future<void> processQuery(WidgetRef ref, String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return;

  final messages = ref.read(chatMessagesProvider);
  final userMsg = ChatMessage(
    sender: MessageSender.user,
    text: trimmed,
    timestamp: DateTime.now(),
  );

  // Show user message immediately
  ref.read(chatMessagesProvider.notifier).state = [...messages, userMsg];
  ref.read(chatLoadingProvider.notifier).state = true;

  try {
    final gemini = ref.read(geminiChatServiceProvider);
    if (gemini == null) {
      _addBotMessage(ref, 'Gemini API key not configured.\n\n'
          'Add GEMINI_API_KEY to assets/.env.json or pass via:\n'
          'flutter run --dart-define=GEMINI_API_KEY=your_key\n\n'
          'Get a free key at aistudio.google.com');
      return;
    }

    // Initialize on first use
    if (!gemini.isInitialized) {
      gemini.initialize(
        players: ref.read(playersRepositoryProvider),
        games: ref.read(gamesRepositoryProvider),
        ratings: ref.read(ratingRepositoryProvider),
        seasons: ref.read(seasonRepositoryProvider),
        configs: ref.read(loadedSeasonConfigsProvider),
      );
    }

    final response = await gemini.sendMessage(trimmed);
    _addBotMessage(ref, response);
  } catch (e) {
    _addBotMessage(ref, 'Something went wrong: $e');
  } finally {
    ref.read(chatLoadingProvider.notifier).state = false;
  }
}

void _addBotMessage(WidgetRef ref, String text) {
  final messages = ref.read(chatMessagesProvider);
  ref.read(chatMessagesProvider.notifier).state = [
    ...messages,
    ChatMessage(
      sender: MessageSender.bot,
      text: text,
      timestamp: DateTime.now(),
    ),
  ];
}
