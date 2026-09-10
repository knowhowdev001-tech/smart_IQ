import 'package:flutter/foundation.dart';

import '../enums.dart';
import 'localized_text.dart';

/// A media asset attached to a stem, option or explanation.
///
/// [path] is a Supabase Storage object path, never a full URL. PRD 8 keeps
/// URLs out of the database so the storage host can change without a data
/// migration; the client builds the URL at render time.
@immutable
class QuestionMedia {
  const QuestionMedia({
    required this.path,
    this.localizedPath = const LocalizedText(),
    this.alt = const LocalizedText(),
    this.caption = const LocalizedText(),
    this.sortOrder = 0,
  });

  factory QuestionMedia.fromJson(Map<String, dynamic> json) => QuestionMedia(
        path: json['path'] as String,
        localizedPath: json['localized_path'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(
                json['localized_path'] as Map<String, dynamic>),
        alt: json['alt'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['alt'] as Map<String, dynamic>),
        caption: json['caption'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['caption'] as Map<String, dynamic>),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String path;

  /// Per-language override used when the image contains embedded text.
  /// Empty means the shared, language-neutral asset applies (PRD 5.4.3).
  final LocalizedText localizedPath;

  /// Alternative text per language, required for screen readers by
  /// PRD 5.4.1.
  final LocalizedText alt;
  final LocalizedText caption;
  final int sortOrder;

  /// Resolves the storage path for a language, preferring a per-language
  /// variant when the content team supplied one.
  String pathFor(AppLanguage language) =>
      localizedPath.resolveOrNull(language) ?? path;

  /// Diagrams drawn in the client as vector art rather than fetched from
  /// Storage. Keeps line work crisp at every device scale.
  bool get isBuiltIn => path.startsWith('builtin:');

  String get builtInKey => path.substring('builtin:'.length);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionMedia &&
          other.path == path &&
          other.localizedPath == localizedPath &&
          other.alt == alt &&
          other.caption == caption &&
          other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(path, localizedPath, alt, caption, sortOrder);
}

/// One selectable answer. Text and media are both nullable because an option
/// may be image-only, but PRD 5.4.1 requires at least one to be present.
@immutable
class QuestionOption {
  const QuestionOption({
    required this.id,
    required this.optionKey,
    this.text = const LocalizedText(),
    this.media,
    this.sortOrder = 0,
  });

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        id: json['id'] as String,
        optionKey: json['option_key'] as String,
        text: json['text'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['text'] as Map<String, dynamic>),
        media: json['media'] == null
            ? null
            : QuestionMedia.fromJson(json['media'] as Map<String, dynamic>),
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  final String id;

  /// Stable label shown in the circular key: A, B, C, D.
  final String optionKey;
  final LocalizedText text;
  final QuestionMedia? media;
  final int sortOrder;

  bool get hasMedia => media != null;

  bool hasText(AppLanguage language) => text.hasLanguage(language);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuestionOption && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}

/// A multiple-choice question. Every question in v1 is multiple choice
/// (PRD 5.4), which is what keeps marking trivial and the practice engine
/// uniform across all sub-topics.
@immutable
class Question {
  const Question({
    required this.id,
    required this.subTopicId,
    required this.categoryKey,
    required this.difficulty,
    required this.options,
    required this.correctOptionId,
    this.categoryName = const LocalizedText(),
    this.subTopicName = const LocalizedText(),
    this.stem = const LocalizedText(),
    this.stemMedia,
    this.explanation = const LocalizedText(),
    this.explanationMedia = const <QuestionMedia>[],
    this.shuffleOptions = true,
    this.languageSpecific = false,
  });

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: json['id'] as String,
        subTopicId: json['sub_topic_id'] as String,
        categoryKey: json['category_key'] as String,
        difficulty: Difficulty.fromKey(json['difficulty'] as String?),
        options: [
          for (final o in (json['options'] as List? ?? const []))
            QuestionOption.fromJson(o as Map<String, dynamic>),
        ],
        correctOptionId: json['correct_option_id'] as String,
        categoryName: json['category_name'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(
                json['category_name'] as Map<String, dynamic>),
        subTopicName: json['sub_topic_name'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(
                json['sub_topic_name'] as Map<String, dynamic>),
        stem: json['stem'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['stem'] as Map<String, dynamic>),
        stemMedia: json['stem_media'] == null
            ? null
            : QuestionMedia.fromJson(
                json['stem_media'] as Map<String, dynamic>),
        explanation: json['explanation'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(
                json['explanation'] as Map<String, dynamic>),
        explanationMedia: [
          for (final m in (json['explanation_media'] as List? ?? const []))
            QuestionMedia.fromJson(m as Map<String, dynamic>),
        ],
        shuffleOptions: json['shuffle_options'] as bool? ?? true,
        languageSpecific: json['language_specific'] as bool? ?? false,
      );

  final String id;
  final String subTopicId;
  final String categoryKey;
  final Difficulty difficulty;
  final List<QuestionOption> options;

  /// Id of the single correct option. The answer lives on the question,
  /// never on a translation, so it cannot diverge between languages.
  final String correctOptionId;

  final LocalizedText categoryName;
  final LocalizedText subTopicName;
  final LocalizedText stem;
  final QuestionMedia? stemMedia;
  final LocalizedText explanation;
  final List<QuestionMedia> explanationMedia;

  /// Disabled for questions whose options are positional, such as
  /// "None of the above" (PRD 5.4.1).
  final bool shuffleOptions;

  /// Verbal-reasoning items are authored per language and must never be
  /// presented as the same question in another language (PRD A.6). The
  /// in-place language toggle is hidden when this is true.
  final bool languageSpecific;

  QuestionOption get correctOption =>
      options.firstWhere((o) => o.id == correctOptionId);

  bool isCorrect(String optionId) => optionId == correctOptionId;

  /// Whether this question can be shown in the given language at all.
  bool availableIn(AppLanguage language) =>
      !languageSpecific || stem.hasLanguage(language);

  /// True when the question cannot be answered without its artwork. PRD 6.3
  /// requires skipping such a question rather than serving it broken.
  bool get requiresMedia =>
      stemMedia != null || options.any((o) => o.hasMedia);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Question && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A top-level content category shown on the home grid.
@immutable
class Category {
  const Category({
    required this.id,
    required this.key,
    required this.name,
    this.meta = const LocalizedText(),
    this.sortOrder = 0,
    this.questionCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        key: json['key'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        meta: json['meta'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['meta'] as Map<String, dynamic>),
        sortOrder: json['sort_order'] as int? ?? 0,
        questionCount: json['question_count'] as int? ?? 0,
      );

  final String id;
  final String key;
  final LocalizedText name;
  final LocalizedText meta;
  final int sortOrder;
  final int questionCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Category && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A sub-topic within a category. The taxonomy is data-driven so Tier 2
/// sub-topics can be added post-launch without an app release (PRD A.6).
@immutable
class SubTopic {
  const SubTopic({
    required this.id,
    required this.categoryKey,
    required this.name,
    this.sortOrder = 0,
    this.requiresImage = false,
    this.languageSpecific = false,
    this.mastery,
    this.questionCount = 0,
  });

  factory SubTopic.fromJson(Map<String, dynamic> json) => SubTopic(
        id: json['id'] as String,
        categoryKey: json['category_key'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        sortOrder: json['sort_order'] as int? ?? 0,
        requiresImage: json['requires_image'] as bool? ?? false,
        languageSpecific: json['verbal_language_specific'] as bool? ?? false,
        mastery: json['mastery'] as int?,
        questionCount: json['question_count'] as int? ?? 0,
      );

  final String id;
  final String categoryKey;
  final LocalizedText name;
  final int sortOrder;

  /// Spatial and most data-interpretation sub-topics cannot render without
  /// an image (PRD A.6).
  final bool requiresImage;

  /// Verbal sub-topics authored per language rather than translated.
  final bool languageSpecific;

  /// The user's own accuracy, 0-100, or null when never attempted.
  final int? mastery;
  final int questionCount;

  bool get attempted => mastery != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SubTopic && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A published current-affairs digest.
@immutable
class CurrentAffairsItem {
  const CurrentAffairsItem({
    required this.id,
    required this.publishDate,
    required this.type,
    required this.title,
    this.body = const LocalizedText(),
    this.mediaPath,
  });

  factory CurrentAffairsItem.fromJson(Map<String, dynamic> json) =>
      CurrentAffairsItem(
        id: json['id'] as String,
        publishDate: DateTime.parse(json['publish_date'] as String),
        type: json['type'] as String,
        title: LocalizedText.fromJson(json['title'] as Map<String, dynamic>),
        body: json['body'] == null
            ? const LocalizedText()
            : LocalizedText.fromJson(json['body'] as Map<String, dynamic>),
        mediaPath: json['media_path'] as String?,
      );

  final String id;
  final DateTime publishDate;
  final String type;
  final LocalizedText title;
  final LocalizedText body;
  final String? mediaPath;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CurrentAffairsItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
