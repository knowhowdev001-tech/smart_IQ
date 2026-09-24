import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import 'sub_topic_accuracy_list.dart';

/// Topic mastery: accuracy in every sub-topic the user has touched, worst
/// first, with the server's weak-area finding marked (PRD 6.6).
///
/// Home shows the worst three; this is the whole list behind them. Nothing
/// here compares the user with anyone else.
class MasteryScreen extends ConsumerWidget {
  const MasteryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final progress = ref.watch(progressProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(title: l10n.profileRowMastery, onBack: context.pop),
          Expanded(
            child: progress.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () => ref.invalidate(progressProvider),
              ),
              data: (summary) {
                final weakIds = {
                  for (final w in summary.weakAreas) w.subTopicId,
                };

                return RefreshIndicator(
                  color: colors.accent,
                  onRefresh: () => ref.refresh(progressProvider.future),
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
                        Row(
                          children: [
                            Expanded(
                              child: StatTile(
                                label: l10n.masteryTopics,
                                value: '${summary.subTopicAccuracy.length}',
                              ),
                            ),
                            SizedBox(width: 9.dp(context)),
                            Expanded(
                              child: StatTile(
                                label: l10n.profileStatAccuracy,
                                value:
                                    '${(summary.overallAccuracy * 100).round()}%',
                              ),
                            ),
                            SizedBox(width: 9.dp(context)),
                            Expanded(
                              child: StatTile(
                                label: l10n.masteryWeak,
                                value: '${weakIds.length}',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.lg.dp(context)),
                        Text(
                          l10n.masteryIntro,
                          style: context.text(
                            AppTextStyles.captionSmall,
                            color: colors.inkMuted,
                          ),
                        ),
                        SizedBox(height: AppSpacing.md.dp(context)),
                        SubTopicAccuracyList(
                          areas: summary.subTopicAccuracy,
                          weakIds: weakIds,
                          showSampleSize: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
