import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/data/repositories/repositories.dart';
import 'package:smart_iq/data/repositories/supabase_guard.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/practice.dart';
import 'package:smart_iq/domain/models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fixtures are shaped exactly like the RPC output in
/// supabase/migrations/0011, 0012 and 0009 — the point of these tests is that
/// the two sides keep agreeing.
void main() {
  group('PracticeSet.fromJson', () {
    final questionJson = {
      'id': 'q1',
      'sub_topic_id': 'st1',
      'category_key': 'general_knowledge',
      'difficulty': 'easy',
      'correct_option_id': 'o2',
      'shuffle_options': true,
      'category_name': {'si': 'ප', 'ta': 'ப', 'en': 'General Knowledge'},
      'sub_topic_name': {'si': 'භූ', 'ta': 'நி', 'en': 'Geography'},
      'stem': {'si': '[SI] Capital?', 'ta': '[TA] Capital?', 'en': 'Capital?'},
      'explanation': {'en': 'Because.'},
      'explanation_media': <dynamic>[],
      'options': [
        {
          'id': 'o1',
          'option_key': 'A',
          'sort_order': 0,
          'text': {'en': 'Colombo'},
        },
        {
          'id': 'o2',
          'option_key': 'B',
          'sort_order': 1,
          'text': {'en': 'Kotte'},
        },
      ],
    };

    test('reads a quick set', () {
      final set = PracticeSet.fromJson({
        'session_id': 's1',
        'mode': 'quick',
        'question_count': 1,
        'questions': [questionJson],
      }, categoryKey: 'general_knowledge');

      expect(set.sessionId, 's1');
      expect(set.mode, PracticeMode.quick);
      expect(set.questions.single.id, 'q1');
      expect(set.questions.single.options.length, 2);
      expect(set.categoryKey, 'general_knowledge');
      // Only mock exams are wall-clock timed and negatively marked.
      expect(set.totalSeconds, isNull);
      expect(set.negativeMarkPerWrong, 0);
    });

    test('a mock exam carries its clock and negative marking', () {
      final set = PracticeSet.fromJson({
        'session_id': 's2',
        'mode': 'mock_exam',
        'questions': [questionJson, questionJson],
      });

      expect(set.mode, PracticeMode.mockExam);
      expect(set.totalSeconds, 2 * 72);
      expect(set.negativeMarkPerWrong, 0.25);
    });

    test('daily_challenge maps to the Dart name', () {
      final set = PracticeSet.fromJson({
        'session_id': 's3',
        'mode': 'daily_challenge',
        'questions': <dynamic>[],
      });
      expect(set.mode, PracticeMode.dailyChallenge);
    });
  });

  group('SessionResult.fromJson', () {
    final json = {
      'session_id': 's1',
      'mode': 'quick',
      'question_count': 3,
      'correct_count': 2,
      'incorrect_count': 1,
      'skipped_count': 0,
      'score': 2,
      'accuracy': 67,
      'streak_days': 4,
      'breakdown': [
        {
          'sub_topic_id': 'st1',
          'name': {'si': 'භූගෝල', 'ta': 'நிலவியல்', 'en': 'Geography'},
          'correct': 2,
          'total': 3,
        },
      ],
      'wrong_question_ids': ['q3'],
      'own_history': [40, 67],
    };

    test('reads counts, breakdown and the wrong-answer ids', () {
      final result = SessionResult.fromJson(
        json,
        language: AppLanguage.english,
        totalTime: const Duration(seconds: 30),
      );

      expect(result.correct, 2);
      expect(result.incorrect, 1);
      expect(result.skipped, 0);
      expect(result.scorePct, 67);
      expect(result.wrongQuestionIds, ['q3']);
      expect(result.ownHistory, [40, 67]);
      expect(result.breakdown.single.name, 'Geography');
      expect(result.totalTime, const Duration(seconds: 30));
    });

    test('the breakdown name follows the reader language', () {
      final result = SessionResult.fromJson(
        json,
        language: AppLanguage.sinhala,
        totalTime: Duration.zero,
      );
      expect(result.breakdown.single.name, 'භූගෝල');
    });
  });

  test('ProgressSummary.fromJson reads the dashboard', () {
    final progress = ProgressSummary.fromJson({
      'streak_days': 3,
      'readiness_score': 42,
      'questions_answered': 20,
      'sessions_completed': 4,
      'overall_accuracy': 0.65,
      'recent_accuracy': [50, 60, 80],
      'weak_areas': [
        {
          'sub_topic_id': 'st9',
          // Already resolved server-side, unlike content elsewhere.
          'name': 'Numerical reasoning',
          'accuracy': 45,
          'sample_size': 8,
        },
      ],
    });

    expect(progress.streakDays, 3);
    expect(progress.readinessScore, 42);
    expect(progress.overallAccuracy, closeTo(0.65, 0.001));
    expect(progress.recentAccuracy, [50, 60, 80]);
    expect(progress.weakAreas.single.name, 'Numerical reasoning');
    expect(progress.weakAreas.single.accuracy, 45);
  });

  test('empty progress parses to zeroes', () {
    final progress = ProgressSummary.fromJson({
      'streak_days': 0,
      'readiness_score': 0,
      'questions_answered': 0,
      'sessions_completed': 0,
      'overall_accuracy': 0,
      'recent_accuracy': <dynamic>[],
      'weak_areas': <dynamic>[],
    });

    expect(progress.questionsAnswered, 0);
    expect(progress.weakAreas, isEmpty);
    expect(progress.recentAccuracy, isEmpty);
  });

  group('supabaseGuard', () {
    // Every RPC refusal shares errcode P0001 and differs only by hint, so a
    // wrong mapping here would show the user the wrong screen entirely.
    Future<void> expectMapped(String hint, Matcher matcher) async {
      await expectLater(
        supabaseGuard<void>(
          () async => throw PostgrestException(
            message: 'refused',
            code: 'P0001',
            hint: hint,
          ),
        ),
        throwsA(matcher),
      );
    }

    test('upgrade_required', () async {
      await expectMapped('upgrade_required', isA<UpgradeRequiredException>());
    });

    test('empty_set', () async {
      await expectMapped('empty_set', isA<EmptyPracticeSetException>());
    });

    test('already_submitted', () async {
      await expectMapped('already_submitted', isA<AlreadySubmittedException>());
    });

    test('quota_exceeded is left to the caller, which knows the limit',
        () async {
      await expectMapped('quota_exceeded', isA<PostgrestException>());
    });

    test('a missing session stays a PostgrestException', () async {
      await expectLater(
        supabaseGuard<void>(
          () async =>
              throw const PostgrestException(message: 'gone', code: 'P0002'),
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('an expired token reads as unauthenticated', () async {
      await expectLater(
        supabaseGuard<void>(
          () async =>
              throw const PostgrestException(message: 'no', code: '42501'),
        ),
        throwsA(isA<UnauthenticatedException>()),
      );
    });
  });
}
