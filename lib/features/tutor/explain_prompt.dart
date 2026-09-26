import '../../domain/enums.dart';
import '../../domain/models/content.dart';

/// The first message of an "Explain this" thread (PRD 6.4).
///
/// The endpoint sees only text, so the question travels as text: the stem,
/// the lettered options, the right answer, what the student picked and the
/// stored explanation, which is the context PRD 5.4.2 says it exists to give.
/// Content is in the student's language; the labels stay English because the
/// endpoint is told the reply language separately and reads them either way.
/// An image-only stem or option is passed by its alt text.
String explainPrompt(
  Question question,
  AppLanguage language, {
  String? selectedOptionId,
}) {
  String keyOf(String id) => question.options
      .firstWhere((o) => o.id == id, orElse: () => question.options.first)
      .optionKey;

  final stem =
      question.stem.resolveOrNull(language) ??
      question.stemMedia?.alt.resolveOrNull(language) ??
      '[image]';

  final buffer = StringBuffer()
    ..writeln('Explain this question to me step by step.')
    ..writeln()
    ..writeln('Question: $stem');

  for (final option in question.options) {
    final text =
        option.text.resolveOrNull(language) ??
        option.media?.alt.resolveOrNull(language) ??
        '[image]';
    buffer.writeln('(${option.optionKey}) $text');
  }

  buffer
    ..writeln()
    ..writeln('Correct answer: (${keyOf(question.correctOptionId)})');

  if (selectedOptionId != null) {
    final picked = keyOf(selectedOptionId);
    buffer.writeln(
      selectedOptionId == question.correctOptionId
          ? 'I answered ($picked), which is correct.'
          : 'I answered ($picked). Explain why that is wrong.',
    );
  }

  final explanation = question.explanation.resolveOrNull(language);
  if (explanation != null) {
    buffer
      ..writeln()
      ..writeln('Reference explanation: $explanation');
  }

  return buffer.toString().trim();
}
