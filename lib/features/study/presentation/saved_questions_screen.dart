import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/practice.dart';
import '../../billing/presentation/plan_sheet.dart';
import '../../quiz/application/quiz_controller.dart';

/// Which saved list a [SavedQuestionsScreen] shows.
enum SavedList { bookmarks, wrongBank }

/// The user's bookmarks, or their wrong-answer bank (PRD 6.3).
///
/// Both are lists of questions the user has already seen, so tapping one
/// opens it in full, answer and explanation included, without spending any
/// quota. The bank also drills: what spaced repetition says is due, or the
/// whole bank when nothing is due yet.
class SavedQuestionsScreen extends ConsumerWidget {
  const SavedQuestionsScreen({required this.list, super.key});

  final SavedList list;

  AutoDisposeFutureProvider<List<SavedQuestion>> get _provider =>
      switch (list) {
        SavedList.bookmarks => bookmarksProvider,
        SavedList.wrongBank => wrongBankProvider,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final items = ref.watch(_provider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(
            title: switch (list) {
              SavedList.bookmarks => l10n.profileRowBookmarks,
              SavedList.wrongBank => l10n.profileRowWrongBank,
            },
            onBack: context.pop,
          ),
          Expanded(
            child: items.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () => ref.invalidate(_provider),
              ),
              data: (saved) => RefreshIndicator(
                color: colors.accent,
                onRefresh: () => ref.refresh(_provider.future),
                child: ContentColumn(
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter.dp(context),
                      AppSpacing.lg.dp(context),
                      AppSpacing.gutter.dp(context),
                      context.safeBottom(AppSpacing.gutter),
                    ),
                    children: [
                      if (list == SavedList.wrongBank) ...[
                        _BankHeader(saved: saved),
                        SizedBox(height: AppSpacing.lg.dp(context)),
                      ],
                      if (saved.isEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: AppSpacing.xl.dp(context)),
                          child: SiqMessageState(
                            icon: switch (list) {
                              SavedList.bookmarks =>
                                Icons.bookmark_outline_rounded,
                              SavedList.wrongBank => Icons.refresh_rounded,
                            },
                            title: switch (list) {
                              SavedList.bookmarks => l10n.savedBookmarksEmpty,
                              SavedList.wrongBank => l10n.bankEmpty,
                            },
                          ),
                        )
                      else
                        for (final item in saved) ...[
                          _SavedRow(item: item, list: list),
                          SizedBox(height: AppSpacing.sm.dp(context)),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the bank works, and the two ways to drill it.
class _BankHeader extends ConsumerWidget {
  const _BankHeader({required this.saved});

  final List<SavedQuestion> saved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final entitlement = ref.watch(currentEntitlementProvider);
    final allowed = entitlement.limits.allows(PracticeMode.wrongAnswerDrill);

    final now = DateTime.now();
    final due = [
      for (final s in saved)
        if (s.nextReviewAt == null || !s.nextReviewAt!.isAfter(now)) s,
    ];

    void drill(List<String>? ids) {
      ref.read(activeQuizRequestProvider.notifier).state = QuizRequest(
        mode: PracticeMode.wrongAnswerDrill,
        questionIds: ids,
      );
      context.push(Routes.quiz);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.bankIntro,
          style: context.text(
            AppTextStyles.captionSmall,
            color: colors.inkMuted,
          ),
        ),
        if (saved.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md.dp(context)),
          if (!allowed)
            LockedBanner(
              title: l10n.bankLockedTitle,
              body: l10n.bankLockedBody,
              onUpgrade: () => showPlanSheet(context),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SiqButton(
                    label: l10n.bankDrillDue(due.length),
                    // No ids: the server picks what is due, which is the
                    // same set counted here.
                    onPressed: due.isEmpty ? null : () => drill(null),
                  ),
                ),
                SizedBox(width: 9.dp(context)),
                Expanded(
                  child: SiqButton(
                    label: l10n.bankDrillAll(saved.length),
                    variant: SiqButtonVariant.secondary,
                    // Named ids reach past the schedule, so the bank is
                    // never a dead end on a day nothing is due.
                    onPressed: () =>
                        drill([for (final s in saved) s.questionId]),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _SavedRow extends ConsumerWidget {
  const _SavedRow({required this.item, required this.list});

  final SavedQuestion item;
  final SavedList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SiqCard(
      radius: 15,
      onTap: () => context.push(Routes.reviewQuestion(item.questionId)),
      padding: EdgeInsets.fromLTRB(
        14.dp(context),
        AppSpacing.md.dp(context),
        list == SavedList.bookmarks ? 4.dp(context) : 14.dp(context),
        AppSpacing.md.dp(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subTopicName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text(
                    AppTextStyles.overline,
                    weight: 700,
                    color: colors.inkMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.dp(context)),
                Text(
                  item.stemPreview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 600,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: AppSpacing.xs.dp(context)),
                switch (list) {
                  SavedList.bookmarks => _Meta(
                      text: item.savedAt == null
                          ? ''
                          : l10n.savedOn(relativeTime(l10n, item.savedAt!)),
                    ),
                  SavedList.wrongBank => _ReviewMeta(item: item),
                },
              ],
            ),
          ),
          if (list == SavedList.bookmarks)
            IconButton(
              tooltip: l10n.savedRemoveBookmark,
              icon: Icon(
                Icons.bookmark_remove_outlined,
                size: 20.dp(context),
                color: colors.inkMuted,
              ),
              onPressed: () => _remove(context, ref),
            )
          else
            Icon(
              Icons.chevron_right_rounded,
              size: 17.dp(context),
              color: colors.inkFaint,
            ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(practiceRepositoryProvider)
          .setBookmark(questionId: item.questionId, saved: false);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedBookmarkRemoved)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
    ref.invalidate(bookmarksProvider);
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.text(
        AppTextStyles.captionSmall,
        weight: color == null ? 400 : 700,
        color: color ?? context.colors.inkMuted,
      ),
    );
  }
}

/// When a banked question comes back, and how far it is from leaving.
class _ReviewMeta extends StatelessWidget {
  const _ReviewMeta({required this.item});

  final SavedQuestion item;

  /// Correct reviews it takes to retire a question (migration 0021).
  static const _reviewsToRetire = 4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final next = item.nextReviewAt;
    final due = next == null || !next.isAfter(DateTime.now());

    return Row(
      children: [
        Flexible(
          child: _Meta(
            text: due
                ? l10n.bankDueNow
                : l10n.bankNextReview(relativeFuture(l10n, next)),
            color: due ? colors.accentSoftInk : null,
          ),
        ),
        SizedBox(width: AppSpacing.sm.dp(context)),
        Semantics(
          label: l10n.bankReviewsDone(item.reviewCount),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _reviewsToRetire; i++)
                Container(
                  width: 6.dp(context),
                  height: 6.dp(context),
                  margin: EdgeInsets.only(right: 3.dp(context)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < item.reviewCount
                        ? colors.accent
                        : colors.borderStrong,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
