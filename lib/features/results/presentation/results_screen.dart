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
import '../../../core/widgets/siq_segmented.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/practice.dart';
import '../../quiz/application/quiz_controller.dart';

/// The result of the session just finished, set by the quiz screen on
/// submit and read here. Null when the screen is opened from home rather
/// than off the back of a quiz.
final lastResultProvider = StateProvider<SessionResult?>((ref) => null);

/// Which window the dashboard below the header is showing.
final resultsRangeProvider =
    StateProvider<ResultsRange>((ref) => ResultsRange.allTime);

/// The user's own figures over a range, for the stats, the sub-topic list and
/// the trend bars.
final rangeStatsProvider = FutureProvider.family<RangeStats, ResultsRange>(
  (ref, range) => ref.watch(practiceRepositoryProvider).rangeStats(range),
);

/// Score and analysis: the session just finished in the header, and the
/// user's own figures over the chosen range below it.
///
/// PRD 6.6 is categorical that progress is self-referential. There is no
/// percentile, no peer average and no leaderboard anywhere on this screen,
/// and the closing note says so to the user directly. A range narrows the
/// user's own history; it never widens it to anyone else's.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final result = ref.watch(lastResultProvider);
    final range = ref.watch(resultsRangeProvider);
    final stats = ref.watch(rangeStatsProvider(range));

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
                    const _ShowingRow(),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    stats.when(
                      loading: () => Padding(
                        padding: EdgeInsets.all(AppSpacing.xl.dp(context)),
                        child: const SiqLoader(),
                      ),
                      error: (_, __) => SiqMessageState.offline(
                        context,
                        onRetry: () =>
                            ref.invalidate(rangeStatsProvider(range)),
                      ),
                      data: (data) => _RangeBody(range: range, stats: data),
                    ),
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
                            onPressed: result == null ||
                                    result.wrongQuestionIds.isEmpty
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

  /// Null when the screen was opened from home with no session behind it.
  final SessionResult? result;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final result = this.result;

    final line = result == null
        ? '${l10n.resultsScoreLine(0, 0)} · ${l10n.resultsNoAnswersYet}'
        : l10n.resultsScoreLine(result.correct, result.total);

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
                  '${result?.scorePct ?? 0}%',
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
                      line,
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

/// The range selector: "Showing · All time / Last 7 days / Today".
class _ShowingRow extends ConsumerWidget {
  const _ShowingRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final range = ref.watch(resultsRangeProvider);

    return Row(
      children: [
        OverlineLabel(l10n.resultsShowing),
        SizedBox(width: AppSpacing.md.dp(context)),
        // Sinhala and Tamil range labels are longer than the English ones;
        // the row scrolls rather than overflowing on a narrow phone.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SiqSegmented<ResultsRange>(
              value: range,
              onChanged: (value) =>
                  ref.read(resultsRangeProvider.notifier).state = value,
              segments: [
                SiqSegment(
                  value: ResultsRange.allTime,
                  label: l10n.resultsRangeAllTime,
                ),
                SiqSegment(
                  value: ResultsRange.week,
                  label: l10n.resultsRangeWeek,
                ),
                SiqSegment(
                  value: ResultsRange.today,
                  label: l10n.resultsRangeToday,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything the range drives: the stat tiles, the sub-topic list and the
/// trend bars.
class _RangeBody extends StatelessWidget {
  const _RangeBody({required this.range, required this.stats});

  final ResultsRange range;
  final RangeStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(range: range, stats: stats),
        SizedBox(height: AppSpacing.lg.dp(context)),
        SectionHeading(l10n.resultsBreakdown),
        if (stats.breakdown.isEmpty)
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
          for (final score in stats.breakdown)
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm.dp(context)),
              child: _BreakdownRow(score: score),
            ),
        SizedBox(height: AppSpacing.lg.dp(context)),
        _HistoryCard(history: stats.history),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.range, required this.stats});

  final ResultsRange range;
  final RangeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seconds = stats.averageTime.inSeconds;

    final rangeLabel = switch (range) {
      ResultsRange.allTime => l10n.resultsRangeAllTime,
      ResultsRange.week => l10n.resultsRangeWeek,
      ResultsRange.today => l10n.resultsRangeToday,
    };

    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: l10n.resultsStatAccuracyIn(rangeLabel),
            value: '${stats.accuracyPct}%',
          ),
        ),
        SizedBox(width: 9.dp(context)),
        Expanded(
          child: StatTile(
            label: l10n.resultsStatTime,
            value: '${seconds}s',
          ),
        ),
        SizedBox(width: 9.dp(context)),
        Expanded(
          child: StatTile(
            label: l10n.resultsStatSkipped,
            value: '${stats.skipped}',
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
  const _HistoryCard({required this.history});

  final List<SessionPoint> history;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

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
              height: 92.dp(context),
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
                          point: history[i],
                          // The final bar is the most recent session.
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
  const _HistoryBar({required this.point, required this.latest});

  final SessionPoint point;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = latest ? colors.accent : colors.accentSoft;
    final inkTint = latest ? colors.accentSoftInk : colors.inkMuted;
    final pct = point.accuracyPct;

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
        SizedBox(height: 5.dp(context)),
        Text(
          _dayLabel(context, point.at),
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: context.text(
            AppTextStyles.overline,
            weight: 700,
            color: colors.inkMuted,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  /// "Today" for a session from the current Sri Lanka day, otherwise the
  /// short month and day in the user's language. Material's localisations
  /// already ship the month names, so this needs no date-format setup of its
  /// own.
  String _dayLabel(BuildContext context, DateTime at) {
    final now = DateTime.now();
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return context.l10n.resultsRangeToday;
    return MaterialLocalizations.of(context).formatShortMonthDay(at);
  }
}
