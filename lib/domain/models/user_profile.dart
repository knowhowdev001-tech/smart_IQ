import 'package:flutter/foundation.dart';

import '../enums.dart';

/// The user's profile. PRD 6.2 keeps this deliberately short: only name and
/// language block progress, because this screen sits between OTP and the
/// user ever seeing a question, and every extra field is a drop-off risk.
@immutable
class UserProfile {
  const UserProfile({
    required this.userId,
    required this.fullName,
    required this.language,
    required this.msisdn,
    this.theme = ThemePreference.system,
    this.district,
    this.targetExamDate,
    this.currentStatus,
    this.educationLevel,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String? ?? '',
        language: AppLanguage.fromCode(json['language_preference'] as String?),
        msisdn: json['msisdn'] as String? ?? '',
        theme: ThemePreference.fromName(json['theme_preference'] as String?),
        district: json['district'] as String?,
        targetExamDate: json['target_exam_date'] == null
            ? null
            : DateTime.parse(json['target_exam_date'] as String),
        currentStatus: json['current_status'] as String?,
        educationLevel: json['education_level'] as String?,
        createdAt: json['created_at'] == null
            ? null
            : DateTime.parse(json['created_at'] as String),
      );

  final String userId;
  final String fullName;
  final AppLanguage language;

  /// The verified MSISDN. This is the account identity and the same number
  /// used for telco charging (PRD 6.1).
  final String msisdn;
  final ThemePreference theme;

  // Optional, skippable. Used for content recommendation and internal
  // analytics only; there are no user-to-user surfaces, so none of this is
  // ever shown to anyone else (PRD 6.2).
  final String? district;
  final DateTime? targetExamDate;
  final String? currentStatus;
  final String? educationLevel;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'language_preference': language.code,
        'msisdn': msisdn,
        'theme_preference': theme.name,
        'district': district,
        'target_exam_date': targetExamDate?.toIso8601String(),
        'current_status': currentStatus,
        'education_level': educationLevel,
      };

  /// Days until the target exam, or null when no date is set. Drives the
  /// home countdown and study-plan pacing (PRD 6.6).
  int? get daysToExam {
    final target = targetExamDate;
    if (target == null) return null;
    final now = DateTime.now();
    final days = DateTime(target.year, target.month, target.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return days < 0 ? 0 : days;
  }

  /// First name only, for the home greeting. Falls back to the whole string
  /// when there is no space, which is common for mononyms.
  String get displayName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    final space = trimmed.indexOf(' ');
    return space == -1 ? trimmed : trimmed.substring(0, space);
  }

  /// Masks the middle of the number for display.
  String get maskedMsisdn {
    final digits = msisdn.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) return msisdn;
    return '${digits.substring(0, 3)} ••• ${digits.substring(digits.length - 4)}';
  }

  UserProfile copyWith({
    String? userId,
    String? fullName,
    AppLanguage? language,
    String? msisdn,
    ThemePreference? theme,
    String? district,
    DateTime? targetExamDate,
    String? currentStatus,
    String? educationLevel,
    DateTime? createdAt,
  }) =>
      UserProfile(
        userId: userId ?? this.userId,
        fullName: fullName ?? this.fullName,
        language: language ?? this.language,
        msisdn: msisdn ?? this.msisdn,
        theme: theme ?? this.theme,
        district: district ?? this.district,
        targetExamDate: targetExamDate ?? this.targetExamDate,
        currentStatus: currentStatus ?? this.currentStatus,
        educationLevel: educationLevel ?? this.educationLevel,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          other.userId == userId &&
          other.fullName == fullName &&
          other.language == language &&
          other.msisdn == msisdn &&
          other.theme == theme &&
          other.district == district &&
          other.targetExamDate == targetExamDate;

  @override
  int get hashCode => Object.hash(
      userId, fullName, language, msisdn, theme, district, targetExamDate);
}

/// An underperforming sub-topic surfaced for a targeted drill (PRD 6.6).
@immutable
class WeakArea {
  const WeakArea({
    required this.subTopicId,
    required this.name,
    required this.accuracy,
    this.sampleSize = 0,
  });

  factory WeakArea.fromJson(Map<String, dynamic> json) => WeakArea(
        subTopicId: json['sub_topic_id'] as String,
        name: json['name'] as String,
        accuracy: json['accuracy'] as int? ?? 0,
        sampleSize: json['sample_size'] as int? ?? 0,
      );

  final String subTopicId;
  final String name;
  final int accuracy;
  final int sampleSize;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeakArea &&
          other.subTopicId == subTopicId &&
          other.accuracy == accuracy;

  @override
  int get hashCode => Object.hash(subTopicId, accuracy);
}

/// The user's own progress. All of it is self-referential — PRD 6.6 forbids
/// any comparison against another user anywhere in the product.
@immutable
class ProgressSummary {
  const ProgressSummary({
    this.streakDays = 0,
    this.readinessScore = 0,
    this.questionsAnswered = 0,
    this.sessionsCompleted = 0,
    this.overallAccuracy = 0,
    this.weakAreas = const <WeakArea>[],
    this.recentAccuracy = const <int>[],
  });

  final int streakDays;
  final int readinessScore;
  final int questionsAnswered;
  final int sessionsCompleted;
  final double overallAccuracy;
  final List<WeakArea> weakAreas;

  /// Accuracy of the last few sessions, oldest first, for the trend bars.
  final List<int> recentAccuracy;

  ProgressSummary copyWith({
    int? streakDays,
    int? readinessScore,
    int? questionsAnswered,
    int? sessionsCompleted,
    double? overallAccuracy,
    List<WeakArea>? weakAreas,
    List<int>? recentAccuracy,
  }) =>
      ProgressSummary(
        streakDays: streakDays ?? this.streakDays,
        readinessScore: readinessScore ?? this.readinessScore,
        questionsAnswered: questionsAnswered ?? this.questionsAnswered,
        sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
        overallAccuracy: overallAccuracy ?? this.overallAccuracy,
        weakAreas: weakAreas ?? this.weakAreas,
        recentAccuracy: recentAccuracy ?? this.recentAccuracy,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressSummary &&
          other.streakDays == streakDays &&
          other.readinessScore == readinessScore &&
          other.questionsAnswered == questionsAnswered &&
          listEquals(other.recentAccuracy, recentAccuracy) &&
          listEquals(other.weakAreas, weakAreas);

  @override
  int get hashCode => Object.hash(streakDays, readinessScore,
      questionsAnswered, Object.hashAll(recentAccuracy));
}

/// A signed-in device. PRD 6.1 lets the user see active sessions and sign
/// out the others, which refresh-token rotation makes enforceable.
@immutable
class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.lastSeenAt,
    this.isCurrent = false,
  });

  factory DeviceSession.fromJson(Map<String, dynamic> json) => DeviceSession(
        id: json['id'] as String,
        deviceName: json['device_name'] as String? ?? 'Unknown device',
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
        isCurrent: json['is_current'] as bool? ?? false,
      );

  final String id;
  final String deviceName;
  final DateTime lastSeenAt;
  final bool isCurrent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DeviceSession && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
