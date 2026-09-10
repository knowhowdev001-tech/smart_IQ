import 'package:flutter/foundation.dart';

import '../enums.dart';

/// Sentinel for an unlimited allowance. PRD 7.5 gives Pro+ unlimited
/// practice and mock exams; representing that as a sentinel rather than null
/// keeps every comparison in the UI uniform.
const int kUnlimited = -1;

/// The quota set applying to a tier, fetched at session start and cached
/// for the session (PRD 7.6).
///
/// These are configuration, not constants: every value lives in the
/// `tier_limits` table and is tunable per tier without an app release, so
/// nothing in the client may treat [defaults] as authoritative once the
/// server has answered.
@immutable
class TierLimits {
  const TierLimits({
    required this.tier,
    required this.questionsPerDay,
    required this.aiMessagesPerDay,
    required this.mockExamsPerMonth,
    required this.maxPracticeSetSize,
    required this.dailyChallenge,
    required this.adaptiveDifficulty,
    required this.studyPlan,
    required this.speedDrills,
    required this.chatRetentionDays,
    this.wrongAnswerBankFull = false,
    this.wrongAnswerBankLimited = false,
  });

  factory TierLimits.fromJson(Map<String, dynamic> json) => TierLimits(
        tier: Tier.fromKey(json['tier'] as String?),
        questionsPerDay: json['questions_per_day'] as int? ?? 0,
        aiMessagesPerDay: json['ai_messages_per_day'] as int? ?? 0,
        mockExamsPerMonth: json['mock_exams_per_month'] as int? ?? 0,
        maxPracticeSetSize: json['max_practice_set_size'] as int? ?? 0,
        dailyChallenge: json['daily_challenge'] as bool? ?? false,
        adaptiveDifficulty: json['adaptive_difficulty'] as bool? ?? false,
        studyPlan: json['study_plan'] as bool? ?? false,
        speedDrills: json['speed_drills'] as bool? ?? false,
        chatRetentionDays: json['chat_retention_days'] as int? ?? 1,
        wrongAnswerBankFull: json['wrong_answer_bank_full'] as bool? ?? false,
        wrongAnswerBankLimited:
            json['wrong_answer_bank_limited'] as bool? ?? false,
      );

  final Tier tier;
  final int questionsPerDay;
  final int aiMessagesPerDay;
  final int mockExamsPerMonth;
  final int maxPracticeSetSize;
  final bool dailyChallenge;
  final bool adaptiveDifficulty;
  final bool studyPlan;
  final bool speedDrills;
  final int chatRetentionDays;
  final bool wrongAnswerBankFull;
  final bool wrongAnswerBankLimited;

  bool get questionsUnlimited => questionsPerDay == kUnlimited;
  bool get mockExamsUnlimited => mockExamsPerMonth == kUnlimited;
  bool get chatRetentionUnlimited => chatRetentionDays == kUnlimited;

  bool allows(PracticeMode mode) => switch (mode) {
        PracticeMode.speed => speedDrills,
        PracticeMode.adaptive => adaptiveDifficulty,
        PracticeMode.dailyChallenge => dailyChallenge,
        PracticeMode.mockExam => mockExamsPerMonth != 0,
        PracticeMode.wrongAnswerDrill =>
          wrongAnswerBankFull || wrongAnswerBankLimited,
        _ => true,
      };

  /// The defaults from PRD 7.5, used only until real configuration arrives
  /// so a cold start with no cached limits still renders a coherent UI.
  static const defaults = <Tier, TierLimits>{
    Tier.free: TierLimits(
      tier: Tier.free,
      questionsPerDay: 2,
      aiMessagesPerDay: 2,
      mockExamsPerMonth: 0,
      maxPracticeSetSize: 2,
      dailyChallenge: false,
      adaptiveDifficulty: false,
      studyPlan: false,
      speedDrills: false,
      chatRetentionDays: 1,
    ),
    Tier.basic: TierLimits(
      tier: Tier.basic,
      questionsPerDay: 50,
      aiMessagesPerDay: 10,
      mockExamsPerMonth: 2,
      maxPracticeSetSize: 20,
      dailyChallenge: true,
      adaptiveDifficulty: false,
      studyPlan: false,
      speedDrills: false,
      chatRetentionDays: 7,
      wrongAnswerBankLimited: true,
    ),
    Tier.pro: TierLimits(
      tier: Tier.pro,
      questionsPerDay: 250,
      aiMessagesPerDay: 60,
      mockExamsPerMonth: 15,
      maxPracticeSetSize: 50,
      dailyChallenge: true,
      adaptiveDifficulty: true,
      studyPlan: true,
      speedDrills: true,
      chatRetentionDays: 90,
      wrongAnswerBankFull: true,
    ),
    Tier.proPlus: TierLimits(
      tier: Tier.proPlus,
      questionsPerDay: kUnlimited,
      aiMessagesPerDay: 200,
      mockExamsPerMonth: kUnlimited,
      maxPracticeSetSize: 100,
      dailyChallenge: true,
      adaptiveDifficulty: true,
      studyPlan: true,
      speedDrills: true,
      chatRetentionDays: kUnlimited,
      wrongAnswerBankFull: true,
    ),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TierLimits &&
          other.tier == tier &&
          other.questionsPerDay == questionsPerDay &&
          other.aiMessagesPerDay == aiMessagesPerDay &&
          other.mockExamsPerMonth == mockExamsPerMonth;

  @override
  int get hashCode =>
      Object.hash(tier, questionsPerDay, aiMessagesPerDay, mockExamsPerMonth);
}

/// Today's consumption against the tier's allowances.
///
/// The server is the authoritative enforcer (PRD 7.6). This exists so the
/// client can show remaining quota and gate the UI ahead of a refusal; it
/// never decides on its own that an action is permitted.
@immutable
class QuotaUsage {
  const QuotaUsage({
    this.questionsToday = 0,
    this.aiMessagesToday = 0,
    this.mockExamsThisMonth = 0,
    this.asOf,
  });

