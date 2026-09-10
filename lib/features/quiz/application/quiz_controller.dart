import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/content.dart';
import '../../../domain/models/practice.dart';

/// A live practice session.
@immutable
class QuizState {
  const QuizState({
    required this.set,
    required this.index,
    required this.answers,
    this.selectedOptionId,
    this.revealed = false,
    this.secondsLeft,
    this.submitting = false,
    this.result,
  });

  final PracticeSet set;
  final int index;

  /// Answers recorded so far, keyed by question id so a resumed session can
  /// be rebuilt in order.
  final Map<String, SessionAnswer> answers;

  /// The option tapped for the current question, before it is checked.
  final String? selectedOptionId;

  /// True once the answer is checked and the explanation is showing.
  final bool revealed;

  /// Remaining seconds on the current question, or on the paper for a mock
  /// exam. Null when the mode is untimed.
  final int? secondsLeft;
  final bool submitting;
  final SessionResult? result;

  Question get question => set.questions[index];

  bool get isLast => index == set.questions.length - 1;

  int get answeredCount => answers.length;

  double get progress =>
      set.questions.isEmpty ? 0 : (index + (revealed ? 1 : 0)) / set.questions.length;

  bool get isBookmarked => answers[question.id]?.bookmarked ?? false;

  QuizState copyWith({
    PracticeSet? set,
    int? index,
    Map<String, SessionAnswer>? answers,
    String? selectedOptionId,
    bool clearSelection = false,
    bool? revealed,
    int? secondsLeft,
    bool clearTimer = false,
    bool? submitting,
    SessionResult? result,
  }) =>
      QuizState(
        set: set ?? this.set,
        index: index ?? this.index,
        answers: answers ?? this.answers,
        selectedOptionId:
            clearSelection ? null : (selectedOptionId ?? this.selectedOptionId),
        revealed: revealed ?? this.revealed,
        secondsLeft: clearTimer ? null : (secondsLeft ?? this.secondsLeft),
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
      );
}

/// Drives one practice session from first question to scored result.
///
/// Scoring shown mid-session is presentational only. The authoritative score
/// comes back from `rpc/submit_practice_session`, which also writes the
/// answers, updates mastery and feeds the wrong-answer bank (PRD 9.3).
class QuizController extends StateNotifier<AsyncValue<QuizState>> {
  QuizController(this._ref, this._loader) : super(const AsyncValue.loading()) {
    _start();
  }

  final Ref _ref;
  final Future<PracticeSet> Function() _loader;

  Timer? _ticker;
  DateTime? _questionShownAt;

  PracticeRepository get _repository => _ref.read(practiceRepositoryProvider);

  Future<void> _start() async {
    state = const AsyncValue.loading();
    try {
      final set = await _loader();

      // A set with no questions is a content failure, not an empty state the
      // user should be dropped into.
      if (set.questions.isEmpty) {
        state = AsyncValue.error(
          const EmptyPracticeSetException(),
          StackTrace.current,
        );
        return;
      }

      state = AsyncValue.data(
        QuizState(set: set, index: 0, answers: const {}),
      );
      // Issuing a set consumes quota server-side, so the displayed remaining
      // count is refreshed as soon as the set arrives.
      unawaited(_ref.read(entitlementProvider.notifier).syncUsage());
      _beginQuestion();
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  void _beginQuestion() {
    _questionShownAt = DateTime.now();
    _ticker?.cancel();

    final current = state.valueOrNull;
    if (current == null) return;

    final perQuestion = current.set.mode.secondsPerQuestion;
    if (perQuestion == null) {
      state = AsyncValue.data(current.copyWith(clearTimer: true));
      return;
    }

    state = AsyncValue.data(current.copyWith(secondsLeft: perQuestion));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = state.valueOrNull;
      if (now == null || now.revealed) return;
      final left = (now.secondsLeft ?? 0) - 1;
      if (left <= 0) {
        _ticker?.cancel();
        // Running out of time records a skip and reveals, rather than
        // silently advancing past a question the user never saw resolved.
        _reveal(timedOut: true);
      } else {
        state = AsyncValue.data(now.copyWith(secondsLeft: left));
      }
    });
  }

  void select(String optionId) {
    final current = state.valueOrNull;
    if (current == null || current.revealed) return;
    state = AsyncValue.data(current.copyWith(selectedOptionId: optionId));
  }

