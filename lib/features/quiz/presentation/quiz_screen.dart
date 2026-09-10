
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../data/repositories/repositories.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/content.dart';
import '../../billing/presentation/plan_sheet.dart';
import '../../results/presentation/results_screen.dart';
import '../application/quiz_controller.dart';
import 'widgets/question_diagram.dart';

/// The question screen: progress, stem, options, explanation and the
/// single primary action that drives the session forward.
class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final state = ref.watch(quizControllerProvider);

    // Once the session is scored, hand off to results rather than keeping
    // the quiz mounted behind it.
    ref.listen(quizControllerProvider, (previous, next) {
      final result = next.valueOrNull?.result;
      if (result != null && previous?.valueOrNull?.result == null) {
        ref.read(lastResultProvider.notifier).state = result;
        context.pushReplacement(Routes.results);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit(context, ref);
      },
      child: Scaffold(
        backgroundColor: colors.page,
        body: SafeArea(
          child: state.when(
            loading: () => SiqLoader(message: context.l10n.loading),
            error: (error, _) => _QuizError(error: error),
            data: (quiz) => _QuizBody(quiz: quiz),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmQuit(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final quiz = ref.read(quizControllerProvider).valueOrNull;

    // Nothing answered yet means nothing to lose, so leave without asking.
    if (quiz == null || quiz.answers.isEmpty) {
      if (context.mounted) context.pop();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          l10n.quizQuitTitle,
          style: context.text(
            AppTextStyles.titleSmall,
            weight: 700,
            color: context.colors.ink,
          ),
        ),
        content: Text(
          l10n.quizQuitBody,
          style: context.text(
            AppTextStyles.bodySmall,
            color: context.colors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.quizQuitStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.quizQuitConfirm,
              style: TextStyle(color: context.colors.dangerInk),
            ),
          ),
        ],
      ),
    );

    if (leave == true && context.mounted) context.pop();
  }
}

class _QuizError extends ConsumerWidget {
  const _QuizError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    // A refused set is the conversion moment PRD 7.7 describes, so it gets
    // the plan sheet rather than a generic error.
    if (error is QuotaExceededException) {
      final quota = error as QuotaExceededException;
      final tierName = switch (quota.tier) {
        Tier.free => l10n.tierFree,
        Tier.basic => l10n.tierBasic,
        Tier.pro => l10n.tierPro,
        Tier.proPlus => l10n.tierProPlus,
      };
      return Padding(
        padding: EdgeInsets.all(AppSpacing.gutter.dp(context)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LockedBanner(
              title: l10n.lockedTitle(l10n.navPractice),
              body: l10n.lockedBody(tierName),
              onUpgrade: () => showPlanSheet(context),
            ),
            SizedBox(height: AppSpacing.lg.dp(context)),
            SiqButton(
              label: l10n.resultsHome,
              variant: SiqButtonVariant.secondary,
              expand: false,
              compact: true,
              onPressed: context.pop,
            ),
          ],
        ),
      );
    }

    return SiqMessageState.offline(
      context,
      onRetry: () => ref.read(quizControllerProvider.notifier).retry(),
    );
  }
}

class _QuizBody extends ConsumerWidget {
  const _QuizBody({required this.quiz});

  final QuizState quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;
    final question = quiz.question;