  factory QuotaUsage.fromJson(Map<String, dynamic> json) => QuotaUsage(
        questionsToday: json['questions_today'] as int? ?? 0,
        aiMessagesToday: json['ai_messages_today'] as int? ?? 0,
        mockExamsThisMonth: json['mock_exams_this_month'] as int? ?? 0,
        asOf: json['as_of'] == null
            ? null
            : DateTime.parse(json['as_of'] as String),
      );

  final int questionsToday;
  final int aiMessagesToday;
  final int mockExamsThisMonth;
  final DateTime? asOf;

  int questionsLeft(TierLimits limits) => limits.questionsUnlimited
      ? kUnlimited
      : (limits.questionsPerDay - questionsToday).clamp(0, 1 << 30);

  int aiMessagesLeft(TierLimits limits) =>
      (limits.aiMessagesPerDay - aiMessagesToday).clamp(0, 1 << 30);

  int mockExamsLeft(TierLimits limits) => limits.mockExamsUnlimited
      ? kUnlimited
      : (limits.mockExamsPerMonth - mockExamsThisMonth).clamp(0, 1 << 30);

  QuotaUsage copyWith({
    int? questionsToday,
    int? aiMessagesToday,
    int? mockExamsThisMonth,
    DateTime? asOf,
  }) =>
      QuotaUsage(
        questionsToday: questionsToday ?? this.questionsToday,
        aiMessagesToday: aiMessagesToday ?? this.aiMessagesToday,
        mockExamsThisMonth: mockExamsThisMonth ?? this.mockExamsThisMonth,
        asOf: asOf ?? this.asOf,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuotaUsage &&
          other.questionsToday == questionsToday &&
          other.aiMessagesToday == aiMessagesToday &&
          other.mockExamsThisMonth == mockExamsThisMonth;

  @override
  int get hashCode =>
      Object.hash(questionsToday, aiMessagesToday, mockExamsThisMonth);
}

/// The unified entitlement the app reads. Neither billing rail is consulted
/// directly (PRD 7.1) — telco daily and RevenueCat both write here, and the
/// client only ever reads the resolved tier.
@immutable
class Entitlement {
  const Entitlement({
    required this.tier,
    required this.limits,
    this.usage = const QuotaUsage(),
    this.source,
    this.validUntil,
    this.lastCheckedAt,
    this.fromCache = false,
  });

  factory Entitlement.fromJson(Map<String, dynamic> json) => Entitlement(
        tier: Tier.fromKey(json['tier'] as String?),
        limits: TierLimits.fromJson(json['limits'] as Map<String, dynamic>),
        usage: json['usage'] == null
            ? const QuotaUsage()
            : QuotaUsage.fromJson(json['usage'] as Map<String, dynamic>),
        source: json['source'] as String?,
        validUntil: json['valid_until'] == null
            ? null
            : DateTime.parse(json['valid_until'] as String),
        lastCheckedAt: json['last_checked_at'] == null
            ? null
            : DateTime.parse(json['last_checked_at'] as String),
      );

  final Tier tier;
  final TierLimits limits;
  final QuotaUsage usage;

  /// 'telco', 'revenuecat', or null on Free Fallback.
  final String? source;
  final DateTime? validUntil;
  final DateTime? lastCheckedAt;

  /// True when the status API could not be reached and this came from cache.
  /// PRD 7.3 keeps paying users on their tier for a short TTL rather than
  /// downgrading them on a flaky connection.
  final bool fromCache;

  /// The state a user lands in whenever charging fails or is absent.
  static const freeFallback = Entitlement(
    tier: Tier.free,
    limits: TierLimits(
      tier: Tier.free,
      questionsPerDay: 2,
      aiMessagesPerDay: 2,
      mockExamsPerMonth: 0,
      maxPracticeSetSize: 2,
      dailyChallenge: false,
      adaptiveDifficulty: false,
      studyPlan: false,
      speedDrills: false,
      chatRetentionDays: 1,
    ),
  );

  bool get isPaid => tier != Tier.free;

  /// How long a cached entitlement stays usable once the status API stops
  /// responding, per PRD 7.3.
  static const cacheTtl = Duration(hours: 6);

  /// PRD 7.3 debounce: a successful check inside this window is skipped.
  static const checkDebounce = Duration(hours: 1);

  bool get needsRefresh {
    final checked = lastCheckedAt;
    return checked == null ||
        DateTime.now().difference(checked) > checkDebounce;
  }

  bool get cacheExpired {
    final checked = lastCheckedAt;
    return checked == null || DateTime.now().difference(checked) > cacheTtl;
  }

  Entitlement copyWith({
    Tier? tier,
    TierLimits? limits,
    QuotaUsage? usage,
    String? source,
    DateTime? validUntil,
    DateTime? lastCheckedAt,
    bool? fromCache,
  }) =>
      Entitlement(
        tier: tier ?? this.tier,
        limits: limits ?? this.limits,
        usage: usage ?? this.usage,
        source: source ?? this.source,
        validUntil: validUntil ?? this.validUntil,
        lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
        fromCache: fromCache ?? this.fromCache,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Entitlement &&
          other.tier == tier &&
          other.limits == limits &&
          other.usage == usage &&
          other.fromCache == fromCache &&
          other.lastCheckedAt == lastCheckedAt;

  @override
  int get hashCode =>
      Object.hash(tier, limits, usage, fromCache, lastCheckedAt);
}
