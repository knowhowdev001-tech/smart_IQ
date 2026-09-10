import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/practice.dart';
import '../../quiz/application/quiz_controller.dart';

/// The result of the session just finished, set by the quiz screen on
/// submit and read here.
final lastResultProvider = StateProvider<SessionResult?>((ref) => null);

/// Per-session analysis: score, counts, sub-topic breakdown and a comparison
/// against the user's own previous sessions.
///
/// PRD 6.6 is categorical that progress is self-referential. There is no
/// percentile, no peer average and no leaderboard anywhere on this screen,
/// and the closing note says so to the user directly.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final result = ref.watch(lastResultProvider);

    if (result == null) {
      return Scaffold(
        backgroundColor: colors.page,
        body: SafeArea(
          child: SiqMessageState(
            title: l10n.errorGeneric,
            onRetry: () => context.go(Routes.home),
            retryLabel: l10n.resultsHome,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      // Backing out of results goes home rather than to the finished quiz.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: colors.page,
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ScoreHeader(result: result),
            ContentColumn(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter.dp(context),
                  AppSpacing.lg.dp(context),
                  AppSpacing.gutter.dp(context),
                  AppSpacing.gutter.dp(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatRow(result: result),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    SectionHeading(l10n.resultsBreakdown),
                    if (result.breakdown.isEmpty)
                      SiqCard(
                        background: colors.surfaceSunken,
                        borderColor: colors.divider,
                        radius: 14,
                        child: Text(
                          l10n.resultsNoBreakdown,
                          style: context.text(
                            AppTextStyles.caption,
                            color: colors.inkMuted,
                          ),
                        ),
                      )
                    else
                      for (final score in result.breakdown)
                        Padding(
                          padding:
                              EdgeInsets.only(bottom: AppSpacing.sm.dp(context)),
                          child: _BreakdownRow(score: score),
                        ),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    _HistoryCard(result: result),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    Row(
                      children: [
                        Expanded(
                          child: SiqButton(
                            label: l10n.resultsHome,
                            variant: SiqButtonVariant.secondary,
                            onPressed: () => context.go(Routes.home),
                          ),
                        ),
                        SizedBox(width: 9.dp(context)),
                        Expanded(
                          child: SiqButton(
                            label: l10n.resultsDrillWrong,
                            onPressed: result.wrongQuestionIds.isEmpty
                                ? null
                                : () {
                                    ref
                                        .read(activeQuizRequestProvider.notifier)
                                        .state = const QuizRequest(
                                      mode: PracticeMode.wrongAnswerDrill,
                                    );
                                    context.pushReplacement(Routes.quiz);
                                  },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return BrandHeader(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter.dp(context),
        AppSpacing.gutter.dp(context),
        AppSpacing.gutter.dp(context),
        AppSpacing.xxl.dp(context),
      ),
      child: ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OverlineLabel(l10n.resultsThisSession, color: colors.brandInkMuted),
            SizedBox(height: AppSpacing.sm.dp(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${result.scorePct}%',
                  style: context.text(
                    AppTextStyles.score,
                    weight: 800,
                    color: colors.brandInk,
                  ),
                ),
                SizedBox(width: 10.dp(context)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xs.dp(context)),
                    child: Text(
                      l10n.resultsScoreLine(result.correct, result.total),
                      style: context.text(
                        AppTextStyles.bodySmall,
                        weight: 600,
                        color: colors.brandInkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seconds = result.averageTime.inSeconds;

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.resultsStatCorrect,
            value: '${result.correct}',
          ),
        ),
        SizedBox(width: 9.dp(context)),
        Expanded(
          child: StatTile(
            label: l10n.resultsStatWrong,
            value: '${result.incorrect}',
          ),
        ),
        SizedBox(width: 9.dp(context)),
        Expanded(
          child: StatTile(
            label: l10n.resultsStatTime,
            value: '${seconds}s',
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.score});

  final SubTopicScore score;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pct = score.accuracyPct;
    final tint = pct < 50
        ? colors.danger
        : (pct < 70 ? colors.warning : colors.success);

    return Row(
      children: [
        Expanded(
          child: Text(
            score.name,
            style: context.text(
              AppTextStyles.caption,
              weight: 600,
              color: colors.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 10.dp(context)),
        SizedBox(
          width: 70.dp(context),
          child: SiqProgressBar(value: pct / 100, color: tint),
        ),
        SizedBox(width: 10.dp(context)),
        SizedBox(
          width: 34.dp(context),
          child: Text(
            '$pct%',
            textAlign: TextAlign.end,
            style: context.text(
              AppTextStyles.captionSmall,
              weight: 800,
              color: tint,
            ),
          ),
        ),
      ],
    );
  }
}

/// The bar chart of the user's own recent sessions.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.result});

  final SessionResult result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final history = result.ownHistory;

    return SiqCard(
      background: colors.surfaceMuted,
      borderColor: colors.border,
      padding: EdgeInsets.all(14.dp(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.resultsHistoryTitle,
            style: context.text(
              AppTextStyles.caption,
              weight: 700,
              color: colors.ink,
            ),
          ),
          SizedBox(height: 11.dp(context)),
          if (history.isEmpty)
            Text(
              l10n.resultsNoBreakdown,
              style: context.text(
                AppTextStyles.captionSmall,
                color: colors.inkMuted,
              ),
            )
          else
            SizedBox(
              height: 72.dp(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < history.length; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.5.dp(context),
                        ),
                        child: _HistoryBar(
                          pct: history[i],
                          // The final bar is the session just finished.
                          latest: i == history.length - 1,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          SizedBox(height: 10.dp(context)),
          Text(
            l10n.resultsPrivacyNote,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryBar extends StatelessWidget {
  const _HistoryBar({required this.pct, required this.latest});

  final int pct;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = latest ? colors.accent : colors.accentSoft;
    final inkTint = latest ? colors.accentSoftInk : colors.inkMuted;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$pct%',
          style: context.text(
            AppTextStyles.overline,
            weight: 800,
            color: inkTint,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 4.dp(context)),
        // Scaled against the 52dp the design allows for a full bar, so a
        // 100% session fills the plot without overflowing it.
        Container(
          height: (pct / 100 * 52).clamp(4, 52).dp(context),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(5.dp(context)),
            ),
          ),
        ),
      ],
    );
  }
}
