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
import '../../../domain/enums.dart';
import '../../../domain/models/content.dart';
import '../../../domain/models/entitlement.dart';
import '../../../domain/models/user_profile.dart';
import '../../billing/presentation/plan_sheet.dart';
import '../../quiz/application/quiz_controller.dart';

/// The home dashboard: greeting, own-progress stats, today's quota, the
/// daily challenge, the category grid and weak areas.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final profile = ref.watch(profileProvider).valueOrNull;
    final entitlement = ref.watch(currentEntitlementProvider);
    final categories = ref.watch(categoriesProvider);
    final progress = ref.watch(progressProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: RefreshIndicator(
        color: colors.accent,
        onRefresh: () async {
          ref.invalidate(categoriesProvider);
          ref.invalidate(progressProvider);
          await ref.read(entitlementProvider.notifier).refresh(force: true);
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              profile: profile,
              streak: progress.valueOrNull?.streakDays ?? 0,
              readiness: progress.valueOrNull?.readinessScore ?? 0,
              unread: unread,
            ),
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
                    _QuotaCard(entitlement: entitlement),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    _DailyChallengeCard(entitlement: entitlement),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    SectionHeading(context.l10n.homePracticeByCategory),
                    categories.when(
                      loading: () => Padding(
                        padding: EdgeInsets.all(AppSpacing.xl.dp(context)),
                        child: const SiqLoader(),
                      ),
                      error: (_, __) => SiqMessageState.offline(
                        context,
                        onRetry: () => ref.invalidate(categoriesProvider),
                      ),
                      data: (items) => _CategoryGrid(categories: items),
                    ),
                    SizedBox(height: AppSpacing.lg.dp(context)),
                    SectionHeading(context.l10n.homePerformance),
                    progress.when(
                      loading: () => const SiqLoader(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (summary) => _WeakAreas(areas: summary.weakAreas),
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

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.streak,
    required this.readiness,
    required this.unread,
  });

  final UserProfile? profile;
  final int streak;
  final int readiness;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      < 12 => l10n.greetingMorning,
      < 17 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };

    final days = profile?.daysToExam;

    return BrandHeader(
      child: ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: context.text(
                          AppTextStyles.caption,
                          weight: 600,
                          color: colors.brandInkMuted,
                        ),
                      ),
                      Text(
                        profile?.displayName ?? '',
                        style: context.text(
                          AppTextStyles.title,
                          weight: 700,
                          color: colors.brandInk,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SiqIconButton(
                  icon: Icons.notifications_none_rounded,
                  semanticLabel: l10n.notificationsTitle,
                  badge: unread > 0,
                  onPressed: () => context.push(Routes.notifications),
                ),
                SiqIconButton(
                  icon: Icons.settings_outlined,
                  semanticLabel: l10n.settingsTitle,
                  onPressed: () => context.push(Routes.settings),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.lg.dp(context)),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: l10n.statStreak,
                    value: l10n.statDays(streak),
                    onBrand: true,
                  ),
                ),
                SizedBox(width: 9.dp(context)),
                Expanded(
                  child: StatTile(
                    label: l10n.statReadiness,
                    value: '$readiness%',
                    onBrand: true,
                  ),
                ),
                SizedBox(width: 9.dp(context)),
                Expanded(
                  child: StatTile(
                    label: l10n.statExamIn,
                    value: days == null
                        ? l10n.statNoExamDate
                        : l10n.statDaysShort(days),
                    onBrand: true,
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

/// Today's remaining question allowance.
///
/// The count shown is what the server last reported, not a client-side
/// tally. PRD 7.6 leaves enforcement entirely to the server; this only tells
/// the user where they stand.
class _QuotaCard extends StatelessWidget {
  const _QuotaCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final limits = entitlement.limits;
    final left = entitlement.usage.questionsLeft(limits);
    final unlimited = left == kUnlimited;

    final tierName = switch (entitlement.tier) {
      Tier.free => l10n.tierFree,
      Tier.basic => l10n.tierBasic,
      Tier.pro => l10n.tierPro,
      Tier.proPlus => l10n.tierProPlus,
    };

    // Turns red as the allowance runs out, which is where the upgrade
    // prompt becomes relevant.
    final tint = unlimited || left > 5 ? colors.accentSoftInk : colors.dangerInk;

    return SiqCard(
      background: colors.surfaceMuted,
      borderColor: colors.border,
      padding: EdgeInsets.symmetric(
        horizontal: 15.dp(context),
        vertical: AppSpacing.md.dp(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.quotaQuestionsToday(tierName),
                  style: context.text(
                    AppTextStyles.caption,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: 2.dp(context)),
                Text(
                  unlimited
                      ? l10n.quotaResetsAt
                      : l10n.quotaUsedOf(
                          entitlement.usage.questionsToday,
                          '${limits.questionsPerDay}',
                        ),
                  style: context.text(
                    AppTextStyles.captionSmall,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md.dp(context)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                unlimited ? '∞' : '$left',
                style: context.text(
                  AppTextStyles.titleSmall,
                  weight: 800,
                  color: tint,
                ),
              ),
              Text(
                l10n.quotaLeft.toUpperCase(),
                style: context.text(
                  AppTextStyles.overline,
                  weight: 700,
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends ConsumerWidget {
  const _DailyChallengeCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final allowed = entitlement.limits.dailyChallenge;

    return InverseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dailyChallengeLabel.toUpperCase(),
            style: context.text(
              AppTextStyles.overline,
              weight: 700,
              color: colors.brand,
              letterSpacing: 0.95,
            ),
          ),
          SizedBox(height: AppSpacing.xs.dp(context)),
          Text(
            l10n.dailyChallengeTitle,
            style: context.text(
              AppTextStyles.titleSmall,
              weight: 700,
              color: colors.inverseInk,
            ),
          ),
          SizedBox(height: AppSpacing.xxs.dp(context)),
          Text(
            l10n.dailyChallengeBlurb,
            style: context.text(
              AppTextStyles.caption,
              color: colors.inverseInkMuted,
            ),
          ),
          SizedBox(height: 14.dp(context)),
          SiqButton(
            label: allowed
                ? l10n.dailyChallengeStart
                : l10n.actionUpgrade,
            expand: false,
            compact: true,
            onPressed: () {
              if (!allowed) {
                showPlanSheet(context);
                return;
              }
              ref.read(activeQuizRequestProvider.notifier).state =
                  const QuizRequest(mode: PracticeMode.dailyChallenge);
              context.push(Routes.quiz);
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.categories});

  final List<Category> categories;

  static const _icons = {
    'gk': Icons.public_rounded,
    'ca': Icons.newspaper_rounded,
    'iq': Icons.psychology_alt_rounded,
    'mock': Icons.timer_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final language = context.language;
    final scale = AppScale.of(context);

    // The tile holds a fixed stack of icon, title and meta, so its height is
    // driven by text rather than by the device. It has to grow with the
    // user's font scale, otherwise an enlarged system font pushes the meta
    // line straight out of the bottom.
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        // Two columns on a phone, three once there is room for them.
        crossAxisCount: scale.isExpanded ? 3 : 2,
        mainAxisSpacing: 9.dp(context),
        crossAxisSpacing: 9.dp(context),
        // A fixed extent rather than an aspect ratio, so a longer category
        // name in Sinhala or Tamil does not change the tile's height.
        mainAxisExtent: (140 * textScale).dp(context),
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return SiqCard(
          onTap: () => context.push(
            '${Routes.practiceCategory}?category=${category.key}',
          ),
          padding: EdgeInsets.all(14.dp(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30.dp(context),
                height: 30.dp(context),
                decoration: BoxDecoration(
                  color: context.colors.accentSoft,
                  borderRadius: BorderRadius.circular(10.dp(context)),
                ),
                child: Icon(
                  _icons[category.key] ?? Icons.category_rounded,
                  size: 16.dp(context),
                  color: context.colors.accentSoftInk,
                ),
              ),
              SizedBox(height: AppSpacing.sm.dp(context)),
              Text(
                category.name.resolve(language),
                style: context.text(
                  AppTextStyles.section,
                  weight: 700,
                  color: context.colors.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                category.meta.resolve(language),
                style: context.text(
                  AppTextStyles.captionSmall,
                  color: context.colors.inkMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WeakAreas extends ConsumerWidget {
  const _WeakAreas({required this.areas});

  final List<WeakArea> areas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;

    if (areas.isEmpty) {
      return Text(
        context.l10n.homeWeakAreasEmpty,
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
                        Text(
                          area.name,
                          style: context.text(
                            AppTextStyles.bodySmall,
                            weight: 700,
                            color: colors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xs.dp(context)),
                        SiqProgressBar(
                          value: area.accuracy / 100,
                          color: _tintFor(context, area.accuracy),
                        ),
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
