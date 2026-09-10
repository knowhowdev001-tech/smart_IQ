import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/enums.dart';

/// The plan picker, opened at the point a limit is hit.
///
/// PRD 7.7 wants the upgrade prompt in context and in the user's language,
/// leading directly to the rail available on that platform: telco daily for
/// Basic, RevenueCat for Pro and Pro+.
Future<void> showPlanSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (context) => const _PlanSheet(),
  );
}

class _PlanSheet extends ConsumerWidget {
  const _PlanSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final current = ref.watch(currentEntitlementProvider).tier;

    String nameFor(Tier tier) => switch (tier) {
          Tier.free => l10n.tierFree,
          Tier.basic => l10n.tierBasic,
          Tier.pro => l10n.tierPro,
          Tier.proPlus => l10n.tierProPlus,
        };

    String blurbFor(Tier tier) => switch (tier) {
          Tier.free => l10n.tierFreeBlurb,
          Tier.basic => l10n.tierBasicBlurb,
          Tier.pro => l10n.tierProBlurb,
          Tier.proPlus => l10n.tierProPlusBlurb,
        };

    // Indicative prices. Real amounts come from the telco routing table and
    // from RevenueCat's offerings, not from the client.
    String priceFor(Tier tier) => switch (tier) {
          Tier.free => l10n.planPriceFree,
          Tier.basic => l10n.planPriceDaily('10.00'),
          Tier.pro => l10n.planPriceMonthly('490'),
          Tier.proPlus => l10n.planPriceMonthly('890'),
        };

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.sheet.dp(context)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter.dp(context),
          AppSpacing.xl.dp(context),
          AppSpacing.gutter.dp(context),
          AppSpacing.gutter.dp(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44.dp(context),
                height: 4.dp(context),
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg.dp(context)),
            Text(
              l10n.planSheetTitle,
              style: context.text(
                AppTextStyles.titleSmall,
                weight: 700,
                color: colors.ink,
              ),
            ),
            SizedBox(height: AppSpacing.xxs.dp(context)),
            Text(
              l10n.planSheetBlurb,
              style: context.text(
                AppTextStyles.caption,
                color: colors.inkMuted,
              ),
            ),
            SizedBox(height: 14.dp(context)),
            for (final tier in Tier.values)
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm.dp(context)),
                child: _PlanRow(
                  name: nameFor(tier),
                  blurb: blurbFor(tier),
                  price: priceFor(tier),
                  current: tier == current,
                  // Free Fallback is a state you land in, never one you buy.
                  onTap: tier == Tier.free || tier == current
                      ? null
                      : () async {
                          await ref
                              .read(entitlementProvider.notifier)
                              .subscribe(tier);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.name,
    required this.blurb,
    required this.price,
    required this.current,
    required this.onTap,
  });

  final String name;
  final String blurb;
  final String price;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadii.lg.dp(context));

    return Material(
      color: current ? colors.accentSoft : colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: current ? colors.accent : colors.border,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 15.dp(context),
              vertical: 13.dp(context),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: context.text(
                                AppTextStyles.body,
                                weight: 700,
                                color: colors.ink,
                              ),
                            ),
                          ),
                          if (current) ...[
                            SizedBox(width: AppSpacing.sm.dp(context)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm.dp(context),
                                vertical: 2.dp(context),
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius:
                                    BorderRadius.circular(10.dp(context)),
                              ),
                              child: Text(
                                context.l10n.planCurrent,
                                style: context.text(
                                  AppTextStyles.overline,
                                  weight: 700,
                                  color: colors.accentInk,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: AppSpacing.xxs.dp(context)),
                      Text(
                        blurb,
                        style: context.text(
                          AppTextStyles.captionSmall,
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.md.dp(context)),
                Text(
                  price,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 800,
                    color: colors.accentSoftInk,
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
