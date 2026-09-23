import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'content.dart';
import 'localized_text.dart';

/// A set of questions served by `rpc/get_practice_set`.
///
/// The quota check and its increment happen inside one database transaction
/// on the server (PRD 9.3), so by the time the client holds a set the
/// allowance has already been consumed.
@immutable
class PracticeSet {
  const PracticeSet({
    required this.sessionId,
    required this.mode,
    required this.questions,
    this.subTopicId,
    this.categoryKey,
    this.startedAt,
    this.totalSeconds,
    this.negativeMarkPerWrong = 0,
  });

  /// Reads what `rpc/get_practice_set`, `rpc/get_daily_challenge` and
  /// `rpc/get_mock_exam` return.
  ///
  /// Timing and negative marking are not server fields: they follow from the
  /// mode (PRD 6.3), so they are derived here rather than round-tripped.
  factory PracticeSet.fromJson(
    Map<String, dynamic> json, {
    String? subTopicId,
    String? categoryKey,
  }) {
    final mode = PracticeMode.fromKey(json['mode'] as String?);
    final questions = [
      for (final q in (json['questions'] as List? ?? const []))
        Question.fromJson(Map<String, dynamic>.from(q as Map)),
    ];
    final perQuestion = mode.secondsPerQuestion;

    return PracticeSet(
      sessionId: json['session_id'] as String,
      mode: mode,
      questions: questions,
      subTopicId: subTopicId,
      categoryKey: categoryKey,
      startedAt: DateTime.now(),
      totalSeconds: mode == PracticeMode.mockExam && perQuestion != null
          ? questions.length * perQuestion
          : null,
      negativeMarkPerWrong: mode == PracticeMode.mockExam ? 0.25 : 0,
    );
  }

  final String sessionId;
  final PracticeMode mode;
  final List<Question> questions;
  final String? subTopicId;
  final String? categoryKey;
  final DateTime? startedAt;

  /// Total seconds for a mock exam, or null when the set is per-question
  /// timed or untimed.
  final int? totalSeconds;

  /// Mock exams apply negative marking (PRD 6.3).
  final double negativeMarkPerWrong;

  int get length => questions.length;

  PracticeSet copyWith({List<Question>? questions}) => PracticeSet(
        sessionId: sessionId,
        mode: mode,
        questions: questions ?? this.questions,
        subTopicId: subTopicId,
        categoryKey: categoryKey,
        startedAt: startedAt,
        totalSeconds: totalSeconds,
        negativeMarkPerWrong: negativeMarkPerWrong,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PracticeSet &&
          other.sessionId == sessionId &&
          listEquals(other.questions, questions);

  @override
  int get hashCode => Object.hash(sessionId, Object.hashAll(questions));
}

/// One answer within a session.
@immutable
class SessionAnswer {
  const SessionAnswer({
    required this.questionId,
    required this.outcome,
    this.selectedOptionId,
    this.timeTakenMs = 0,
    this.markedForReview = false,
    this.bookmarked = false,
  });

  final String questionId;
  final AnswerOutcome outcome;
  final String? selectedOptionId;

  /// Milliseconds spent on the question, for the time-per-question
  /// breakdown in PRD 6.3.
  final int timeTakenMs;
  final bool markedForReview;
  final bool bookmarked;

  bool get isCorrect => outcome == AnswerOutcome.correct;

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'outcome': outcome.name,
        'selected_option_id': selectedOptionId,
        'time_taken_ms': timeTakenMs,
        'marked_for_review': markedForReview,
        'bookmarked': bookmarked,
      };

