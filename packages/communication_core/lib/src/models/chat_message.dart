enum MessageOrigin { local, remote }

class ChatMessage {
  final String text;
  final MessageOrigin origin;
  final DateTime timestamp;

  const ChatMessage({
    required this.text,
    required this.origin,
    required this.timestamp,
  });

  factory ChatMessage.local(String text) => ChatMessage(
        text: text,
        origin: MessageOrigin.local,
        timestamp: DateTime.now(),
      );

  factory ChatMessage.remote(String text) => ChatMessage(
        text: text,
        origin: MessageOrigin.remote,
        timestamp: DateTime.now(),
      );
}