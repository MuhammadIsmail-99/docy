class MessageModel {
  final String id;
  final String conversationId;
  final String senderRole; // 'patient' | 'doctor' | 'ai'
  final String content;
  final bool isRedFlag;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderRole,
    required this.content,
    required this.isRedFlag,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      conversationId: json['conversation_id'],
      senderRole: json['sender_role'],
      content: json['content'],
      isRedFlag: json['is_red_flag'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