  SessionAnswer copyWith({
    AnswerOutcome? outcome,
    String? selectedOptionId,
    int? timeTakenMs,
    bool? markedForReview,
    bool? bookmarked,
  }) =>
      SessionAnswer(
        questionId: questionId,
        outcome: outcome ?? this.outcome,
        selectedOptionId: selectedOptionId ?? this.selectedOptionId,
        timeTakenMs: timeTakenMs ?? this.timeTakenMs,
        markedForReview: markedForReview ?? this.markedForReview,
        bookmarked: bookmarked ?? this.bookmarked,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionAnswer &&
          other.questionId == questionId &&
          other.outcome == outcome &&
          other.selectedOptionId == selectedOptionId &&
          other.bookmarked == bookmarked &&
          other.markedForReview == markedForReview;

  @override
  int get hashCode => Object.hash(
      questionId, outcome, selectedOptionId, bookmarked, markedForReview);
}

/// Per-sub-topic accuracy inside a result.
@immutable
class SubTopicScore {
  const SubTopicScore({
    required this.subTopicId,
    required this.name,
    required this.correct,
    required this.total,
  });

  /// The server sends `name` as all three languages at once, the same as
  /// everywhere else content is returned; the result screen shows one.
  factory SubTopicScore.fromJson(
    Map<String, dynamic> json,
    AppLanguage language,
  ) =>
      SubTopicScore(
        subTopicId: json['sub_topic_id'] as String,
        name: LocalizedText.fromJson(Map<String, dynamic>.from(json['name'] as Map)).resolve(language),
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  final String subTopicId;
  final String name;
  final int correct;
  final int total;

  int get accuracyPct => total == 0 ? 0 : ((correct / total) * 100).round();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubTopicScore &&
          other.subTopicId == subTopicId &&
          other.correct == correct &&
          other.total == total;

  @override
  int get hashCode => Object.hash(subTopicId, correct, total);
}

/// The scored outcome of a session. Scoring happens server-side in
/// `rpc/submit_practice_session` (PRD 9.3); this is what comes back.
@immutable
class SessionResult {
  const SessionResult({
    required this.sessionId,
    required this.mode,
    required this.correct,
    required this.incorrect,
    required this.skipped,
    required this.totalTime,
    this.breakdown = const <SubTopicScore>[],
    this.ownHistory = const <int>[],
    this.wrongQuestionIds = const <String>[],
    this.completedAt,
  });

