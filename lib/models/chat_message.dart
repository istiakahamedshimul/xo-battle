class ChatMessage {
  final String senderId;
  final String message;
  final String type; // text / emoji
  final DateTime createdAt;

  ChatMessage({
    required this.senderId,
    required this.message,
    required this.type,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        senderId: map['senderId'] ?? '',
        message: map['message'] ?? '',
        type: map['type'] ?? 'text',
        createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'message': message,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
      };
}
