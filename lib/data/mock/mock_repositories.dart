import 'dart:async';
import 'dart:math';

import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/content.dart';
import '../../domain/models/entitlement.dart';
import '../../domain/models/practice.dart';
import '../../domain/models/user_profile.dart';
import '../repositories/repositories.dart';
import 'mock_content.dart';

/// In-memory stand-ins for the Supabase repositories.
///
/// These exist so the client can be built and reviewed end to end before the
/// backend lands. They deliberately reproduce the server's *behaviour* where
/// it constrains the UI — quota is consumed when a set is issued and refused
/// when exhausted, scoring happens outside the widget layer — so swapping in
/// the real implementations changes no screen code.
///
/// What they do not reproduce is the server's *authority*: the real quota
/// check lives in one database transaction (PRD 9.3), and nothing here should
/// be read as the client being trusted to enforce a limit.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository(this._state);

  final MockBackendState _state;

  static const _latency = Duration(milliseconds: 550);

  @override
  Future<int> requestOtp(String msisdn) async {
    await Future<void>.delayed(_latency);
    _state.pendingMsisdn = msisdn;
    _state.otpIssuedAt = DateTime.now();
    return 60;
  }

  @override
  Future<UserProfile?> verifyOtp({
    required String msisdn,
    required String code,
  }) async {
    await Future<void>.delayed(_latency);

    final issued = _state.otpIssuedAt;
    if (issued == null ||
        DateTime.now().difference(issued) > const Duration(minutes: 5)) {
      throw const OtpExpiredException();
    }
    // Any six digits verify in the mock. The real check is server-side
    // against a hashed, single-use OTP row (PRD 6.1).
    if (code.length != 6 || int.tryParse(code) == null) {
      throw const OtpInvalidException();
    }

    _state.signedIn = true;
    _state.profile = _state.profile?.copyWith(msisdn: msisdn);
    return _state.profile;
  }

  @override
  Future<UserProfile> createProfile({
    required String fullName,
    required AppLanguage language,
    String? district,
    DateTime? targetExamDate,
  }) async {
    await Future<void>.delayed(_latency);
    final profile = UserProfile(
      userId: 'user-mock-1',
      fullName: fullName,
      language: language,
      msisdn: _state.pendingMsisdn ?? '0771234821',
      district: district,
      targetExamDate: targetExamDate ??
          DateTime.now().add(const Duration(days: 86)),
      createdAt: DateTime.now(),
    );
    _state.profile = profile;
    _state.signedIn = true;
    return profile;
  }

  @override
  Future<UserProfile?> currentProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _state.signedIn ? _state.profile : null;
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _state.profile = profile;
    return profile;
  }

  @override
  Future<List<DeviceSession>> activeSessions() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return [
      DeviceSession(
        id: 's1',
        deviceName: 'This device',
        lastSeenAt: DateTime.now(),
        isCurrent: true,
      ),
      DeviceSession(
        id: 's2',
        deviceName: 'Redmi Note 12',
        lastSeenAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
    ];
  }

  @override
  Future<void> revokeSession(String sessionId) async =>
      Future<void>.delayed(const Duration(milliseconds: 220));

  @override
  Future<void> signOut() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    _state.signedIn = false;
  }

  @override
  Future<void> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _state
      ..signedIn = false
      ..profile = null;
  }
}

class OtpInvalidException implements Exception {
  const OtpInvalidException();
}

class OtpExpiredException implements Exception {
  const OtpExpiredException();
}

class MockContentRepository implements ContentRepository {
  @override
  Future<List<Category>> categories() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return MockContent.categories;
  }

  @override
  Future<List<SubTopic>> subTopics(String categoryKey) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return MockContent.subTopics[categoryKey] ?? const [];
  }

  @override
  Future<List<CurrentAffairsItem>> currentAffairs() async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return const [];
  }

  @override
  String mediaUrl(String path) => path;
}

class MockPracticeRepository implements PracticeRepository {
  MockPracticeRepository(this._state);

  final MockBackendState _state;
  final _random = Random();

