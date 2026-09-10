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
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../billing/presentation/plan_sheet.dart';

/// The profile tab: identity, own stats, current plan and the routes into
/// saved material and settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).valueOrNull;
    final progress = ref.watch(progressProvider).valueOrNull;
    final entitlement = ref.watch(currentEntitlementProvider);

    final tierName = switch (entitlement.tier) {
      Tier.free => l10n.tierFree,
      Tier.basic => l10n.tierBasic,
      Tier.pro => l10n.tierPro,
      Tier.proPlus => l10n.tierProPlus,
    };
    final tierBlurb = switch (entitlement.tier) {
      Tier.free => l10n.tierFreeBlurb,
      Tier.basic => l10n.tierBasicBlurb,
      Tier.pro => l10n.tierProBlurb,
      Tier.proPlus => l10n.tierProPlusBlurb,
    };

    return Scaffold(
      backgroundColor: colors.page,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          BrandHeader(
            child: ContentColumn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OverlineLabel(
                    l10n.profileTitle,
                    color: colors.brandInkMuted,
                  ),
                  SizedBox(height: AppSpacing.xs.dp(context)),
                  Text(
                    profile?.fullName ?? '',
                    style: context.text(
                      AppTextStyles.title,
                      weight: 700,
                      color: colors.brandInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${profile?.maskedMsisdn ?? ''} · ${l10n.profileVerified}',
                    style: context.text(
                      AppTextStyles.caption,
                      color: colors.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
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
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: l10n.profileStatAnswered,
                          value: '${progress?.questionsAnswered ?? 0}',
                        ),
                      ),
                      SizedBox(width: 9.dp(context)),
                      Expanded(
                        child: StatTile(
                          label: l10n.profileStatAccuracy,
                          value:
                              '${((progress?.overallAccuracy ?? 0) * 100).round()}%',
                        ),
                      ),
                      SizedBox(width: 9.dp(context)),
                      Expanded(
                        child: StatTile(
                          label: l10n.profileStatSessions,
                          value: '${progress?.sessionsCompleted ?? 0}',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg.dp(context)),
                  InverseCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.profileCurrentPlan.toUpperCase(),
                                    style: context.text(
                                      AppTextStyles.overline,
                                      weight: 700,
                                      color: colors.brand,
                                      letterSpacing: 0.95,
                                    ),
                                  ),
                                  SizedBox(height: 4.dp(context)),
                                  Text(
                                    tierName,
                                    style: context.text(
                                      AppTextStyles.titleSmall,
                                      weight: 700,
                                      color: colors.inverseInk,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SiqButton(
                              label: l10n.actionChange,
                              variant: SiqButtonVariant.chip,
                              expand: false,
                              onPressed: () => showPlanSheet(context),
                            ),
                          ],
                        ),
                        SizedBox(height: 11.dp(context)),
                        Text(
                          tierBlurb,
                          style: context.text(
                            AppTextStyles.caption,
                            color: colors.inverseInkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.dp(context)),
                  SectionHeading(l10n.profileStudyMaterial),
                  _Row(
                    name: l10n.profileRowBookmarks,
                    meta: l10n.profileRowBookmarksMeta,
                    icon: Icons.bookmark_outline_rounded,
                    onTap: () {},
                  ),
                  _Row(
                    name: l10n.profileRowWrongBank,
                    meta: l10n.profileRowWrongBankMeta,
                    icon: Icons.refresh_rounded,
                    onTap: () {},
                  ),
                  _Row(
                    name: l10n.profileRowMastery,
                    meta: l10n.profileRowMasteryMeta,
                    icon: Icons.insights_rounded,
                    onTap: () {},
                  ),
                  _Row(
                    name: l10n.profileRowSettings,
                    meta: l10n.profileRowSettingsMeta,
                    icon: Icons.settings_outlined,
                    onTap: () => context.push(Routes.settings),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.name,
    required this.meta,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String meta;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.only(bottom: 7.dp(context)),
      child: SiqCard(
        onTap: onTap,
        radius: 15,
        padding: EdgeInsets.symmetric(
          horizontal: 14.dp(context),
          vertical: AppSpacing.md.dp(context),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18.dp(context), color: colors.accentSoftInk),
            SizedBox(width: AppSpacing.md.dp(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: context.text(
                      AppTextStyles.bodySmall,
                      weight: 600,
                      color: colors.ink,
                    ),
                  ),
                  SizedBox(height: 2.dp(context)),
                  Text(
                    meta,
                    style: context.text(
                      AppTextStyles.captionSmall,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
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
