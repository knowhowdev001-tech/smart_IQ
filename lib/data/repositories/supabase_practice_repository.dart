import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums.dart';
import '../../domain/models/content.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/models/practice.dart';
import '../../domain/models/user_profile.dart';
import '../auth/session_store.dart';
import 'repositories.dart';
import 'supabase_content_repository.dart';
import 'supabase_guard.dart';

/// Practice, scoring and progress.
///
/// Every method here is a SECURITY DEFINER RPC rather than a table read: the
/// question bank is invisible to the client, and the quota check, the set
/// selection and the counter increment all happen inside one server
/// transaction (PRD 9.3). Scoring is the same — the client sends which
/// option was tapped and the server decides whether it was right.
// ignore_for_file: prefer_initializing_formals

class SupabasePracticeRepository implements PracticeRepository {
  SupabasePracticeRepository({
    required SupabaseClient client,
    required SessionStore sessions,
    required SupabaseContentRepository content,
    required AppLanguage Function() language,
  })  : _client = client,
        _sessions = sessions,
        _content = content,
        _language = language;

  final SupabaseClient _client;
  final SessionStore _sessions;
  final SupabaseContentRepository _content;
  final AppLanguage Function() _language;

  /// Preview length for a saved question, matching the mock so the list
  /// looks the same either side of the swap.
  static const _previewLength = 90;

  @override
  Future<PracticeSet> practiceSet({
    required PracticeMode mode,
    String? subTopicId,
    String? categoryKey,
    int? size,
  }) async {
    final categoryId =
        categoryKey == null ? null : await _content.categoryId(categoryKey);

    final json = await _rpc(
      'get_practice_set',
      {
        'p_mode': mode.key,
        'p_sub_topic_id': subTopicId,
        'p_category_id': categoryId,
        if (size != null) 'p_size': size,
      },
      mode: mode,
    );
    return PracticeSet.fromJson(
      json,
      subTopicId: subTopicId,
      categoryKey: categoryKey,
    );
  }

  @override
  Future<PracticeSet> dailyChallenge() async {
    final json = await _rpc('get_daily_challenge', const {},
        mode: PracticeMode.dailyChallenge);
    return PracticeSet.fromJson(json);
  }

  @override
  Future<PracticeSet> mockExam({required int length}) async {
    final json = await _rpc('get_mock_exam', {'p_size': length},
        mode: PracticeMode.mockExam);
    return PracticeSet.fromJson(json);
  }

  @override
  Future<PracticeSet> wrongAnswerDrill() =>
      practiceSet(mode: PracticeMode.wrongAnswerDrill);

  @override
  Future<SessionResult> submitSession({
    required String sessionId,
    required List<SessionAnswer> answers,
  }) async {
    final totalMs =
        answers.fold<int>(0, (sum, answer) => sum + answer.timeTakenMs);

    // The RPC's column names, not the model's: it reads the payload with
    // jsonb_to_recordset, so the keys have to match exactly.
    final payload = [
      for (final answer in answers)
        {
          'question_id': answer.questionId,
          'selected_option': answer.selectedOptionId,
          'time_taken': answer.timeTakenMs ~/ 1000,
          'marked_for_review': answer.markedForReview,
        },
    ];

    final json = await _rpc('submit_practice_session', {
      'p_session_id': sessionId,
      'p_answers': payload,
      'p_duration_seconds': totalMs ~/ 1000,
    });

    // Bookmarks are a separate table with direct client access, so they are
    // written here rather than being smuggled into the submission.
    for (final answer in answers.where((a) => a.bookmarked)) {
      await setBookmark(questionId: answer.questionId, saved: true);
    }

    return SessionResult.fromJson(
      json,
      language: _language(),
      totalTime: Duration(milliseconds: totalMs),
    );
  }

  /// No server support yet: a session interrupted mid-quiz stays open on the
  /// server and is simply not offered back. Returning null keeps the screens
  /// on the path they already take when there is nothing to resume.
  @override
  Future<PracticeSet?> resumableSession() async => null;

  @override
  Future<void> discardResumableSession() async {}

  @override
  Future<ProgressSummary> progress() async {
    final json = await _rpc('get_progress', const {});
    return ProgressSummary.fromJson(json);
  }