  @override
  Future<PracticeSet> practiceSet({
    required PracticeMode mode,
    String? subTopicId,
    String? categoryKey,
    int? size,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return _issue(
      mode: mode,
      subTopicId: subTopicId,
      categoryKey: categoryKey,
      size: size ?? 10,
    );
  }

  @override
  Future<PracticeSet> dailyChallenge() =>
      practiceSet(mode: PracticeMode.dailyChallenge, size: 10);

  @override
  Future<PracticeSet> mockExam({required int length}) async {
    await Future<void>.delayed(const Duration(milliseconds: 520));
    final limits = _state.entitlement.limits;
    if (_state.usage.mockExamsLeft(limits) == 0) {
      throw QuotaExceededException(
        tier: _state.entitlement.tier,
        limit: limits.mockExamsPerMonth,
      );
    }
    _state.usage = _state.usage.copyWith(
      mockExamsThisMonth: _state.usage.mockExamsThisMonth + 1,
    );
    return _issue(mode: PracticeMode.mockExam, size: length);
  }

  @override
  Future<PracticeSet> wrongAnswerDrill() =>
      practiceSet(mode: PracticeMode.wrongAnswerDrill, size: 5);

  /// Mirrors the server's atomic check-and-increment: the allowance is spent
  /// as the set is issued, not as questions are answered.
  PracticeSet _issue({
    required PracticeMode mode,
    required int size,
    String? subTopicId,
    String? categoryKey,
  }) {
    final limits = _state.entitlement.limits;
    final remaining = _state.usage.questionsLeft(limits);

    if (remaining != kUnlimited && remaining <= 0) {
      throw QuotaExceededException(
        tier: _state.entitlement.tier,
        limit: limits.questionsPerDay,
        resetsAt: _nextSltMidnight(),
      );
    }

    // The set is capped by both the tier's max set size and what is left of
    // today's allowance, which is what produces the two-question Free
    // Fallback experience described in PRD 7.7.
    var length = min(size, limits.maxPracticeSetSize);
    if (remaining != kUnlimited) length = min(length, remaining);

    final pool = [
      for (final q in MockContent.questions)
        if (subTopicId == null || q.subTopicId == subTopicId)
          if (categoryKey == null ||
              categoryKey == 'mock' ||
              q.categoryKey == categoryKey)
            q,
    ];
    final source = pool.isEmpty ? MockContent.questions : pool;

    final questions = <Question>[
      for (var i = 0; i < length; i++) source[i % source.length],
    ];

    _state.usage = _state.usage.copyWith(
      questionsToday: _state.usage.questionsToday + questions.length,
    );

    final sessionId = 'sess-${_random.nextInt(1 << 32)}';
    return PracticeSet(
      sessionId: sessionId,
      mode: mode,
      questions: questions,
      subTopicId: subTopicId,
      categoryKey: categoryKey,
      startedAt: DateTime.now(),
      totalSeconds:
          mode == PracticeMode.mockExam ? questions.length * 72 : null,
      negativeMarkPerWrong: mode == PracticeMode.mockExam ? 0.25 : 0,
    );
  }

  @override
  Future<SessionResult> submitSession({
    required String sessionId,
    required List<SessionAnswer> answers,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 480));

    final correct = answers.where((a) => a.isCorrect).length;
    final incorrect = answers
        .where((a) => a.outcome == AnswerOutcome.incorrect)
        .length;
    final skipped =
        answers.where((a) => a.outcome == AnswerOutcome.skipped).length;
    final totalMs =
        answers.fold<int>(0, (sum, a) => sum + a.timeTakenMs);

    final bySubTopic = <String, List<SessionAnswer>>{};
    for (final answer in answers) {
      final question = MockContent.questions
          .firstWhere((q) => q.id == answer.questionId,
              orElse: () => MockContent.questions.first);
      bySubTopic.putIfAbsent(question.subTopicId, () => []).add(answer);
    }

    final breakdown = <SubTopicScore>[
      for (final entry in bySubTopic.entries)
        SubTopicScore(
          subTopicId: entry.key,
          name: MockContent.questions
              .firstWhere((q) => q.subTopicId == entry.key)
              .subTopicName
              .resolve(_state.profile?.language ?? AppLanguage.english),
          correct: entry.value.where((a) => a.isCorrect).length,
          total: entry.value.length,
        ),
    ];

    final scorePct = answers.isEmpty
        ? 0
        : ((correct / answers.length) * 100).round();
    _state.recentAccuracy = [
      ..._state.recentAccuracy.skip(max(0, _state.recentAccuracy.length - 4)),
      scorePct,
    ];

    return SessionResult(
      sessionId: sessionId,
      mode: PracticeMode.quick,
      correct: correct,
      incorrect: incorrect,
      skipped: skipped,
      totalTime: Duration(milliseconds: totalMs),
      breakdown: breakdown,
      ownHistory: _state.recentAccuracy,
      wrongQuestionIds: [
        for (final a in answers)
          if (a.outcome == AnswerOutcome.incorrect) a.questionId,
      ],
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<PracticeSet?> resumableSession() async => null;

  @override
  Future<void> discardResumableSession() async {}

  @override
  Future<ProgressSummary> progress() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockContent.progress().copyWith(
      recentAccuracy: _state.recentAccuracy,
    );
  }

  @override
  Future<List<SavedQuestion>> bookmarks() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final language = _state.profile?.language ?? AppLanguage.english;
    return [
      for (final id in _state.bookmarkedIds)
        _saved(id, language),
    ];
  }

