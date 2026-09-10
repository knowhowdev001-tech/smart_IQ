import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'siq_button.dart';

/// A centred message with an optional retry.
///
/// PRD 11 requires every screen to have a defined offline state showing a
/// connection error and a retry, never a degraded local mode, and both
/// themes must be verified across error, empty and loading states.
class SiqMessageState extends StatelessWidget {
  const SiqMessageState({
    required this.title,
    this.body,
    this.icon,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  /// The connection state from PRD 12, which is the same on every screen.
  factory SiqMessageState.offline(
    BuildContext context, {
    VoidCallback? onRetry,
  }) {
    final l10n = AppL10n.of(context);
    return SiqMessageState(
      title: l10n.errorOffline,
      body: l10n.errorOfflineBody,
      icon: Icons.wifi_off_rounded,
      onRetry: onRetry,
      retryLabel: l10n.actionRetry,
    );
  }

  final String title;
  final String? body;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.xxl.dp(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 56.dp(context),
                height: 56.dp(context),
                decoration: BoxDecoration(
                  color: colors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26.dp(context),
                  color: colors.accentSoftInk,
                ),
              ),
              SizedBox(height: AppSpacing.lg.dp(context)),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.text(
                AppTextStyles.titleSmall,
                weight: 700,
                color: colors.ink,
              ),
            ),
            if (body != null) ...[
              SizedBox(height: AppSpacing.sm.dp(context)),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: context.text(
                  AppTextStyles.bodySmall,
                  color: colors.inkMuted,
                ),
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: AppSpacing.xl.dp(context)),
              SiqButton(
                label: retryLabel ?? AppL10n.of(context).actionRetry,
                onPressed: onRetry,
                expand: false,
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The app's loading indicator, themed so it is correct before entitlement
/// resolves (PRD 7.3).
class SiqLoader extends StatelessWidget {
  const SiqLoader({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28.dp(context),
            height: 28.dp(context),
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
          if (message != null) ...[
            SizedBox(height: AppSpacing.md.dp(context)),
            Text(
              message!,
              style: context.text(
                AppTextStyles.caption,
                color: colors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The pale-red banner used when a feature is above the user's tier or a
/// daily allowance is spent.
///
/// PRD 7.7 wants the upgrade prompt at the point of exhaustion, in context
/// and in the user's language, leading straight to the right rail.
class LockedBanner extends StatelessWidget {
  const LockedBanner({
    required this.title,
    required this.body,
    required this.onUpgrade,
    this.upgradeLabel,
    super.key,
  });

  final String title;
  final String body;
  final VoidCallback onUpgrade;
  final String? upgradeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: AppSpacing.md.dp(context),
      ),
      decoration: BoxDecoration(
        color: colors.dangerSurface,
        borderRadius: BorderRadius.circular(AppRadii.md.dp(context)),
        border: Border.all(color: colors.dangerBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: context.text(
              AppTextStyles.caption,
              weight: 700,
              color: colors.dangerInk,
            ),
          ),
          SizedBox(height: AppSpacing.xxs.dp(context)),
          Text(
            body,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.dangerInk.withValues(alpha: 0.85),
            ),
          ),
          SizedBox(height: 9.dp(context)),
          SiqButton(
            label: upgradeLabel ?? AppL10n.of(context).actionUpgrade,
            onPressed: onUpgrade,
            expand: false,
            compact: true,
          ),
        ],
      ),
    );
  }
}
