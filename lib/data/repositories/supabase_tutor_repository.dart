import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums.dart';
import '../../domain/models/chat.dart';
import 'repositories.dart';
import 'supabase_guard.dart';

/// The tutor over the `ai-chat` Edge Function (PRD 4.5).
///
/// The function holds the endpoint's key, reserves the day's message before
/// forwarding and writes both sides of the exchange to chat_threads and
/// chat_messages. The endpoint does not stream, so a reply arrives as one
/// event.
// ignore_for_file: prefer_initializing_formals

class SupabaseTutorRepository implements TutorRepository {
  SupabaseTutorRepository({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  @override
  Future<List<ChatThread>> threads() async {
    final rows = await supabaseGuard(
      () => _client
          .from('chat_threads')
          .select(
            'id, topic, question_id, created_at, '
            'chat_messages(id, role, content, language, created_at)',
          )
          .order('updated_at', ascending: false),
    );
    return [
      for (final row in rows)
        ChatThread(
          id: row['id'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          topic: row['topic'] as String?,
          sourceQuestionId: row['question_id'] as String?,
          messages: [
            for (final m in (row['chat_messages'] as List? ?? const []))
              ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)),
          ]..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        ),
    ];
  }

  /// The id is minted here and the row is created by the function on the
  /// first message, since the client cannot write chat_threads itself.
  @override
  Future<ChatThread> createThread({
    String? sourceQuestionId,
    String? topic,
  }) async => ChatThread(
    id: _uuidV4(),
    createdAt: DateTime.now(),
    topic: topic,
    sourceQuestionId: sourceQuestionId,
  );

  @override
  Stream<ChatMessage> send({
    required String threadId,
    required String content,
    required AppLanguage language,
    required TutorTopic topic,
    String? questionId,
  }) async* {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke(
        'ai-chat',
        body: {
          'thread_id': threadId,
          'type': topic.name,
          'content': content,
          'language': language.code,
          if (questionId != null) 'question_id': questionId,
        },
      );
    } on FunctionException catch (error) {
      if (error.status == 429) throw _quotaExceeded(error.details);
      rethrow;
    }

    final message = Map<String, dynamic>.from(
      (response.data as Map)['message'] as Map,
    );
    yield ChatMessage(
      id: message['id'] as String,
      role: ChatRole.assistant,
      content: message['content'] as String,
      createdAt: DateTime.parse(message['created_at'] as String),
      language: language,
    );
  }

  @override
  Future<void> deleteThread(String threadId) {
    throw UnsupportedError('deleting a tutor thread is not built yet');
  }

  static QuotaExceededException _quotaExceeded(Object? details) {
    final body = details is Map ? details : const {};
    return QuotaExceededException(
      tier: Tier.fromKey(body['tier'] as String?),
      limit: (body['limit'] as num?)?.toInt() ?? 0,
      // Every counter on the server resets at Sri Lanka midnight (PRD 7.6).
      resetsAt: _nextSltMidnight(),
    );
  }

  static const _slt = Duration(hours: 5, minutes: 30);

  static DateTime _nextSltMidnight() {
    final nowSlt = DateTime.now().toUtc().add(_slt);
    final next = DateTime.utc(
      nowSlt.year,
      nowSlt.month,
      nowSlt.day,
    ).add(const Duration(days: 1));
    return next.subtract(_slt).toLocal();
  }

  static final _random = Random.secure();

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