  @override
  Future<void> setBookmark({
    required String questionId,
    required bool saved,
  }) async {
    if (saved) {
      _state.bookmarkedIds.add(questionId);
    } else {
      _state.bookmarkedIds.remove(questionId);
    }
  }

  @override
  Future<List<SavedQuestion>> wrongAnswerBank() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    final language = _state.profile?.language ?? AppLanguage.english;
    return [
      for (final q in MockContent.questions.take(3))
        _saved(q.id, language).copyWith(
          nextReviewAt: DateTime.now().add(const Duration(days: 1)),
          reviewCount: 1,
        ),
    ];
  }

  SavedQuestion _saved(String questionId, AppLanguage language) {
    final question = MockContent.questions.firstWhere(
      (q) => q.id == questionId,
      orElse: () => MockContent.questions.first,
    );
    final stem = question.stem.resolve(language);
    return SavedQuestion(
      questionId: question.id,
      subTopicName: question.subTopicName.resolve(language),
      stemPreview: stem.length > 90 ? '${stem.substring(0, 90)}…' : stem,
      savedAt: DateTime.now(),
    );
  }
}

class MockTutorRepository implements TutorRepository {
  MockTutorRepository(this._state);

  final MockBackendState _state;
  var _threadSeq = 0;

  @override
  Future<List<ChatThread>> threads() async {
    await Future<void>.delayed(const Duration(milliseconds: 220));
    return _state.threads;
  }

  @override
  Future<ChatThread> createThread({
    String? sourceQuestionId,
    String? topic,
  }) async {
    final thread = ChatThread(
      id: 'thread-${_threadSeq++}',
      createdAt: DateTime.now(),
      topic: topic,
      sourceQuestionId: sourceQuestionId,
    );
    _state.threads.insert(0, thread);
    return thread;
  }

  @override
  Stream<ChatMessage> send({
    required String threadId,
    required String content,
    required AppLanguage language,
  }) async* {
    // The proxy decrements the counter before forwarding and returns a
    // structured refusal when the allowance is gone (PRD 4.5).
    final limits = _state.entitlement.limits;
    if (_state.usage.aiMessagesLeft(limits) <= 0) {
      throw QuotaExceededException(
        tier: _state.entitlement.tier,
        limit: limits.aiMessagesPerDay,
        resetsAt: _nextSltMidnight(),
      );
    }
    _state.usage = _state.usage.copyWith(
      aiMessagesToday: _state.usage.aiMessagesToday + 1,
    );

    await Future<void>.delayed(const Duration(milliseconds: 700));

    final reply = _cannedReply(language);
    final id = 'msg-${DateTime.now().microsecondsSinceEpoch}';

    // Streamed word by word, so the UI's streaming path is the one actually
    // exercised in development rather than only the single-shot path.
    final buffer = StringBuffer();
    final words = reply.split(' ');
    for (var i = 0; i < words.length; i++) {
      buffer.write(i == 0 ? words[i] : ' ${words[i]}');
      await Future<void>.delayed(const Duration(milliseconds: 28));
      yield ChatMessage(
        id: id,
        role: ChatRole.assistant,
        content: buffer.toString(),
        createdAt: DateTime.now(),
        language: language,
        streaming: i < words.length - 1,
      );
    }
  }

  @override
  Future<ChatThread> explainQuestion({
    required Question question,
    required AppLanguage language,
    String? selectedOptionId,
  }) async {
    final thread = await createThread(
      sourceQuestionId: question.id,
      topic: question.subTopicName.resolve(language),
    );
    return thread;
  }

  @override
  Future<void> deleteThread(String threadId) async {
    _state.threads.removeWhere((t) => t.id == threadId);
  }

