import 'package:flutter/material.dart';

import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum SiqButtonVariant {
  /// Filled green pill. The single primary action on a screen.
  primary,

  /// Outlined pill on the page surface.
  secondary,

  /// Filled near-black pill, used on the daily-challenge and result cards.
  inverse,

  /// Small pale-green chip used for inline actions such as "Log in".
  chip,
}

/// The pill button from the design.
///
/// Height, radius and padding are all authored in design space and scaled,
/// so the control keeps its proportions from a 320dp phone to a tablet while
/// never dropping below the 48dp minimum tap target.
class SiqButton extends StatelessWidget {
  const SiqButton({
    required this.label,
    required this.onPressed,
    this.variant = SiqButtonVariant.primary,
    this.icon,
    this.expand = true,
    this.compact = false,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final SiqButtonVariant variant;
  final IconData? icon;

  /// Fills the available width. Off for buttons that sit inline in a row.
  final bool expand;

  /// The shorter 38dp height used inside cards.
  final bool compact;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null && !loading;

    final (background, foreground, border) = switch (variant) {
      SiqButtonVariant.primary => (colors.accent, colors.accentInk, null),
      SiqButtonVariant.secondary => (
          Colors.transparent,
          colors.ink,
          colors.borderStrong,
        ),
      SiqButtonVariant.inverse => (
          colors.inverseSurface,
          colors.inverseInk,
          null,
        ),
      SiqButtonVariant.chip => (
          colors.accentSoft,
          colors.accentSoftInk,
          null,
        ),
    };

    final designHeight = switch (variant) {
      SiqButtonVariant.chip => 28.0,
      _ => compact ? AppSizes.buttonHeightSmall : AppSizes.buttonHeight,
    };
    final height = designHeight.dp(context);
    final radius = height / 2;

    final textStyle = context.text(
      variant == SiqButtonVariant.chip
          ? AppTextStyles.captionSmall
          : (compact ? AppTextStyles.buttonSmall : AppTextStyles.button),
      weight: 700,
      color: enabled ? foreground : foreground.withValues(alpha: 0.45),
    );

    final child = loading
        ? SizedBox(
            width: 18.dp(context),
            height: 18.dp(context),
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(foreground),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16.dp(context), color: textStyle.color),
                SizedBox(width: AppSpacing.xs.dp(context)),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ConstrainedBox(
        // Never let scaling shrink a control below the platform minimum.
        constraints: BoxConstraints(
          minHeight: variant == SiqButtonVariant.chip
              ? 0
              : AppSizes.minTapTarget,
        ),
        child: Material(
          color: enabled ? background : background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(radius),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              height: height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: border == null
                    ? null
                    : Border.all(color: border, width: 1.5),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: (variant == SiqButtonVariant.chip ? 12.0 : 20.0)
                      .dp(context),
                ),
                child: Center(
                  widthFactor: expand ? null : 1,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small translucent square icon buttons in the mint header band.
class SiqIconButton extends StatelessWidget {
  const SiqIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.badge = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;

  /// Draws the unread dot used on the notifications bell.
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = AppSizes.iconButton.dp(context);

    return Semantics(
      button: true,
      label: semanticLabel,
      child: SizedBox(
        // The visual square stays 34dp as drawn, but the tap target is
        // padded out to the platform minimum.
        width: AppSizes.minTapTarget,
        height: AppSizes.minTapTarget,
        child: Center(
          child: Material(
            color: colors.brandSurface,
            borderRadius: BorderRadius.circular(AppRadii.sm.dp(context)),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadii.sm.dp(context)),
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, size: 17.dp(context), color: colors.brandInk),
                    if (badge)
                      Positioned(
                        top: 6.dp(context),
                        right: 6.dp(context),
                        child: Container(
                          width: 7.dp(context),
                          height: 7.dp(context),
                          decoration: BoxDecoration(
                            color: colors.danger,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
