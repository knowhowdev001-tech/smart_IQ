import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/models/content.dart';
import '../../quiz/presentation/widgets/question_diagram.dart';
import '../../quiz/presentation/widgets/question_parts.dart';
import '../../tutor/presentation/tutor_screen.dart';

/// One saved question, read in full outside a session: the stem, every
/// option with the correct one marked, and the worked explanation.
///
/// Nothing here is answered or scored, so it spends no quota. The server
/// serves only questions the user has already seen, bookmarked or banked.
class QuestionReviewScreen extends ConsumerWidget {
  const QuestionReviewScreen({required this.questionId, super.key});

  final String questionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final question = ref.watch(savedQuestionProvider(questionId));

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(
            title: l10n.reviewTitle,
            onBack: context.pop,
            trailing: switch (question.valueOrNull) {
              // Verbal items are authored per language and have no
              // equivalent in another script (PRD A.6).
              final q? when !q.languageSpecific =>
                QuestionLanguageToggle(color: colors.brandInk),
              _ => null,
            },
          ),
          Expanded(
            child: question.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () =>
                    ref.invalidate(savedQuestionProvider(questionId)),
              ),
              data: (q) => q == null
                  ? SiqMessageState(
                      icon: Icons.help_outline_rounded,
                      title: l10n.reviewUnavailable,
                    )
                  : _ReviewBody(question: q),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewBody extends ConsumerWidget {
  const _ReviewBody({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;

    return ContentColumn(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl.dp(context),
          AppSpacing.lg.dp(context),
          AppSpacing.xl.dp(context),
          context.safeBottom(AppSpacing.gutter),
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
              // Revealed with nothing selected: the correct option is marked
              // and no choice is shown, because none is being made here.
              child: OptionTile(
                option: option,
                isCorrect: question.isCorrect(option.id),
                selected: false,
                revealed: true,
              ),
            ),
          SizedBox(height: AppSpacing.xs.dp(context)),
          SiqCard(
            background: colors.surfaceMuted,
            borderColor: colors.borderStrong,
            radius: AppRadii.lg,
            padding: EdgeInsets.all(14.dp(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.reviewExplanation.toUpperCase(),
                  style: context.text(
                    AppTextStyles.caption,
                    weight: 800,
                    color: colors.accentSoftInk,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: 7.dp(context)),
                ExplanationBody(question: question),
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
                    _BookmarkButton(questionId: question.id),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _explain(BuildContext context, WidgetRef ref) async {
    context.push(Routes.tutor, extra: TutorExplain(question: question));
  }
}

/// Saved or not is read from the bookmarks list, so this button and the
/// list it came from can never disagree.
class _BookmarkButton extends ConsumerStatefulWidget {
  const _BookmarkButton({required this.questionId});

  final String questionId;

  @override
  ConsumerState<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<_BookmarkButton> {
  bool _saving = false;

  Future<void> _toggle(bool saved) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(practiceRepositoryProvider)
          .setBookmark(questionId: widget.questionId, saved: !saved);
      ref.invalidate(bookmarksProvider);
      await ref.read(bookmarksProvider.future);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bookmarks = ref.watch(bookmarksProvider);
    final saved = bookmarks.valueOrNull
            ?.any((b) => b.questionId == widget.questionId) ??
        false;

    return SiqButton(
      label: saved ? l10n.quizBookmarked : l10n.quizBookmark,
      icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
      variant: SiqButtonVariant.secondary,
      expand: false,
      compact: true,
      loading: _saving || bookmarks.isLoading,
      onPressed: _saving || !bookmarks.hasValue ? null : () => _toggle(saved),
    );
  }
}
