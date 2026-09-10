import 'package:flutter/material.dart';

import '../../../../core/theme/app_scale.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';

/// The shared auth layout: logo and title on the mint band, with a white
/// sheet overlapping it from below.
///
/// The sheet is pulled up over the band by a negative margin, which is what
/// produces the overlap in the design. It scrolls independently so the
/// keyboard never covers a field on a short screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.brand,
      // The sheet must move with the keyboard rather than being covered.
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: colors.brand,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.dp(context),
                  AppSpacing.sm.dp(context),
                  AppSpacing.md.dp(context),
                  46.dp(context),
                ),
                child: Column(
                  children: [
                    if (onBack != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: onBack,
                          icon: Icon(
                            Icons.chevron_left_rounded,
                            color: colors.brandInk,
                            size: 26.dp(context),
                          ),
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                        ),
                      ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(19.dp(context)),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: 76.dp(context),
                        height: 76.dp(context),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    SizedBox(height: AppSpacing.md.dp(context)),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: context.text(
                        AppTextStyles.headline,
                        weight: 700,
                        color: colors.brandInk,
                      ),
                    ),
                    SizedBox(height: AppSpacing.xxs.dp(context)),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: context.text(
                        AppTextStyles.caption,
                        weight: 500,
                        color: colors.brandInkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: Offset(0, -28.dp(context)),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(30.dp(context)),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xxl.dp(context),
                      30.dp(context),
                      AppSpacing.xxl.dp(context),
                      AppSpacing.xxl.dp(context) +
                          MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "Don't have an account? Signup" row at the foot of the auth sheets.
class AuthSwitchRow extends StatelessWidget {
  const AuthSwitchRow({
    required this.prompt,
    required this.action,
    required this.onTap,
    super.key,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(14.dp(context));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            prompt,
            style: context.text(
              AppTextStyles.caption,
              color: colors.inkMuted,
            ),
          ),
        ),
        SizedBox(width: AppSpacing.sm.dp(context)),
        Material(
          color: colors.accentSoft,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.dp(context),
                vertical: AppSpacing.xs.dp(context),
              ),
              child: Text(
                action,
                style: context.text(
                  AppTextStyles.captionSmall,
                  weight: 700,
                  color: colors.accentSoftInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