  /// Reads what `rpc/submit_practice_session` returns.
  ///
  /// [totalTime] is passed in rather than parsed: the server records a
  /// duration but does not return it, and the client already knows how long
  /// each question took.
  factory SessionResult.fromJson(
    Map<String, dynamic> json, {
    required AppLanguage language,
    required Duration totalTime,
  }) =>
      SessionResult(
        sessionId: json['session_id'] as String,
        mode: PracticeMode.fromKey(json['mode'] as String?),
        correct: (json['correct_count'] as num?)?.toInt() ?? 0,
        incorrect: (json['incorrect_count'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped_count'] as num?)?.toInt() ?? 0,
        totalTime: totalTime,
        breakdown: [
          for (final b in (json['breakdown'] as List? ?? const []))
            SubTopicScore.fromJson(
                Map<String, dynamic>.from(b as Map), language),
        ],
        ownHistory: [
          for (final a in (json['own_history'] as List? ?? const []))
            (a as num).toInt(),
        ],
        wrongQuestionIds: [
          for (final id in (json['wrong_question_ids'] as List? ?? const []))
            id as String,
        ],
        completedAt: DateTime.now(),
      );

  final String sessionId;
  final PracticeMode mode;
  final int correct;
  final int incorrect;
  final int skipped;
  final Duration totalTime;
  final List<SubTopicScore> breakdown;

  /// The user's own recent session accuracies, oldest first. PRD 6.3
  /// compares against prior sessions of the same user and nothing else.
  final List<int> ownHistory;
  final List<String> wrongQuestionIds;
  final DateTime? completedAt;

  int get answered => correct + incorrect;
  int get total => correct + incorrect + skipped;

  int get scorePct => total == 0 ? 0 : ((correct / total) * 100).round();

  Duration get averageTime => answered == 0
      ? Duration.zero
      : Duration(milliseconds: totalTime.inMilliseconds ~/ answered);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionResult &&
          other.sessionId == sessionId &&
          other.correct == correct &&
          other.incorrect == incorrect &&
          other.skipped == skipped;

  @override
  int get hashCode => Object.hash(sessionId, correct, incorrect, skipped);
}

/// One completed session on the history chart, with the day it happened on
/// so the bars can be labelled.
@immutable
class SessionPoint {
  const SessionPoint({required this.at, required this.accuracyPct});

  factory SessionPoint.fromJson(Map<String, dynamic> json) => SessionPoint(
        at: DateTime.parse(json['at'] as String).toLocal(),
        accuracyPct: (json['accuracy'] as num?)?.toInt() ?? 0,
      );

  final DateTime at;
  final int accuracyPct;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPoint &&
          other.at == at &&
          other.accuracyPct == accuracyPct;

  @override
  int get hashCode => Object.hash(at, accuracyPct);
}

/// What the results dashboard shows for a chosen [ResultsRange]: the user's
/// own figures over that window, and nothing about anybody else (PRD 6.6).
@immutable
class RangeStats {
  const RangeStats({
    this.answered = 0,
    this.correct = 0,
    this.skipped = 0,
    this.totalTime = Duration.zero,
    this.breakdown = const <SubTopicScore>[],
    this.history = const <SessionPoint>[],
  });

  /// Reads what `rpc/get_results_summary` returns. `breakdown[].name` is the
  /// raw `display_names` map, as it is on a submitted session.
  factory RangeStats.fromJson(
    Map<String, dynamic> json,
    AppLanguage language,
  ) =>
      RangeStats(
        answered: (json['answered'] as num?)?.toInt() ?? 0,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        skipped: (json['skipped'] as num?)?.toInt() ?? 0,
        totalTime: Duration(
          milliseconds: (json['total_time_ms'] as num?)?.toInt() ?? 0,
        ),
        breakdown: [
          for (final b in (json['breakdown'] as List? ?? const []))
            SubTopicScore.fromJson(
              Map<String, dynamic>.from(b as Map),
              language,
            ),
        ],
        history: [
          for (final h in (json['history'] as List? ?? const []))
            SessionPoint.fromJson(Map<String, dynamic>.from(h as Map)),
        ],
      );

  /// Questions the user actually answered — skips are excluded, so accuracy
  /// is not punished for a question never attempted.
  final int answered;
  final int correct;
  final int skipped;
  final Duration totalTime;

  /// Accuracy per sub-topic over the range, worst first.
  final List<SubTopicScore> breakdown;

  /// The sessions behind the trend bars, oldest first.
  final List<SessionPoint> history;

  bool get isEmpty => answered == 0 && skipped == 0;

  int get accuracyPct => answered == 0 ? 0 : ((correct / answered) * 100).round();

  Duration get averageTime => answered == 0
      ? Duration.zero
      : Duration(milliseconds: totalTime.inMilliseconds ~/ answered);
}

/// A question saved by the user, or one waiting in the wrong-answer bank.
@immutable
class SavedQuestion {
  const SavedQuestion({
    required this.questionId,
    required this.subTopicName,
    required this.stemPreview,
    this.savedAt,
    this.nextReviewAt,
    this.reviewCount = 0,
  });

  final String questionId;
  final String subTopicName;
  final String stemPreview;
  final DateTime? savedAt;

  /// Set only for wrong-answer bank entries, which resurface through spaced
  /// repetition (PRD 6.3).
  final DateTime? nextReviewAt;
  final int reviewCount;

  SavedQuestion copyWith({DateTime? nextReviewAt, int? reviewCount}) =>
      SavedQuestion(
        questionId: questionId,
        subTopicName: subTopicName,
        stemPreview: stemPreview,
        savedAt: savedAt,
        nextReviewAt: nextReviewAt ?? this.nextReviewAt,
        reviewCount: reviewCount ?? this.reviewCount,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SavedQuestion && other.questionId == questionId;

  @override
  int get hashCode => questionId.hashCode;
}
