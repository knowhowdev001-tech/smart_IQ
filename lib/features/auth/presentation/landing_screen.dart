import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../domain/enums.dart';

/// The first screen: logo, language picker and the route into sign-up.
///
/// The language pills come before anything else deliberately. PRD 6.5 treats
/// Sinhala and Tamil as primary languages, so a user who reads neither
/// English nor the device's default can switch before being asked to do
/// anything.
class LandingScreen extends ConsumerWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: colors.brand,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // Centres on a tall screen but scrolls on a short one, so the
              // layout survives both a 16:9 budget phone and a tall 21:9.
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxl.dp(context),
                      vertical: AppSpacing.xl.dp(context),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(),
                        _Logo(size: 132.dp(context)),
                        SizedBox(height: 22.dp(context)),
                        Text(
                          l10n.appName,
                          textAlign: TextAlign.center,
                          style: context.text(
                            AppTextStyles.display,
                            weight: 800,
                            color: colors.brandInk,
                          ),
                        ),
                        SizedBox(height: 14.dp(context)),
                        Text(
                          l10n.landingWelcome,
                          style: context.text(
                            AppTextStyles.titleSmall,
                            weight: 700,
                            color: colors.brandInk,
                          ),
                        ),
                        SizedBox(height: AppSpacing.lg.dp(context)),
                        _LanguagePills(
                          selected: language,
                          onSelected: (value) => ref
                              .read(appSettingsProvider.notifier)
                              .setLanguage(value),
                        ),
                        SizedBox(height: AppSpacing.xl.dp(context)),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: 280.dp(context),
                          ),
                          child: Text(
                            l10n.landingBlurb,
                            textAlign: TextAlign.center,
                            style: context.text(
                              AppTextStyles.body,
                              weight: 500,
                              color: colors.brandInkMuted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        SizedBox(height: AppSpacing.xxl.dp(context)),
                        SiqButton(
                          label: l10n.landingGetStarted,
                          variant: SiqButtonVariant.inverse,
                          onPressed: () => context.push(Routes.signup),
                        ),
                        SizedBox(height: AppSpacing.lg.dp(context)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                l10n.landingHaveAccount,
                                style: context.text(
                                  AppTextStyles.bodySmall,
                                  color: colors.brandInkMuted,
                                ),
                              ),
                            ),
                            SizedBox(width: AppSpacing.xs.dp(context)),
                            GestureDetector(
                              onTap: () => context.push(Routes.login),
                              child: Text(
                                l10n.landingLogIn,
                                style: context.text(
                                  AppTextStyles.bodySmall,
                                  weight: 700,
                                  color: colors.brandInk,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/images/app_logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The logo is decorative here; the wordmark beside it carries the
        // name for a screen reader.
        excludeFromSemantics: true,
      ),
    );
  }
}

/// The three language pills. Shown on the landing screen and again in
/// settings, so it lives here and is reused rather than duplicated.
class _LanguagePills extends StatelessWidget {
  const _LanguagePills({required this.selected, required this.onSelected});

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    String labelFor(AppLanguage language) => switch (language) {
          AppLanguage.sinhala => l10n.languageSinhala,
          AppLanguage.tamil => l10n.languageTamil,
          AppLanguage.english => l10n.languageEnglish,
        };

    return Container(
      padding: EdgeInsets.all(4.dp(context)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22.dp(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final language in AppLanguage.values)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 2.dp(context)),
              child: _Pill(
                label: labelFor(language),
                selected: language == selected,
                onTap: () => onSelected(language),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(18.dp(context));

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.brandInk : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 15.dp(context),
              vertical: AppSpacing.sm.dp(context),
            ),
            child: Text(
              label,
              style: context.text(
                AppTextStyles.caption,
                weight: 700,
                color: selected ? colors.brand : colors.brandInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
