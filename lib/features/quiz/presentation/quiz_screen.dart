
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
import '../../billing/presentation/plan_sheet.dart';
import '../../results/presentation/results_screen.dart';
import '../application/quiz_controller.dart';
import 'widgets/question_diagram.dart';
import 'widgets/question_parts.dart';

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
        // The ranged dashboard on that screen counts this session too.
        ref.invalidate(rangeStatsProvider);
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

    // Two different refusals, one prompt: the allowance is spent, or the
    // tier never included this mode at all. Both are the conversion moment
    // PRD 7.7 describes, so both get the plan sheet rather than an error.
    final failure = error;
    if (failure is QuotaExceededException ||
        failure is UpgradeRequiredException) {
      final tier = failure is QuotaExceededException
          ? failure.tier
          : ref.watch(currentEntitlementProvider).tier;
      final tierName = switch (tier) {
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

    // An exhausted bank is an empty state, not a failure: retrying the same
    // filter would return the same nothing.
    if (failure is EmptyPracticeSetException) {
      return SiqMessageState(
        title: l10n.quizNoQuestionsTitle,
        body: l10n.quizNoQuestionsBody,
        icon: Icons.inbox_rounded,
        retryLabel: l10n.resultsHome,
        onRetry: context.pop,
      );
    }

    // Where a retry after a dropped connection lands once the first attempt
    // actually reached the server.
    if (failure is AlreadySubmittedException) {
      return SiqMessageState(
        title: l10n.quizAlreadySubmittedTitle,
        body: l10n.quizAlreadySubmittedBody,
        icon: Icons.check_circle_outline_rounded,
        retryLabel: l10n.resultsHome,
        onRetry: context.pop,
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
                    child: OptionTile(
                      option: option,
                      isCorrect: question.isCorrect(option.id),
                      selected: quiz.selectedOptionId == option.id,
                      revealed: quiz.revealed,
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
                  const QuestionLanguageToggle(),
              ],
            ),
          ],
        ),
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

class _ExplanationCard extends ConsumerWidget {
  const _ExplanationCard({required this.quiz});

  final QuizState quiz;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;

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
          ExplanationBody(question: quiz.question),
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