  @override
  Future<List<SavedQuestion>> bookmarks() async {
    final rows = await supabaseGuard(
      () => _client
          .from('bookmarks')
          .select('question_id, created_at')
          .order('created_at', ascending: false),
    );
    return _hydrate(
      rows,
      savedAt: (row) => DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  @override
  Future<void> setBookmark({
    required String questionId,
    required bool saved,
  }) async {
    final userId = _sessions.userId;
    if (userId == null) throw const UnauthenticatedException();

    await supabaseGuard(() async {
      if (saved) {
        await _client.from('bookmarks').upsert(
          {'user_id': userId, 'question_id': questionId},
          onConflict: 'user_id,question_id',
        );
      } else {
        await _client
            .from('bookmarks')
            .delete()
            .eq('question_id', questionId);
      }
    });
  }

  @override
  Future<List<SavedQuestion>> wrongAnswerBank() async {
    final rows = await supabaseGuard(
      () => _client
          .from('wrong_answer_bank')
          .select('question_id, next_review_at, review_count, last_wrong_at')
          .isFilter('retired_at', null)
          .order('next_review_at'),
    );
    return _hydrate(
      rows,
      savedAt: (row) => DateTime.parse(row['last_wrong_at'] as String).toLocal(),
      nextReviewAt: (row) =>
          DateTime.parse(row['next_review_at'] as String).toLocal(),
      reviewCount: (row) => (row['review_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Turns rows that hold only a question id into list entries.
  ///
  /// `get_questions_by_ids` is the only way back to a stem, and it serves
  /// exactly the questions the user has already earned the right to see:
  /// bookmarked, answered, or sitting in the wrong-answer bank.
  Future<List<SavedQuestion>> _hydrate(
    List<Map<String, dynamic>> rows, {
    required DateTime Function(Map<String, dynamic>) savedAt,
    DateTime Function(Map<String, dynamic>)? nextReviewAt,
    int Function(Map<String, dynamic>)? reviewCount,
  }) async {
    if (rows.isEmpty) return const [];

    final ids = [for (final row in rows) row['question_id'] as String];
    final questions = await supabaseGuard(
      () => _client.rpc<dynamic>('get_questions_by_ids', params: {
        'p_ids': ids,
      }),
    );
    final byId = {
      for (final q in (questions as List? ?? const []))
        (q as Map)['id'] as String:
            Question.fromJson(Map<String, dynamic>.from(q)),
    };
    final language = _language();

    return [
      for (final row in rows)
        if (byId[row['question_id']] case final question?)
          SavedQuestion(
            questionId: question.id,
            subTopicName: question.subTopicName.resolve(language),
            stemPreview: _preview(question.stem.resolve(language)),
            savedAt: savedAt(row),
            nextReviewAt: nextReviewAt?.call(row),
            reviewCount: reviewCount?.call(row) ?? 0,
          ),
    ];
  }

  String _preview(String stem) => stem.length <= _previewLength
      ? stem
      : '${stem.substring(0, _previewLength)}…';

  /// Calls an RPC and returns its object, turning a refused call into the
  /// exception the screens branch on.
  ///
  /// `quota_exceeded` is handled here rather than in [supabaseGuard] because
  /// the prompt has to name the limit that was hit, and only the entitlement
  /// knows what it was.
  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> params, {
    PracticeMode? mode,
  }) async {
    try {
      final result = await supabaseGuard(
        () => _client.rpc<dynamic>(name, params: params),
      );
      return Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (error) {
      if (error.hint != 'quota_exceeded') rethrow;
      throw await _quotaExceeded(mode);
    }
  }

  Future<QuotaExceededException> _quotaExceeded(PracticeMode? mode) async {
    var tier = Tier.free;
    var limit = 0;
    try {
      final json = await _client.rpc<dynamic>('get_entitlement');
      final entitlement =
          Entitlement.fromJson(Map<String, dynamic>.from(json as Map));
      tier = entitlement.tier;
      limit = mode == PracticeMode.mockExam
          ? entitlement.limits.mockExamsPerMonth
          : entitlement.limits.questionsPerDay;
    } catch (_) {
      // The refusal is what matters; an unavailable entitlement only costs
      // the exact number in the message.
    }
    return QuotaExceededException(
      tier: tier,
      limit: limit,
      // Monthly allowances reset on the first of the month, daily ones at
      // the Sri Lanka midnight every counter in the server uses (PRD 7.6).
      resetsAt: mode == PracticeMode.mockExam
          ? _nextSltMonth()
          : _nextSltMidnight(),
    );
  }

  static const _slt = Duration(hours: 5, minutes: 30);

  static DateTime _nextSltMidnight() {
    final nowSlt = DateTime.now().toUtc().add(_slt);
    final next = DateTime.utc(nowSlt.year, nowSlt.month, nowSlt.day)
        .add(const Duration(days: 1));
    return next.subtract(_slt).toLocal();
  }

  static DateTime _nextSltMonth() {
    final nowSlt = DateTime.now().toUtc().add(_slt);
    final next = DateTime.utc(nowSlt.year, nowSlt.month + 1, 1);
    return next.subtract(_slt).toLocal();
  }
}
