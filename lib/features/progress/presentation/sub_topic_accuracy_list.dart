import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/user_profile.dart';
import '../../quiz/application/quiz_controller.dart';

/// Accuracy in the sub-topics the user has practised, in the order given
/// (worst first, as the server sends it). Tapping a row drills that
/// sub-topic.
///
/// Home shows the first three as a glance; the mastery screen shows all of
/// them with the answer count and the server's weak-area finding.
class SubTopicAccuracyList extends ConsumerWidget {
  const SubTopicAccuracyList({
    required this.areas,
    this.weakIds = const {},
    this.showSampleSize = false,
    super.key,
  });

  final List<WeakArea> areas;

  /// Sub-topics `get_progress` names as weak areas. That is a finding with a
  /// sample floor, so it is taken from the server rather than re-derived
  /// from the accuracy here.
  final Set<String> weakIds;

  final bool showSampleSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;

    if (areas.isEmpty) {
      return Text(
        l10n.homeWeakAreasEmpty,
        style: context.text(
          AppTextStyles.caption,
          color: colors.inkMuted,
        ),
      );
    }

    return Column(
      children: [
        for (final area in areas)
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm.dp(context)),
            child: SiqCard(
              background: colors.surfaceMuted,
              bordered: false,
              radius: AppRadii.md,
              padding: EdgeInsets.symmetric(
                horizontal: 14.dp(context),
                vertical: AppSpacing.md.dp(context),
              ),
              onTap: () {
                ref.read(activeQuizRequestProvider.notifier).state =
                    QuizRequest(
                  mode: PracticeMode.quick,
                  subTopicId: area.subTopicId,
                );
                context.push(Routes.quiz);
              },
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                area.name,
                                style: context.text(
                                  AppTextStyles.bodySmall,
                                  weight: 700,
                                  color: colors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (weakIds.contains(area.subTopicId)) ...[
                              SizedBox(width: AppSpacing.xs.dp(context)),
                              _WeakTag(label: l10n.masteryWeak),
                            ],
                          ],
                        ),
                        SizedBox(height: AppSpacing.xs.dp(context)),
                        SiqProgressBar(
                          value: area.accuracy / 100,
                          color: _tintFor(context, area.accuracy),
                        ),
                        if (showSampleSize) ...[
                          SizedBox(height: AppSpacing.xs.dp(context)),
                          Text(
                            l10n.masteryAnswered(area.sampleSize),
                            style: context.text(
                              AppTextStyles.captionSmall,
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.dp(context)),
                  Text(
                    '${area.accuracy}%',
                    style: context.text(
                      AppTextStyles.bodySmall,
                      weight: 800,
                      color: _tintFor(context, area.accuracy),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Color _tintFor(BuildContext context, int accuracy) {
    final colors = context.colors;
    if (accuracy < 50) return colors.danger;
    if (accuracy < 70) return colors.warning;
    return colors.success;
  }
}

class _WeakTag extends StatelessWidget {
  const _WeakTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xs.dp(context),
        vertical: 1.dp(context),
      ),
      decoration: BoxDecoration(
        color: colors.dangerSurface,
        borderRadius: BorderRadius.circular(AppRadii.sm.dp(context)),
      ),
      child: Text(
        label,
        style: context.text(
          AppTextStyles.overline,
          weight: 700,
          color: colors.dangerInk,
        ),
      ),
    );
  }
}
