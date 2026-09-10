import 'package:flutter/material.dart';

/// The three content and interface languages. PRD 6.5 treats Sinhala and
/// Tamil as primary, not as translations layered onto an English product.
enum AppLanguage {
  sinhala('si'),
  tamil('ta'),
  english('en');

  const AppLanguage(this.code);

  final String code;

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) => switch (code) {
        'si' => AppLanguage.sinhala,
        'ta' => AppLanguage.tamil,
        _ => AppLanguage.english,
      };

  /// Pre-selects from the device locale where it maps cleanly (PRD 6.2).
  /// Anything else falls to English rather than guessing.
  static AppLanguage fromDeviceLocale(Locale locale) =>
      fromCode(locale.languageCode);
}

enum ThemePreference {
  light,
  dark,
  system;

  ThemeMode get mode => switch (this) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.system => ThemeMode.system,
      };

  static ThemePreference fromName(String? name) => ThemePreference.values
      .firstWhere((t) => t.name == name, orElse: () => ThemePreference.system);
}

/// Entitlement tiers. The client only ever reads this from the entitlement
/// layer; it is never derived from a billing rail directly (PRD 7.1).
enum Tier {
  free,
  basic,
  pro,
  proPlus;

  static Tier fromKey(String? key) => switch (key) {
        'basic' => Tier.basic,
        'pro' => Tier.pro,
        'proplus' || 'pro_plus' => Tier.proPlus,
        _ => Tier.free,
      };

  /// Rank used for feature gating comparisons.
  int get rank => index;

  bool atLeast(Tier other) => rank >= other.rank;
}

enum Difficulty {
  easy,
  medium,
  hard;

  static Difficulty fromKey(String? key) => switch (key) {
        'hard' => Difficulty.hard,
        'medium' => Difficulty.medium,
        _ => Difficulty.easy,
      };
}

/// How a practice set was assembled. Drives timer behaviour, scoring and
/// which quota the set is charged against.
enum PracticeMode {
  quick,
  timed,
  speed,
  adaptive,
  dailyChallenge,
  mockExam,
  wrongAnswerDrill;

  /// Modes that run under a visible countdown.
  bool get isTimed => switch (this) {
        PracticeMode.timed ||
        PracticeMode.speed ||
        PracticeMode.mockExam =>
          true,
        _ => false,
      };

  /// Seconds allowed per question, or null when untimed.
  int? get secondsPerQuestion => switch (this) {
        PracticeMode.timed => 60,
        PracticeMode.speed => 20,
        PracticeMode.mockExam => 72,
        _ => null,
      };

  /// PRD 7.5 gates adaptive difficulty and speed drills to Pro and above.
  Tier get minimumTier => switch (this) {
        PracticeMode.speed || PracticeMode.adaptive => Tier.pro,
        PracticeMode.mockExam => Tier.basic,
        PracticeMode.dailyChallenge => Tier.basic,
        _ => Tier.free,
      };
}

/// Whether an answer was right, wrong, or never given.
enum AnswerOutcome { correct, incorrect, skipped }

enum NotificationKind {
  dailyChallenge,
  streak,
  digest,
  chargeFailed,
  renewal,
  inactivity;

  static NotificationKind fromKey(String? key) => switch (key) {
        'streak' => NotificationKind.streak,
        'digest' => NotificationKind.digest,
        'charge' || 'charge_failed' => NotificationKind.chargeFailed,
        'renewal' => NotificationKind.renewal,
        'inactivity' => NotificationKind.inactivity,
        _ => NotificationKind.dailyChallenge,
      };
}

enum ChatRole { user, assistant }
