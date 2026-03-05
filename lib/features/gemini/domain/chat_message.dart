enum MessageRole { user, model }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.createdAtMs,
    this.isLoading = false,
  });

  final MessageRole role;
  final String      text;
  final int         createdAtMs;
  final bool        isLoading;

  bool get isUser  => role == MessageRole.user;
  bool get isModel => role == MessageRole.model;

  ChatMessage copyWith({String? text, bool? isLoading}) => ChatMessage(
        role:        role,
        text:        text ?? this.text,
        createdAtMs: createdAtMs,
        isLoading:   isLoading ?? this.isLoading,
      );

  static ChatMessage loading() => ChatMessage(
        role:        MessageRole.model,
        text:        '',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        isLoading:   true,
      );
}
