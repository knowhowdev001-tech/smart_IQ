import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_field.dart';
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
    StateProvider<ResultsWindow>((ref) => ResultsWindow.allTime);

/// The user's own figures over a range, for the stats, the sub-topic list and
/// the trend bars.
final rangeStatsProvider = FutureProvider.family<RangeStats, ResultsWindow>(
  (ref, window) => ref.watch(practiceRepositoryProvider).rangeStats(window),
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
    final window = ref.watch(resultsRangeProvider);
    final stats = ref.watch(rangeStatsProvider(window));

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
            const _ScoreHeader(),
            ContentColumn(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter.dp(context),
                  AppSpacing.lg.dp(context),
                  AppSpacing.gutter.dp(context),
                  // The outer ListView stays full-bleed so the mint header
                  // can run under the status bar; the inset is paid here.
                  context.safeBottom(AppSpacing.gutter),
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
                            ref.invalidate(rangeStatsProvider(window)),
                      ),
                      data: (data) => _RangeBody(window: window, stats: data),
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
                                        .state = QuizRequest(
                                      mode: PracticeMode.wrongAnswerDrill,
                                      questionIds: result.wrongQuestionIds,
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

class _ScoreHeader extends ConsumerWidget {
  const _ScoreHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;

    // The live result of a quiz just finished, and failing that the same
    // figures fetched: the live one lives in memory only, so it is gone on
    // a restart or when this screen is opened from home.
    final live = ref.watch(lastResultProvider);
    final window = ref.watch(resultsRangeProvider);
    final fetched =
        ref.watch(rangeStatsProvider(window)).valueOrNull?.lastSession;

    final (scorePct, correct, total) = switch ((live, fetched)) {
      (final SessionResult r, _) => (r.scorePct, r.correct, r.total),
      (_, final SessionTotals t) => (t.scorePct, t.correct, t.total),
      // Nothing live and nothing on record: this account has never finished
      // a session, which is what the line then says.
      _ => (0, 0, 0),
    };

    final line = total == 0
        ? '${l10n.resultsScoreLine(0, 0)} · ${l10n.resultsNoAnswersYet}'
        : l10n.resultsScoreLine(correct, total);

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
            OverlineLabel(l10n.resultsLastSession, color: colors.brandInkMuted),
            SizedBox(height: AppSpacing.sm.dp(context)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$scorePct%',
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

/// The range selector: "Sort by · All time / Last 7 days / Today / Custom".
class _ShowingRow extends ConsumerWidget {
  const _ShowingRow();

  /// What the Custom chip offers the first time it is opened.
  static const _defaultCustomDays = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final window = ref.watch(resultsRangeProvider);
    final custom = window.range == ResultsRange.custom
        ? window
        : const ResultsWindow.custom(_defaultCustomDays);

    return Row(
      children: [
        OverlineLabel(l10n.resultsSortBy),
        SizedBox(width: AppSpacing.md.dp(context)),
        // Sinhala and Tamil range labels are longer than the English ones;
        // the row scrolls rather than overflowing on a narrow phone.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: SiqSegmented<ResultsWindow>(
              value: window,
              onChanged: (value) {
                // Custom has no fixed length, so choosing it asks for one
                // rather than applying whatever it last held.
                if (value.range == ResultsRange.custom) {
                  _askForDays(context, ref, custom.days!);
                  return;
                }
                ref.read(resultsRangeProvider.notifier).state = value;
              },
              segments: [
                SiqSegment(
                  value: ResultsWindow.allTime,
                  label: l10n.resultsRangeAllTime,
                ),
                SiqSegment(
                  value: ResultsWindow.week,
                  label: l10n.resultsRangeWeek,
                ),
                SiqSegment(
                  value: ResultsWindow.today,
                  label: l10n.resultsRangeToday,
                ),
                SiqSegment(
                  value: custom,
                  // Once a length is chosen the chip says what it is, so the
                  // row still reads as a set of windows rather than a verb.
                  label: window.range == ResultsRange.custom
                      ? l10n.statDays(window.days!)
                      : l10n.resultsRangeCustom,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _askForDays(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => _CustomRangeDialog(days: current),
    );

    if (days != null) {
      ref.read(resultsRangeProvider.notifier).state = ResultsWindow.custom(days);
    }
  }
}

/// Asks how many days back the figures should reach.
class _CustomRangeDialog extends StatefulWidget {
  const _CustomRangeDialog({required this.days});

  final int days;

  @override
  State<_CustomRangeDialog> createState() => _CustomRangeDialogState();
}

class _CustomRangeDialogState extends State<_CustomRangeDialog> {
  /// A year is already more history than any account here has, and it caps
  /// the chart at 365 bars.
  static const _maxDays = 365;

  late final _controller = TextEditingController(text: '${widget.days}');

  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final days = int.tryParse(_controller.text.trim());

    if (days == null || days < 1 || days > _maxDays) {
      setState(() => _error = context.l10n.errorEnterDays);
      return;
    }

    Navigator.of(context).pop(days);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(
        l10n.resultsCustomTitle,
        style: context.text(
          AppTextStyles.titleSmall,
          weight: 700,
          color: colors.ink,
        ),
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.resultsCustomBlurb,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.md.dp(context)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SiqField(
                  label: l10n.fieldDays,
                  hint: l10n.fieldDaysHint,
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  errorText: _error,
                  onSubmitted: (_) => _confirm(),
                ),
              ),
              SizedBox(width: AppSpacing.sm.dp(context)),
              // The unit sits beside the field rather than inside it, so it
              // is legible at any text scale and never mistaken for input.
              Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl.dp(context)),
                child: Text(
                  l10n.unitDays,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 600,
                    color: colors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        SiqButton(
          label: l10n.actionConfirm,
          expand: false,
          compact: true,
          onPressed: _confirm,
        ),
      ],
    );
  }
}

/// Everything the range drives: the stat tiles, the sub-topic list and the
/// trend bars.
class _RangeBody extends StatelessWidget {
  const _RangeBody({required this.window, required this.stats});

  final ResultsWindow window;
  final RangeStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatRow(window: window, stats: stats),
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
  const _StatRow({required this.window, required this.stats});

  final ResultsWindow window;
  final RangeStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final seconds = stats.averageTime.inSeconds;

    final rangeLabel = switch (window.range) {
      ResultsRange.allTime => l10n.resultsRangeAllTime,
      ResultsRange.week => l10n.resultsRangeWeek,
      ResultsRange.today => l10n.resultsRangeToday,
      ResultsRange.custom => l10n.statDays(window.days ?? 0),
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

/// The bar chart of the user's own recent days, one bar per day.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});

  /// Narrow enough to keep a week on the smallest phone, wide enough for a
  /// date label. Below this the chart scrolls rather than squeezing.
  static const _minBarWidth = 30.0;

  final List<DayPoint> history;

  Widget _bar(List<DayPoint> history, int index) => _HistoryBar(
        point: history[index],
        // The final bar is today.
        latest: index == history.length - 1,
      );

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
              l10n.resultsNoSessions,
              style: context.text(
                AppTextStyles.captionSmall,
                color: colors.inkMuted,
              ),
            )
          else
            // 76 rather than the design's 72: a full bar is 42, and this
            // app's labels are set on a 1.3 line so Sinhala and Tamil
            // ascenders are not clipped, which costs a couple of points
            // the prototype's tighter metrics did not pay.
            SizedBox(
              height: 76.dp(context),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final gap = 7.dp(context);
                  final gaps = gap * (history.length - 1);
                  final shared =
                      (constraints.maxWidth - gaps) / history.length;

                  // "All time" runs from the user's first session to today,
                  // so the bar count is unbounded. Past the point where a
                  // date label still fits, the chart scrolls instead of
                  // shrinking to hairlines.
                  if (shared >= _minBarWidth.dp(context)) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < history.length; i++) ...[
                          // The gap sits between bars rather than around
                          // each one, so the outer bars stay flush with the
                          // card's padding.
                          if (i > 0) SizedBox(width: gap),
                          Expanded(child: _bar(history, i)),
                        ],
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Opens on the most recent days; older ones are to the
                    // left, which is the direction the eye reads back in.
                    reverse: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < history.length; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          SizedBox(
                            width: _minBarWidth.dp(context),
                            child: _bar(history, i),
                          ),
                        ],
                      ],
                    ),
                  );
                },
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

  final DayPoint point;
  final bool latest;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final inkTint = latest ? colors.accentSoftInk : colors.inkMuted;
    final pct = point.accuracyPct;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$pct%',
          // Never wrapped: a seven-day axis makes the bars narrow enough for
          // "100%" to break across two lines, which pushes the column past
          // the height of the plot.
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          // Tabular figures so the labels above bars of different values
          // keep the same digit widths and stay optically aligned.
          style: context
              .text(
                AppTextStyles.overline,
                weight: 800,
                color: inkTint,
                letterSpacing: 0,
              )
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        SizedBox(height: 4.dp(context)),
        // The track is always the full 42dp and the fill carries the value,
        // so the bars are read against a common baseline rather than against
        // each other. A session with nothing correct leaves the track empty,
        // which is the honest drawing of it.
        SizedBox(
          height: 42.dp(context),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              _column(context, colors.borderStrong, 1),
              _column(context, colors.accent, (pct / 100).clamp(0.0, 1.0)),
            ],
          ),
        ),
        SizedBox(height: 4.dp(context)),
        Text(
          _dayLabel(context, point.at),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: context.text(
            AppTextStyles.axisLabel,
            weight: 600,
            color: colors.inkMuted,
          ),
        ),
      ],
    );
  }

  /// One column of the bar: the ash track at full height, or the green fill
  /// at [factor] of it.
  Widget _column(BuildContext context, Color color, double factor) =>
      FractionallySizedBox(
        heightFactor: factor,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(5.dp(context)),
            ),
          ),
        ),
      );

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
