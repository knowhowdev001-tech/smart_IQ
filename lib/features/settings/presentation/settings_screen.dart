import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../legal/presentation/terms_sheet.dart';

/// Language, theme, notification preferences, legal and account actions.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(title: l10n.settingsTitle, onBack: context.pop),
          Expanded(
            child: ContentColumn(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter.dp(context),
                  AppSpacing.lg.dp(context),
                  AppSpacing.gutter.dp(context),
                  AppSpacing.gutter.dp(context),
                ),
                children: [
                  OverlineLabel(l10n.settingsLanguage),
                  SizedBox(height: 9.dp(context)),
                  _SegmentedRow<AppLanguage>(
                    values: AppLanguage.values,
                    selected: settings.language,
                    labelFor: (language) => switch (language) {
                      AppLanguage.sinhala => l10n.languageSinhala,
                      AppLanguage.tamil => l10n.languageTamil,
                      AppLanguage.english => l10n.languageEnglish,
                    },
                    onSelected: (value) => ref
                        .read(appSettingsProvider.notifier)
                        .setLanguage(value),
                  ),
                  SizedBox(height: AppSpacing.xl.dp(context)),

                  OverlineLabel(l10n.settingsTheme),
                  SizedBox(height: 9.dp(context)),
                  _SegmentedRow<ThemePreference>(
                    values: ThemePreference.values,
                    selected: settings.theme,
                    labelFor: (theme) => switch (theme) {
                      ThemePreference.light => l10n.settingsThemeLight,
                      ThemePreference.dark => l10n.settingsThemeDark,
                      ThemePreference.system => l10n.settingsThemeSystem,
                    },
                    onSelected: (value) =>
                        ref.read(appSettingsProvider.notifier).setTheme(value),
                  ),
                  SizedBox(height: AppSpacing.sm.dp(context)),
                  Text(
                    l10n.settingsThemeNote,
                    style: context.text(
                      AppTextStyles.captionSmall,
                      color: colors.inkMuted,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xl.dp(context)),

                  OverlineLabel(l10n.settingsNotifications),
                  SizedBox(height: 9.dp(context)),
                  const _NotificationToggles(),
                  SizedBox(height: AppSpacing.xl.dp(context)),

                  OverlineLabel(l10n.settingsLegal),
                  SizedBox(height: 9.dp(context)),
                  _LinkRow(
                    title: l10n.settingsTerms,
                    meta: l10n.settingsTermsMeta,
                    onTap: () => showTermsSheet(context),
                  ),
                  SizedBox(height: AppSpacing.xl.dp(context)),

                  OverlineLabel(l10n.settingsAccount),
                  SizedBox(height: 9.dp(context)),
                  _LinkRow(
                    title: l10n.settingsDevices,
                    meta: l10n.settingsDevicesMeta,
                    onTap: () {},
                  ),
                  SizedBox(height: 7.dp(context)),
                  _LinkRow(
                    title: l10n.settingsExportData,
                    meta: '',
                    onTap: () {},
                  ),
                  SizedBox(height: 7.dp(context)),
                  _DangerRow(
                    title: l10n.settingsDeleteAccount,
                    onTap: () => _confirmDelete(context, ref),
                  ),
                  SizedBox(height: AppSpacing.lg.dp(context)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          l10n.settingsDeleteConfirmTitle,
          style: context.text(
            AppTextStyles.titleSmall,
            weight: 700,
            color: context.colors.ink,
          ),
        ),
        content: Text(
          l10n.settingsDeleteConfirmBody,
          style: context.text(
            AppTextStyles.bodySmall,
            color: context.colors.inkMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.settingsDeleteAccount,
              style: TextStyle(color: context.colors.dangerInk),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Cascading deletion runs in a single transaction server-side
    // (rpc/delete_account, PRD 9.3).
    await ref.read(authRepositoryProvider).deleteAccount();
    ref.read(profileProvider.notifier).set(null);
    if (context.mounted) context.go(Routes.landing);
  }
}

/// A row of equal-width options. Used for both language and theme, which
/// are the same control in the design.
class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: value == values.last ? 0 : 7.dp(context),
              ),
              child: _Segment(
                label: labelFor(value),
                selected: value == selected,
                onTap: () => onSelected(value),
              ),
            ),
          ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
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
    final radius = BorderRadius.circular(15.dp(context));

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
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
              padding: EdgeInsets.symmetric(vertical: 11.dp(context)),
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text(
                    AppTextStyles.caption,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-type push toggles. PRD 6.8 requires every trigger to be individually
/// switchable, not one blanket setting.
class _NotificationToggles extends ConsumerWidget {
  const _NotificationToggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final repository = ref.watch(notificationRepositoryProvider);

    return FutureBuilder(
      future: repository.preferences(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) return const SizedBox.shrink();

        Widget toggle(String label, bool value, ValueChanged<bool> onChanged) {
          return SwitchListTile.adaptive(
            value: value,
            onChanged: (next) async {
              onChanged(next);
              // Rebuild so the FutureBuilder reflects the saved value.
              ref.invalidate(notificationRepositoryProvider);
            },
            title: Text(
              label,
              style: context.text(
                AppTextStyles.bodySmall,
                color: context.colors.ink,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeThumbColor: context.colors.accent,
          );
        }

        return Column(
          children: [
            toggle(
              l10n.notificationPrefDaily,
              prefs.dailyChallenge,
              (v) => repository
                  .savePreferences(prefs.copyWith(dailyChallenge: v)),
            ),
            toggle(
              l10n.notificationPrefStreak,
              prefs.streak,
              (v) => repository.savePreferences(prefs.copyWith(streak: v)),
            ),
            toggle(
              l10n.notificationPrefDigest,
              prefs.digest,
              (v) => repository.savePreferences(prefs.copyWith(digest: v)),
            ),
            toggle(
              l10n.notificationPrefBilling,
              prefs.billing,
              (v) => repository.savePreferences(prefs.copyWith(billing: v)),
            ),
            toggle(
              l10n.notificationPrefInactivity,
              prefs.inactivity,
              (v) => repository.savePreferences(prefs.copyWith(inactivity: v)),
            ),
          ],
        );
      },
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.meta,
    required this.onTap,
  });

  final String title;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SiqCard(
      onTap: onTap,
      radius: 15,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: AppSpacing.md.dp(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 600,
                    color: colors.ink,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  SizedBox(height: 2.dp(context)),
                  Text(
                    meta,
                    style: context.text(
                      AppTextStyles.captionSmall,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
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
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SiqCard(
      onTap: onTap,
      radius: 15,
      borderColor: colors.dangerBorder,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: AppSpacing.md.dp(context),
      ),
      child: Text(
        title,
        style: context.text(
          AppTextStyles.bodySmall,
          weight: 700,
          color: colors.dangerInk,
        ),
      ),
    );
  }
}