  /// Checks the selected answer and shows the explanation.
  void check() => _reveal();

  void _reveal({bool timedOut = false}) {
    final current = state.valueOrNull;
    if (current == null || current.revealed) return;

    _ticker?.cancel();

    final selected = current.selectedOptionId;
    final outcome = switch (selected) {
      null => AnswerOutcome.skipped,
      final id when current.question.isCorrect(id) => AnswerOutcome.correct,
      _ => AnswerOutcome.incorrect,
    };

    final elapsed = _questionShownAt == null
        ? 0
        : DateTime.now().difference(_questionShownAt!).inMilliseconds;

    final answers = Map<String, SessionAnswer>.from(current.answers);
    answers[current.question.id] = SessionAnswer(
      questionId: current.question.id,
      outcome: timedOut && selected == null ? AnswerOutcome.skipped : outcome,
      selectedOptionId: selected,
      timeTakenMs: elapsed,
      bookmarked: current.isBookmarked,
    );

    state = AsyncValue.data(
      current.copyWith(revealed: true, answers: answers, clearTimer: true),
    );
  }

  /// Advances, or submits the session when the last question is done.
  Future<void> next() async {
    final current = state.valueOrNull;
    if (current == null) return;

    if (!current.revealed) {
      _reveal();
      return;
    }

    if (current.isLast) {
      await submit();
      return;
    }

    state = AsyncValue.data(
      current.copyWith(
        index: current.index + 1,
        revealed: false,
        clearSelection: true,
      ),
    );
    _beginQuestion();
  }

  Future<void> submit() async {
    final current = state.valueOrNull;
    if (current == null || current.submitting) return;

    _ticker?.cancel();
    state = AsyncValue.data(current.copyWith(submitting: true));

    try {
      final result = await _repository.submitSession(
        sessionId: current.set.sessionId,
        answers: current.answers.values.toList(),
      );
      state = AsyncValue.data(
        current.copyWith(submitting: false, result: result),
      );
      _ref.invalidate(progressProvider);
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> toggleBookmark() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final id = current.question.id;
    final saved = !current.isBookmarked;

    final answers = Map<String, SessionAnswer>.from(current.answers);
    final existing = answers[id];
    answers[id] = existing == null
        ? SessionAnswer(
            questionId: id,
            outcome: AnswerOutcome.skipped,
            bookmarked: saved,
          )
        : existing.copyWith(bookmarked: saved);

    state = AsyncValue.data(current.copyWith(answers: answers));
    await _repository.setBookmark(questionId: id, saved: saved);
  }

  void retry() => _start();

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

class EmptyPracticeSetException implements Exception {
  const EmptyPracticeSetException();
}

/// Describes the set to load. Held as provider state so the quiz screen can
/// be entered by route without threading a set through navigation.
@immutable
class QuizRequest {
  const QuizRequest({
    required this.mode,
    this.subTopicId,
    this.categoryKey,
    this.size,
  });

  final PracticeMode mode;
  final String? subTopicId;
  final String? categoryKey;
  final int? size;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuizRequest &&
          other.mode == mode &&
          other.subTopicId == subTopicId &&
          other.categoryKey == categoryKey &&
          other.size == size;

  @override
  int get hashCode => Object.hash(mode, subTopicId, categoryKey, size);
}

/// The session the quiz screen is currently running.
final activeQuizRequestProvider = StateProvider<QuizRequest?>((ref) => null);

final quizControllerProvider = StateNotifierProvider.autoDispose<QuizController,
    AsyncValue<QuizState>>((ref) {
  final request = ref.watch(activeQuizRequestProvider);
  final repository = ref.watch(practiceRepositoryProvider);

  if (request == null) {
    throw StateError(
      'quizControllerProvider read with no active request. Set '
      'activeQuizRequestProvider before navigating to the quiz.',
    );
  }

  return QuizController(ref, () => switch (request.mode) {
        PracticeMode.dailyChallenge => repository.dailyChallenge(),
        PracticeMode.mockExam =>
          repository.mockExam(length: request.size ?? 50),
        PracticeMode.wrongAnswerDrill => repository.wrongAnswerDrill(),
        _ => repository.practiceSet(
            mode: request.mode,
            subTopicId: request.subTopicId,
            categoryKey: request.categoryKey,
            size: request.size,
          ),
      });
});
