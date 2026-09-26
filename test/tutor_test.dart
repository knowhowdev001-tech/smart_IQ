import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/providers/app_providers.dart';
import 'package:smart_iq/core/settings/app_settings.dart';
import 'package:smart_iq/core/theme/app_scale.dart';
import 'package:smart_iq/core/theme/app_theme.dart';
import 'package:smart_iq/data/mock/mock_content.dart';
import 'package:smart_iq/data/repositories/repositories.dart';
import 'package:smart_iq/data/repositories/supabase_tutor_repository.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/chat.dart';
import 'package:smart_iq/features/tutor/explain_prompt.dart';
import 'package:smart_iq/features/tutor/presentation/tutor_screen.dart';
import 'package:smart_iq/l10n/generated/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The tutor over the ai-chat proxy (PRD 4.5, 6.4).
void main() {
  final ageQuestion =
      MockContent.questions.firstWhere((q) => q.id == 'q-age-1');
  final historyQuestion =
      MockContent.questions.firstWhere((q) => q.id == 'q-history-1');

  group('SupabaseTutorRepository', () {
    /// A client whose ai-chat answers with [status] and [body], and which
    /// keeps the last request body it was sent.
    (SupabaseTutorRepository, List<Map<String, dynamic>>) build(
      int status,
      Map<String, dynamic> body,
    ) {
      final sent = <Map<String, dynamic>>[];
      final http.Client fake = MockClient((request) async {
        if (!request.url.path.endsWith('/functions/v1/ai-chat')) {
          return http.Response('not found', 404, request: request);
        }
        sent.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final repository = SupabaseTutorRepository(
        client: SupabaseClient(
          'http://localhost:54321',
          'test-key',
          httpClient: fake,
        ),
      );
      return (repository, sent);
    }

    test('sends the thread, topic and language, and yields the answer',
        () async {
      final (repository, sent) = build(200, {
        'thread_id': 't',
        'message': {
          'id': 'm-1',
          'content': 'Answer: (B) 42',
          'created_at': '2026-09-26T08:00:00Z',
        },
        'used_search': false,
      });
      final thread = await repository.createThread();

      final replies = await repository
          .send(
            threadId: thread.id,
            content: 'What comes next?',
            language: AppLanguage.sinhala,
            topic: TutorTopic.gk,
          )
          .toList();

      expect(replies.single.content, 'Answer: (B) 42');
      expect(replies.single.role, ChatRole.assistant);
      expect(sent.single, {
        'thread_id': thread.id,
        'type': 'gk',
        'content': 'What comes next?',
        'language': 'si',
      });
    });

    test('a thread id is a v4 uuid, which the function insists on', () async {
      final (repository, _) = build(200, const {});
      final thread = await repository.createThread();

      expect(
        thread.id,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        )),
      );
    });

    test('a spent allowance is a quota refusal with its limit', () async {
      final (repository, _) = build(429, {
        'hint': 'quota_exceeded',
        'tier': 'free',
        'limit': 2,
      });

      await expectLater(
        repository
            .send(
              threadId: 't',
              content: 'hi',
              language: AppLanguage.english,
              topic: TutorTopic.iq,
            )
            .toList(),
        throwsA(
          isA<QuotaExceededException>()
              .having((e) => e.limit, 'limit', 2)
              .having((e) => e.tier, 'tier', Tier.free)
              .having((e) => e.resetsAt, 'resetsAt', isNotNull),
        ),
      );
    });

    test('an endpoint failure is an error, not a quota refusal', () async {
      final (repository, _) = build(502, {'hint': 'tutor_unavailable'});

      await expectLater(
        repository
            .send(
              threadId: 't',
              content: 'hi',
              language: AppLanguage.english,
              topic: TutorTopic.iq,
            )
            .toList(),
        throwsA(isNot(isA<QuotaExceededException>())),
      );
    });
  });

  group('explainPrompt', () {
    test('carries the options, the answer and the pick', () {
      final prompt = explainPrompt(
        ageQuestion,
        AppLanguage.english,
        selectedOptionId: 'opt-a',
      );

      expect(prompt, contains('Kamal is four times as old'));
      expect(prompt, contains('(A) 20'));
      expect(prompt, contains('(D) 32'));
      expect(prompt, contains('Correct answer: (B)'));
      expect(prompt, contains('I answered (A)'));
      expect(prompt, contains('Reference explanation:'));
    });

    test('is written in the student language', () {
      final prompt = explainPrompt(historyQuestion, AppLanguage.sinhala);

      expect(prompt, contains('උඩරට ගිවිසුම'));
      expect(prompt, isNot(contains('I answered')));
    });
  });

  group('TutorScreen', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget host(Widget child, _RecordingTutor tutor) {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ResponsiveScope(child: child),
          ),
        ],
      );
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          tutorRepositoryProvider.overrideWithValue(tutor),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          locale: AppLanguage.english.locale,
          supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
          localizationsDelegates: AppL10n.localizationsDelegates,
          routerConfig: router,
        ),
      );
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 900));
    }

    testWidgets('the GK chip sends a GK message', (tester) async {
      final tutor = _RecordingTutor();
      await tester.pumpWidget(host(const TutorScreen(), tutor));
      await settle(tester);

      await tester.tap(find.text('General knowledge'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Who is the president?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);

      expect(tutor.sent.single.topic, TutorTopic.gk);
      expect(find.text('A reply'), findsOneWidget);
    });

    testWidgets('Explain this sends the question as a GK thread',
        (tester) async {
      final tutor = _RecordingTutor();
      await tester.pumpWidget(
        host(TutorScreen(explain: TutorExplain(question: historyQuestion)),
            tutor),
      );
      await settle(tester);

      final sent = tutor.sent.single;
      expect(sent.topic, TutorTopic.gk);
      expect(sent.questionId, 'q-history-1');
      expect(sent.content, contains('Kandyan Convention'));
      // The bubble is the short ask, not the whole context.
      expect(find.textContaining('Explain this question'), findsOneWidget);
      expect(find.textContaining('Correct answer'), findsNothing);
    });
  });
}

typedef _Sent = ({String content, TutorTopic topic, String? questionId});

class _RecordingTutor implements TutorRepository {
  final sent = <_Sent>[];
  var _seq = 0;

  @override
  Future<List<ChatThread>> threads() async => const [];

  @override
  Future<ChatThread> createThread({
    String? sourceQuestionId,
    String? topic,
  }) async =>
      ChatThread(id: 'thread-${_seq++}', createdAt: DateTime.now());

  @override
  Stream<ChatMessage> send({
    required String threadId,
    required String content,
    required AppLanguage language,
    required TutorTopic topic,
    String? questionId,
  }) async* {
    sent.add((content: content, topic: topic, questionId: questionId));
    yield ChatMessage(
      id: 'reply-${sent.length}',
      role: ChatRole.assistant,
      content: 'A reply',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteThread(String threadId) async {}
}
