import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// The mint band that heads nearly every screen, curving into the page.
///
/// The band absorbs the status bar inset itself rather than letting a
/// SafeArea push it down, which is what keeps the colour running under the
/// system bar the way the design shows it.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    required this.child,
    this.rounded = true,
    this.padding,
    super.key,
  });

  final Widget child;

  /// Screens that continue straight into a list keep square corners.
  final bool rounded;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = rounded ? AppRadii.headerBand.dp(context) : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.brand,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(radius)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: padding ??
              EdgeInsets.fromLTRB(
                AppSpacing.gutter.dp(context),
                AppSpacing.lg.dp(context),
                AppSpacing.gutter.dp(context),
                AppSpacing.xl.dp(context),
              ),
          child: child,
        ),
      ),
    );
  }
}

/// A header band carrying a back button and a title, used on the secondary
/// screens: practice, settings and notifications.
class BrandAppBar extends StatelessWidget {
  const BrandAppBar({
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.rounded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BrandHeader(
      rounded: rounded,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.dp(context),
        AppSpacing.sm.dp(context),
        AppSpacing.lg.dp(context),
        AppSpacing.lg.dp(context),
      ),
      child: Row(
        children: [
          if (onBack != null)
            _BackButton(onPressed: onBack!)
          else
            SizedBox(width: AppSpacing.xs.dp(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text(
                    AppTextStyles.titleSmall,
                    weight: 700,
                    color: colors.brandInk,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: context.text(
                      AppTextStyles.captionSmall,
                      color: colors.brandInkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(11.dp(context));

    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      child: SizedBox(
        width: AppSizes.minTapTarget,
        height: AppSizes.minTapTarget,
        child: Center(
          child: Material(
            color: colors.brandSurface,
            borderRadius: radius,
            child: InkWell(
              onTap: onPressed,
              borderRadius: radius,
              child: SizedBox(
                width: 32.dp(context),
                height: 32.dp(context),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 20.dp(context),
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered white card. The workhorse container of the design.
class SiqCard extends StatelessWidget {
  const SiqCard({
    required this.child,
    this.onTap,
    this.padding,
    this.background,
    this.borderColor,
    this.radius,
    this.bordered = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final Color? borderColor;
  final double? radius;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = BorderRadius.circular((radius ?? AppRadii.lg).dp(context));
    final resolvedPadding = padding ??
        EdgeInsets.symmetric(
          horizontal: 14.0.dp(context),
          vertical: AppSpacing.md.dp(context),
        );

    final decorated = Ink(
      decoration: BoxDecoration(
        color: background ?? colors.surface,
        borderRadius: r,
        border: bordered
            ? Border.all(color: borderColor ?? colors.border, width: 1.5)
            : null,
      ),
      child: Padding(padding: resolvedPadding, child: child),
    );

    if (onTap == null) {
      return Material(color: Colors.transparent, child: decorated);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: r, child: decorated),
    );
  }
}

/// The near-black panel behind the daily challenge and current-plan cards,
/// with the soft mint orb in its top-right corner.
class InverseCard extends StatelessWidget {
  const InverseCard({required this.child, this.padding, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final r = BorderRadius.circular(AppRadii.xl.dp(context));

    return ClipRRect(
      borderRadius: r,
      child: Container(
        decoration: BoxDecoration(color: colors.inverseSurface, borderRadius: r),
        child: Stack(
          children: [
            Positioned(
              right: -30.dp(context),
              top: -30.dp(context),
              child: Container(
                width: 120.dp(context),
                height: 120.dp(context),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brand.withValues(alpha: 0.18),
                ),
              ),
            ),
            Padding(
              padding: padding ?? EdgeInsets.all(AppSpacing.lg.dp(context)),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

/// A small stat tile: an uppercase label over a value.
///
/// Used both inside the mint band, where it sits on a translucent white
/// fill, and on the page, where it sits on the pale green surface.
class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    this.onBrand = false,
    super.key,
  });

  final String label;
  final String value;
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 13.0.dp(context),
        vertical: 11.0.dp(context),
      ),
      decoration: BoxDecoration(
        color: onBrand ? colors.brandSurface : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadii.md.dp(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: context.text(
              AppTextStyles.overline,
              weight: 700,
              color: onBrand ? colors.brandInkMuted : colors.inkMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.dp(context)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.text(
                AppTextStyles.stat,
                weight: 700,
                color: onBrand ? colors.brandInk : colors.ink,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// A bold section heading such as "Practice by category".
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 9.dp(context)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: context.text(
                AppTextStyles.section,
                weight: 700,
                color: context.colors.ink,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// The small uppercase tracked label above a group.
class OverlineLabel extends StatelessWidget {
  const OverlineLabel(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text(
        AppTextStyles.overline,
        weight: 700,
        color: color ?? context.colors.inkMuted,
      ),
    );
  }
}

/// A thin rounded progress track, used for mastery, quiz progress and the
/// per-sub-topic accuracy bars.
class SiqProgressBar extends StatelessWidget {
  const SiqProgressBar({
    required this.value,
    this.color,
    this.height = 5,
    super.key,
  });

  /// 0.0 to 1.0.
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final h = height.dp(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(h),
      child: SizedBox(
        height: h,
        child: LinearProgressIndicator(
          value: value.clamp(0.0, 1.0),
          backgroundColor: colors.accentSoft,
          valueColor: AlwaysStoppedAnimation(color ?? colors.accent),
        ),
      ),
    );
  }
}
