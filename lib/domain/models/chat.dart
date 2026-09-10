import 'package:flutter/foundation.dart';

import '../enums.dart';

/// One message in a tutor thread.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.language,
    this.streaming = false,
    this.failed = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
        content: json['content'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        language: json['language'] == null
            ? null
            : AppLanguage.fromCode(json['language'] as String),
      );

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final AppLanguage? language;

  /// True while an assistant reply is still streaming in. The endpoint
  /// decides whether to stream (PRD 6.4); the client renders either.
  final bool streaming;
  final bool failed;

  bool get isUser => role == ChatRole.user;

  ChatMessage copyWith({String? content, bool? streaming, bool? failed}) =>
      ChatMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
        language: language,
        streaming: streaming ?? this.streaming,
        failed: failed ?? this.failed,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          other.id == id &&
          other.content == content &&
          other.streaming == streaming &&
          other.failed == failed;

  @override
  int get hashCode => Object.hash(id, content, streaming, failed);
}

/// A conversation, grouped by topic and retained per the tier's limit.
@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.createdAt,
    this.topic,
    this.messages = const <ChatMessage>[],
    this.sourceQuestionId,
  });

  final String id;
  final DateTime createdAt;
  final String? topic;
  final List<ChatMessage> messages;

  /// Set when the thread was opened from a question via "Explain this",
  /// which passes the question context to the endpoint (PRD 6.4).
  final String? sourceQuestionId;

  bool get isEmpty => messages.isEmpty;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatThread copyWith({String? topic, List<ChatMessage>? messages}) =>
      ChatThread(
        id: id,
        createdAt: createdAt,
        topic: topic ?? this.topic,
        messages: messages ?? this.messages,
        sourceQuestionId: sourceQuestionId,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatThread &&
          other.id == id &&
          listEquals(other.messages, messages);

  @override
  int get hashCode => Object.hash(id, Object.hashAll(messages));
}