  String _cannedReply(AppLanguage language) => switch (language) {
        AppLanguage.sinhala =>
          'මෙම ගැටලුව විසඳීමට පියවර තුනක් අනුගමනය කරන්න. පළමුව දී ඇති තොරතුරු '
              'සමීකරණයක් ලෙස ලියන්න. දෙවනුව නොදන්නා අගය එක් පසෙකට ගන්න. '
              'තෙවනුව ඔබේ පිළිතුර මුල් ප්‍රකාශයට ආදේශ කර පරීක්ෂා කරන්න.',
        AppLanguage.tamil =>
          'இந்தக் கணக்கை மூன்று படிகளில் தீர்க்கலாம். முதலில் கொடுக்கப்பட்ட '
              'தகவலைச் சமன்பாடாக எழுதுங்கள். இரண்டாவதாக தெரியாத மதிப்பை ஒரு '
              'பக்கமாகப் பிரியுங்கள். மூன்றாவதாக உங்கள் விடையை மூலக் '
              'கூற்றில் பொருத்திச் சரிபாருங்கள்.',
        AppLanguage.english =>
          'Work through it in three steps. First, write the given information '
              'as an equation. Second, collect the unknown on one side. '
              'Third, substitute your answer back into the original statement '
              'to check it holds.',
      };
}

class MockEntitlementRepository implements EntitlementRepository {
  MockEntitlementRepository(this._state);

  final MockBackendState _state;

  @override
  Future<Entitlement> resolve({bool force = false}) async {
    final current = _state.entitlement;
    if (!force && !current.needsRefresh) return current;

    await Future<void>.delayed(const Duration(milliseconds: 700));
    final resolved = current.copyWith(
      usage: _state.usage,
      lastCheckedAt: DateTime.now(),
      fromCache: false,
    );
    _state.entitlement = resolved;
    return resolved;
  }

  @override
  Future<Entitlement?> cached() async =>
      _state.entitlement.copyWith(usage: _state.usage, fromCache: true);

  @override
  Future<QuotaUsage> usage() async => _state.usage;

  @override
  Future<void> startSubscription(Tier tier) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _state.entitlement = _state.entitlement.copyWith(
      tier: tier,
      limits: TierLimits.defaults[tier]!,
      source: tier == Tier.basic ? 'telco' : 'revenuecat',
      lastCheckedAt: DateTime.now(),
      validUntil: DateTime.now().add(
        tier == Tier.basic ? const Duration(days: 1) : const Duration(days: 30),
      ),
    );
  }
}

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(this._state);

  final MockBackendState _state;

  @override
  Future<List<AppNotification>> inbox() async {
    await Future<void>.delayed(const Duration(milliseconds: 260));
    return _state.notifications;
  }

  @override
  Future<void> markAllRead() async {
    _state.notifications = [
      for (final n in _state.notifications) n.copyWith(unread: false),
    ];
  }

  @override
  Future<void> markRead(String id) async {
    _state.notifications = [
      for (final n in _state.notifications)
        if (n.id == id) n.copyWith(unread: false) else n,
    ];
  }

  @override
  Future<NotificationPreferences> preferences() async => _state.notifyPrefs;

  @override
  Future<void> savePreferences(NotificationPreferences prefs) async {
    _state.notifyPrefs = prefs;
  }
}

/// Shared mutable state behind the mock repositories, so a quota spent in
/// one screen is visible in every other.
class MockBackendState {
  MockBackendState({Tier tier = Tier.basic})
      : entitlement = Entitlement(
          tier: tier,
          limits: TierLimits.defaults[tier]!,
          source: tier == Tier.basic ? 'telco' : null,
          lastCheckedAt: null,
        );

  bool signedIn = false;
  String? pendingMsisdn;
  DateTime? otpIssuedAt;

  UserProfile? profile = UserProfile(
    userId: 'user-mock-1',
    fullName: 'Nimal Perera',
    language: AppLanguage.english,
    msisdn: '0771234821',
    district: 'Colombo',
    targetExamDate: DateTime.now().add(const Duration(days: 86)),
    createdAt: DateTime.now().subtract(const Duration(days: 40)),
  );

  Entitlement entitlement;
  QuotaUsage usage = QuotaUsage(questionsToday: 12, aiMessagesToday: 3,
      asOf: DateTime.now());

  List<int> recentAccuracy = const [58, 64, 61, 73, 70];
  final Set<String> bookmarkedIds = {};
  final List<ChatThread> threads = [];
  List<AppNotification> notifications = MockContent.notifications();
  NotificationPreferences notifyPrefs = const NotificationPreferences();
}

/// Quota counters reset on the Sri Lanka day boundary, UTC+5:30 (PRD 7.6).
DateTime _nextSltMidnight() {
  const slt = Duration(hours: 5, minutes: 30);
  final nowSlt = DateTime.now().toUtc().add(slt);
  final nextSlt = DateTime.utc(nowSlt.year, nowSlt.month, nowSlt.day)
      .add(const Duration(days: 1));
  return nextSlt.subtract(slt).toLocal();
}
