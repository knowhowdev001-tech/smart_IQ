import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/siq_surfaces.dart';
import '../../../../domain/enums.dart';
import '../../../../domain/models/content.dart';
import 'question_diagram.dart';

/// The pieces of a question that the running quiz and the saved-question
/// review both draw, so a question looks the same wherever it is read.

/// One answer option.
///
/// Before the answer is checked the tile only shows selection. Afterwards it
/// marks the correct option and, if the user was wrong, their choice — so
/// the explanation below has something to refer to.
class OptionTile extends StatelessWidget {
  const OptionTile({
    required this.option,
    required this.isCorrect,
    required this.selected,
    required this.revealed,
    this.onTap,
    super.key,
  });

  final QuestionOption option;
  final bool isCorrect;
  final bool selected;
  final bool revealed;

  /// Ignored once [revealed]: an answered question cannot be re-answered.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.language;

    final (background, borderColor, keyBackground, keyInk) = switch ((
      revealed,
      isCorrect,
      selected,
    )) {
      (true, true, _) => (
          colors.accentSoft,
          colors.accent,
          colors.accent,
          colors.accentInk,
        ),
      (true, false, true) => (
          colors.dangerSurface,
          colors.dangerBorder,
          colors.danger,
          Colors.white,
        ),
      (false, _, true) => (
          colors.accentSoft,
          colors.accent,
          colors.accent,
          colors.accentInk,
        ),
      _ => (colors.surface, colors.border, colors.surfaceMuted, colors.inkMuted),
    };

    final mark = switch ((revealed, isCorrect, selected)) {
      (true, true, _) => Icons.check_rounded,
      (true, false, true) => Icons.close_rounded,
      _ => null,
    };

    return Semantics(
      button: !revealed,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SiqCard(
        onTap: revealed ? null : onTap,
        background: background,
        borderColor: borderColor,
        radius: AppRadii.md,
        padding: EdgeInsets.symmetric(
          horizontal: 14.dp(context),
          vertical: 13.dp(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 24.dp(context),
              height: 24.dp(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: keyBackground,
                shape: BoxShape.circle,
              ),
              child: Text(
                option.optionKey,
                style: context.text(
                  AppTextStyles.caption,
                  weight: 700,
                  color: keyInk,
                ),
              ),
            ),
            SizedBox(width: 11.dp(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (option.hasText(language))
                    Text(
                      option.text.resolve(language),
                      style: context.text(
                        AppTextStyles.body,
                        weight: 600,
                        color: colors.ink,
                      ),
                    ),
                  // Image-only options must stay individually selectable and
                  // show an unambiguous selected state (PRD 5.4.1), which is
                  // why the border and key colour carry the state rather
                  // than a subtle tint on the artwork.
                  if (option.hasMedia) ...[
                    if (option.hasText(language))
                      SizedBox(height: AppSpacing.sm.dp(context)),
                    QuestionDiagram(media: option.media!, maxHeight: 110),
                  ],
                ],
              ),
            ),
            if (mark != null) ...[
              SizedBox(width: AppSpacing.sm.dp(context)),
              Icon(
                mark,
                size: 18.dp(context),
                color: isCorrect ? colors.accentSoftInk : colors.dangerInk,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A question's worked explanation: the text, then its ordered sequence of
/// step images with their captions (PRD 5.4.2).
class ExplanationBody extends StatelessWidget {
  const ExplanationBody({required this.question, super.key});

  final Question question;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question.explanation.resolve(language),
          style: context.text(
            AppTextStyles.bodySmall,
            color: colors.ink,
            height: 1.6,
          ),
        ),
        for (final media in question.explanationMedia) ...[
          SizedBox(height: AppSpacing.md.dp(context)),
          QuestionDiagram(media: media, maxHeight: 160),
          if (media.caption.resolveOrNull(language) != null) ...[
            SizedBox(height: AppSpacing.xs.dp(context)),
            Text(
              media.caption.resolve(language),
              style: context.text(
                AppTextStyles.captionSmall,
                color: colors.inkMuted,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// The in-place language toggle from PRD 6.5.
///
/// It writes the app's language setting, so the question re-renders in the
/// new language without losing whatever state the screen holds.
class QuestionLanguageToggle extends ConsumerWidget {
  const QuestionLanguageToggle({this.color, super.key});

  /// The icon and label colour; the muted ink when null.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = color ?? context.colors.inkMuted;
    final current = ref.watch(languageProvider);

    return PopupMenuButton<AppLanguage>(
      tooltip: context.l10n.settingsLanguage,
      onSelected: (value) =>
          ref.read(appSettingsProvider.notifier).setLanguage(value),
      itemBuilder: (context) => [
        for (final language in AppLanguage.values)
          PopupMenuItem(
            value: language,
            child: Text(switch (language) {
              AppLanguage.sinhala => context.l10n.languageSinhala,
              AppLanguage.tamil => context.l10n.languageTamil,
              AppLanguage.english => context.l10n.languageEnglish,
            }),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate_rounded, size: 14.dp(context), color: tint),
          SizedBox(width: 4.dp(context)),
          Text(
            current.code.toUpperCase(),
            style: context.text(
              AppTextStyles.overline,
              weight: 700,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}
