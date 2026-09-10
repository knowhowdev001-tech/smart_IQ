import 'package:flutter/foundation.dart';

import '../enums.dart';

/// A string supplied by the content team in all three languages.
///
/// PRD 5.3 requires every stem, option and explanation in Sinhala, Tamil and
/// English, so this is the shape almost all content text takes. Values are
/// nullable per language because verbal-reasoning sub-topics are authored
/// per language rather than translated (PRD A.5).
@immutable
class LocalizedText {
  const LocalizedText({this.si, this.ta, this.en});

  /// Convenience for content that genuinely has one form, such as a numeric
  /// option like "24" or a proper noun.
  const LocalizedText.same(String value)
      : si = value,
        ta = value,
        en = value;

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
        si: json['si'] as String?,
        ta: json['ta'] as String?,
        en: json['en'] as String?,
      );

  final String? si;
  final String? ta;
  final String? en;

  Map<String, dynamic> toJson() => {'si': si, 'ta': ta, 'en': en};

  String? raw(AppLanguage language) => switch (language) {
        AppLanguage.sinhala => si,
        AppLanguage.tamil => ta,
        AppLanguage.english => en,
      };

  /// Whether this text exists in the requested language at all. The in-place
  /// language toggle (PRD 6.5) is disabled for questions where it does not.
  bool hasLanguage(AppLanguage language) {
    final value = raw(language);
    return value != null && value.trim().isNotEmpty;
  }

  /// Resolves to the requested language, falling back through English and
  /// then any populated value rather than rendering an empty string. A blank
  /// question stem is a worse failure than one shown in the wrong language.
  String resolve(AppLanguage language) {
    for (final candidate in [raw(language), en, si, ta]) {
      if (candidate != null && candidate.trim().isNotEmpty) return candidate;
    }
    return '';
  }

  /// Null-safe variant for genuinely optional text such as an image caption.
  String? resolveOrNull(AppLanguage language) {
    final value = resolve(language);
    return value.isEmpty ? null : value;
  }

  LocalizedText copyWith({String? si, String? ta, String? en}) =>
      LocalizedText(si: si ?? this.si, ta: ta ?? this.ta, en: en ?? this.en);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          other.si == si &&
          other.ta == ta &&
          other.en == en;

  @override
  int get hashCode => Object.hash(si, ta, en);

  @override
  String toString() => 'LocalizedText(en: $en, si: $si, ta: $ta)';
}