    return Column(
      children: [
        _QuizTopBar(quiz: quiz),
        Expanded(
          child: ContentColumn(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl.dp(context),
                AppSpacing.lg.dp(context),
                AppSpacing.xl.dp(context),
                AppSpacing.gutter.dp(context),
              ),
              children: [
                Text(
                  question.subTopicName.resolve(language).toUpperCase(),
                  style: context.text(
                    AppTextStyles.overline,
                    weight: 700,
                    color: colors.inkMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.md.dp(context)),
                Text(
                  question.stem.resolve(language),
                  style: context.text(
                    AppTextStyles.stem,
                    weight: 600,
                    color: colors.ink,
                  ),
                ),
                if (question.stemMedia != null) ...[
                  SizedBox(height: 14.dp(context)),
                  QuestionDiagram(media: question.stemMedia!),
                ],
                SizedBox(height: 14.dp(context)),
                for (final option in question.options)
                  Padding(
                    padding: EdgeInsets.only(bottom: 9.dp(context)),
                    child: _OptionTile(
                      option: option,
                      quiz: quiz,
                      onTap: () => ref
                          .read(quizControllerProvider.notifier)
                          .select(option.id),
                    ),
                  ),
                if (quiz.revealed) ...[
                  SizedBox(height: AppSpacing.xs.dp(context)),
                  _ExplanationCard(quiz: quiz),
                ],
                SizedBox(height: AppSpacing.xl.dp(context)),
                SiqButton(
                  label: quiz.revealed
                      ? (quiz.isLast
                          ? l10n.quizFinish
                          : l10n.quizNextQuestion)
                      : l10n.quizCheckAnswer,
                  loading: quiz.submitting,
                  onPressed: quiz.submitting ||
                          (!quiz.revealed && quiz.selectedOptionId == null)
                      ? null
                      : () => ref.read(quizControllerProvider.notifier).next(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuizTopBar extends ConsumerWidget {
  const _QuizTopBar({required this.quiz});

  final QuizState quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;
    final seconds = quiz.secondsLeft;

    final difficulty = switch (quiz.question.difficulty) {
      Difficulty.easy => l10n.quizDifficultyEasy,
      Difficulty.medium => l10n.quizDifficultyMedium,
      Difficulty.hard => l10n.quizDifficultyHard,
    };

    return Container(
      color: colors.surfaceMuted,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl.dp(context),
        AppSpacing.md.dp(context),
        AppSpacing.xl.dp(context),
        14.dp(context),
      ),
      child: ContentColumn(
        child: Column(
          children: [
            Row(
              children: [
                _CloseButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                SizedBox(width: 10.dp(context)),
                Expanded(child: SiqProgressBar(value: quiz.progress, height: 6)),
                SizedBox(width: 10.dp(context)),
                Text(
                  l10n.quizCounter(quiz.index + 1, quiz.set.length),
                  style: context.text(
                    AppTextStyles.caption,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
                if (seconds != null) ...[
                  SizedBox(width: AppSpacing.sm.dp(context)),
                  _TimerChip(seconds: seconds),
                ],
              ],
            ),
            SizedBox(height: 11.dp(context)),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.dp(context),
                    vertical: 4.dp(context),
                  ),
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(9.dp(context)),
                  ),
                  child: Text(
                    quiz.question.categoryName.resolve(language).toUpperCase(),
                    style: context.text(
                      AppTextStyles.overline,
                      weight: 700,
                      color: colors.accentSoftInk,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.xs.dp(context)),
                Text(
                  difficulty,
                  style: context.text(
                    AppTextStyles.captionSmall,
                    color: colors.inkMuted,
                  ),
                ),
                const Spacer(),
                // The in-place language toggle from PRD 6.5. Hidden for
                // verbal items, which are authored per language and have no
                // equivalent in another script.
                if (!quiz.question.languageSpecific)
                  const _LanguageToggle(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final current = ref.watch(languageProvider);

    return PopupMenuButton<AppLanguage>(
      tooltip: context.l10n.settingsLanguage,
      // Switching language here must not disturb the answer state, which is
      // why it writes to settings rather than restarting the session.
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
          Icon(Icons.translate_rounded, size: 14.dp(context),
              color: colors.inkMuted),
          SizedBox(width: 4.dp(context)),
          Text(
            current.code.toUpperCase(),
            style: context.text(
              AppTextStyles.overline,
              weight: 700,
              color: colors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(10.dp(context));

    return Material(
      color: colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: SizedBox(
          width: 30.dp(context),
          height: 30.dp(context),
          child: Icon(Icons.close_rounded, size: 15.dp(context),
              color: colors.ink),
        ),
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Turns red in the last ten seconds, which is the only warning the user
    // gets before the question auto-reveals.
    final urgent = seconds <= 10;
    final tint = urgent ? colors.dangerInk : colors.accentSoftInk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 9.dp(context),
        vertical: 4.dp(context),
      ),
      decoration: BoxDecoration(
        color: urgent ? colors.dangerSurface : colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm.dp(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 12.dp(context), color: tint),
          SizedBox(width: 4.dp(context)),
          Text(
            '$seconds',
            style: context.text(
              AppTextStyles.captionSmall,
              weight: 700,
              color: tint,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// One answer option.
///
/// Before the answer is checked the tile only shows selection. Afterwards it
/// marks the correct option and, if the user was wrong, their choice — so
/// the explanation below has something to refer to.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.quiz,
    required this.onTap,
  });

  final QuestionOption option;
  final QuizState quiz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.language;

    final selected = quiz.selectedOptionId == option.id;
    final isCorrect = quiz.question.isCorrect(option.id);
    final revealed = quiz.revealed;

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
      button: true,
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

class _ExplanationCard extends ConsumerWidget {
  const _ExplanationCard({required this.quiz});

  final QuizState quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;

    final answer = quiz.answers[quiz.question.id];
    final correct = answer?.isCorrect ?? false;

    return SiqCard(
      background: colors.surfaceMuted,
      borderColor: colors.borderStrong,
      radius: AppRadii.lg,
      padding: EdgeInsets.all(14.dp(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (correct ? l10n.quizVerdictCorrect : l10n.quizVerdictIncorrect)
                .toUpperCase(),
            style: context.text(
              AppTextStyles.caption,
              weight: 800,
              color: correct ? colors.accentSoftInk : colors.dangerInk,
              letterSpacing: 0.6,
            ),
          ),
          SizedBox(height: 7.dp(context)),
          Text(
            quiz.question.explanation.resolve(language),
            style: context.text(
              AppTextStyles.bodySmall,
              color: colors.ink,
              height: 1.6,
            ),
          ),
          // Explanations may carry an ordered sequence of images for
          // step-by-step working (PRD 5.4.2).
          for (final media in quiz.question.explanationMedia) ...[
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
          SizedBox(height: AppSpacing.md.dp(context)),
          Wrap(
            spacing: AppSpacing.sm.dp(context),
            runSpacing: AppSpacing.sm.dp(context),
            children: [
              SiqButton(
                label: l10n.quizExplainWithAi,
                variant: SiqButtonVariant.inverse,
                expand: false,
                compact: true,
                onPressed: () => _explain(context, ref),
              ),
              SiqButton(
                label: quiz.isBookmarked
                    ? l10n.quizBookmarked
                    : l10n.quizBookmark,
                variant: SiqButtonVariant.secondary,
                expand: false,
                compact: true,
                onPressed: () =>
                    ref.read(quizControllerProvider.notifier).toggleBookmark(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _explain(BuildContext context, WidgetRef ref) async {
    final answer = quiz.answers[quiz.question.id];
    await ref.read(tutorRepositoryProvider).explainQuestion(
          question: quiz.question,
          language: ref.read(languageProvider),
          selectedOptionId: answer?.selectedOptionId,
        );
    if (context.mounted) context.push(Routes.tutor);
  }
}
