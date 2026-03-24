enum MessageSender { user, bot }

class ChatMessage {
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final List<String> suggestions;

  const ChatMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.suggestions = const [],
  });
}
