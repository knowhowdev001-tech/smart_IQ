import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/content.dart';
import '../../billing/presentation/plan_sheet.dart';
import '../../quiz/application/quiz_controller.dart';

/// Mode picker and sub-topic list for one category.
class PracticeScreen extends ConsumerStatefulWidget {
  const PracticeScreen({required this.categoryKey, super.key});

  final String categoryKey;

  @override
  ConsumerState<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends ConsumerState<PracticeScreen> {
  PracticeMode _mode = PracticeMode.quick;

  /// Mock exams are their own mode regardless of the picker, so the category
  /// decides the base set rather than the toggle.
  bool get _isMockCategory => widget.categoryKey == 'mock';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = context.language;
    final entitlement = ref.watch(currentEntitlementProvider);
    final subTopics = ref.watch(subTopicsProvider(widget.categoryKey));
    final categories = ref.watch(categoriesProvider).valueOrNull;

    final category = categories?.where((c) => c.key == widget.categoryKey);
    final title = category == null || category.isEmpty
        ? l10n.navPractice
        : category.first.name.resolve(language);
    final subtitle = category == null || category.isEmpty
        ? null
        : category.first.meta.resolve(language);

    final locked = !entitlement.limits.allows(_mode);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(
            title: title,
            subtitle: subtitle,
            onBack: context.pop,
          ),
          Expanded(
            child: subTopics.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () =>
                    ref.invalidate(subTopicsProvider(widget.categoryKey)),
              ),
              data: (topics) => ContentColumn(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl.dp(context),
                    AppSpacing.lg.dp(context),
                    AppSpacing.xl.dp(context),
                    AppSpacing.xl.dp(context),
                  ),
                  children: [
                    if (!_isMockCategory) ...[
                      _ModePicker(
                        selected: _mode,
                        onSelected: (mode) => setState(() => _mode = mode),
                      ),
                      SizedBox(height: 14.dp(context)),
                      if (locked) ...[
                        LockedBanner(
                          title: l10n.lockedTitle(_modeName(context, _mode)),
                          body: l10n.lockedBody(_tierName(context)),
                          onUpgrade: () => showPlanSheet(context),
                        ),
                        SizedBox(height: 14.dp(context)),
                      ],
                    ],
                    SectionHeading(l10n.practiceSubTopics),
                    if (topics.isEmpty)
                      Text(
                        l10n.practiceNoSubTopics,
                        style: context.text(
                          AppTextStyles.caption,
                          color: colors.inkMuted,
                        ),
                      )
                    else
                      for (final topic in topics)
                        Padding(
                          padding: EdgeInsets.only(bottom: 7.dp(context)),
                          child: _SubTopicRow(
                            subTopic: topic,
                            enabled: !locked,
                            onTap: () => _start(topic),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _start(SubTopic topic) {
    ref.read(activeQuizRequestProvider.notifier).state = QuizRequest(
      mode: _isMockCategory ? PracticeMode.mockExam : _mode,
      subTopicId: _isMockCategory ? null : topic.id,
      categoryKey: widget.categoryKey,
      size: _isMockCategory
          ? (topic.id == 'mock-full' ? 100 : 50)
          : null,
    );
    context.push(Routes.quiz);
  }

  String _modeName(BuildContext context, PracticeMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      PracticeMode.quick => l10n.practiceModeQuick,
      PracticeMode.timed => l10n.practiceModeTimed,
      PracticeMode.speed => l10n.practiceModeSpeed,
      PracticeMode.adaptive => l10n.practiceModeAdaptive,
      _ => l10n.navPractice,
    };
  }

  String _tierName(BuildContext context) {
    final l10n = context.l10n;
    return switch (ref.read(currentEntitlementProvider).tier) {
      Tier.free => l10n.tierFree,
      Tier.basic => l10n.tierBasic,
      Tier.pro => l10n.tierPro,
      Tier.proPlus => l10n.tierProPlus,
    };
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selected, required this.onSelected});

  final PracticeMode selected;
  final ValueChanged<PracticeMode> onSelected;

  static const _modes = [
    PracticeMode.quick,
    PracticeMode.timed,
    PracticeMode.speed,
    PracticeMode.adaptive,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    (String, String) labelFor(PracticeMode mode) => switch (mode) {
          PracticeMode.quick => (
              l10n.practiceModeQuick,
              l10n.practiceModeQuickMeta,
            ),
          PracticeMode.timed => (
              l10n.practiceModeTimed,
              l10n.practiceModeTimedMeta,
            ),
          PracticeMode.speed => (
              l10n.practiceModeSpeed,
              l10n.practiceModeSpeedMeta,
            ),
          _ => (l10n.practiceModeAdaptive, l10n.practiceModeAdaptiveMeta),
        };

    // Wraps rather than scrolls, so all four stay visible on a narrow phone
    // instead of hiding the last one off-screen.
    return Wrap(
      spacing: AppSpacing.sm.dp(context),
      runSpacing: AppSpacing.sm.dp(context),
      children: [
        for (final mode in _modes)
          _ModeChip(
            label: labelFor(mode).$1,
            meta: labelFor(mode).$2,
            selected: mode == selected,
            onTap: () => onSelected(mode),
          ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadii.md.dp(context));

    return Material(
      color: selected ? colors.accentSoft : colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? colors.accent : colors.border,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.dp(context),
              vertical: 11.dp(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.text(
                    AppTextStyles.caption,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: 2.dp(context)),
                Text(
                  meta,
                  style: context.text(
                    AppTextStyles.overline,
                    color: colors.inkMuted,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubTopicRow extends StatelessWidget {
  const _SubTopicRow({
    required this.subTopic,
    required this.enabled,
    required this.onTap,
  });

  final SubTopic subTopic;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final language = context.language;
    final mastery = subTopic.mastery;

    final tint = switch (mastery) {
      null => colors.inkFaint,
      final value when value < 50 => colors.danger,
      final value when value < 70 => colors.warning,
      _ => colors.success,
    };

    return SiqCard(
      onTap: enabled ? onTap : null,
      radius: 15,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: 11.dp(context),
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subTopic.name.resolve(language),
                    style: context.text(
                      AppTextStyles.bodySmall,
                      weight: 600,
                      color: colors.ink,
                    ),
                  ),
                  // The English name sits under the localised one, since
                  // exam papers and study groups often use it.
                  if (language != AppLanguage.english &&
                      subTopic.name.hasLanguage(AppLanguage.english)) ...[
                    SizedBox(height: 2.dp(context)),
                    Text(
                      subTopic.name.resolve(AppLanguage.english),
                      style: context.text(
                        AppTextStyles.captionSmall,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: AppSpacing.sm.dp(context)),
            if (mastery != null)
              Text(
                '$mastery%',
                style: context.text(
                  AppTextStyles.captionSmall,
                  weight: 700,
                  color: tint,
                ),
              ),
            SizedBox(width: AppSpacing.sm.dp(context)),
            Icon(
              Icons.chevron_right_rounded,
              size: 17.dp(context),
              color: colors.inkFaint,
            ),
          ],
        ),
      ),
    );
  }
}
