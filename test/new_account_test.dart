import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/mock/mock_repositories.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/practice.dart';

/// A freshly signed-up user must start at zero.
///
/// Progress in this product is self-referential (PRD 6.6), so anything shown
/// on the home dashboard is a claim about what *this* user has done. Seeding
/// it means showing a new account someone else's streak, readiness and weak
/// areas, which is both wrong and misleading about their preparation.
void main() {
  late MockBackendState state;
  late MockPracticeRepository practice;
  late MockContentRepository content;

  setUp(() {
    state = MockBackendState(tier: Tier.basic);
    practice = MockPracticeRepository(state);
    content = MockContentRepository(state);
  });

  group('a new account', () {
    test('has no profile until one is created', () {
      expect(state.profile, isNull);
      expect(state.signedIn, isFalse);
    });

    test('reports zero progress and no weak areas', () async {
      final progress = await practice.progress();

      expect(progress.questionsAnswered, 0);
      expect(progress.sessionsCompleted, 0);
      expect(progress.streakDays, 0);
      expect(progress.readinessScore, 0);
      expect(progress.overallAccuracy, 0);
      expect(progress.recentAccuracy, isEmpty);

      // This is the specific regression: the home Performance section was
      // showing seeded sub-topics at 38%, 45% and 46% on a brand new account.
      expect(progress.weakAreas, isEmpty);
    });

    test('shows no mastery percentage on any sub-topic', () async {
      for (final category in ['gk', 'ca', 'iq', 'mock']) {
        for (final topic in await content.subTopics(category)) {
          expect(
            topic.mastery,
            isNull,
            reason: '${topic.id} reported mastery before any attempt',
          );
        }
      }
    });

    test('has spent no quota', () {
      expect(state.usage.questionsToday, 0);
      expect(state.usage.aiMessagesToday, 0);
      expect(state.usage.mockExamsThisMonth, 0);
    });

    test('has an empty wrong-answer bank', () async {
      expect(await practice.wrongAnswerBank(), isEmpty);
    });
  });

  group('after practising', () {
    /// Answers one question, right or wrong, as its own session.
    Future<void> answer(String questionId, {required bool correct}) async {
      await practice.submitSession(
        sessionId: 'sess-$questionId-${DateTime.now().microsecondsSinceEpoch}',
        answers: [
          SessionAnswer(
            questionId: questionId,
            outcome:
                correct ? AnswerOutcome.correct : AnswerOutcome.incorrect,
            selectedOptionId: 'opt-a',
            timeTakenMs: 4000,
          ),
        ],
      );
    }

    test('progress reflects what the user actually did', () async {
      await answer('q-age-1', correct: true);
      await answer('q-history-1', correct: false);

      final progress = await practice.progress();

      expect(progress.questionsAnswered, 2);
      expect(progress.sessionsCompleted, 2);
      expect(progress.overallAccuracy, 0.5);
      expect(progress.streakDays, 1);
      expect(progress.recentAccuracy, [100, 0]);
    });

    test('a weak area appears only once there is enough evidence', () async {
      // One wrong answer is not evidence of weakness in a sub-topic.
      await answer('q-age-1', correct: false);
      expect((await practice.progress()).weakAreas, isEmpty);

      await answer('q-age-1', correct: false);
      expect((await practice.progress()).weakAreas, isEmpty);

      // Three attempts crosses the sample threshold, and 0% is well under it.
      await answer('q-age-1', correct: false);
      final weakAreas = (await practice.progress()).weakAreas;

      expect(weakAreas, hasLength(1));
      expect(weakAreas.single.subTopicId, 'iq-age');
      expect(weakAreas.single.accuracy, 0);
      expect(weakAreas.single.sampleSize, 3);
    });

    test('a sub-topic answered well is not called weak', () async {
      await answer('q-age-1', correct: true);
      await answer('q-age-1', correct: true);
      await answer('q-age-1', correct: true);

      expect((await practice.progress()).weakAreas, isEmpty);
    });

    test('mastery appears on the attempted sub-topic only', () async {
      await answer('q-age-1', correct: true);
      await answer('q-age-1', correct: false);

      final topics = await content.subTopics('iq');
      final attempted = topics.firstWhere((t) => t.id == 'iq-age');
      final untouched = topics.firstWhere((t) => t.id == 'iq-clocks');

      expect(attempted.mastery, 50);
      expect(untouched.mastery, isNull);
    });

    test('the wrong-answer bank holds wrong answers and retires them',
        () async {
      await answer('q-age-1', correct: false);
      expect(await practice.wrongAnswerBank(), hasLength(1));

      // Getting it right later takes it out of the review queue.
      await answer('q-age-1', correct: true);
      expect(await practice.wrongAnswerBank(), isEmpty);
    });
  });
}
