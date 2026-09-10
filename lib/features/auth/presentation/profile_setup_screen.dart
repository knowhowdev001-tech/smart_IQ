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
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_field.dart';
import '../../../domain/enums.dart';
import 'widgets/auth_scaffold.dart';

/// Mandatory profile creation, sitting between OTP and the first question.
///
/// PRD 6.2 is emphatic that only name and language block progress. District
/// and exam date are offered here because they drive the countdown and study
/// plan, but they are presented as skippable rather than as an incomplete
/// form, and everything is editable later from settings.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _nameError;
  String? _district;
  DateTime? _examDate;
  bool _saving = false;

  static const _districts = [
    'Colombo', 'Gampaha', 'Kalutara', 'Kandy', 'Matale', 'Nuwara Eliya',
    'Galle', 'Matara', 'Hambantota', 'Jaffna', 'Kilinochchi', 'Mannar',
    'Vavuniya', 'Mullaitivu', 'Batticaloa', 'Ampara', 'Trincomalee',
    'Kurunegala', 'Puttalam', 'Anuradhapura', 'Polonnaruwa', 'Badulla',
    'Monaragala', 'Ratnapura', 'Kegalle',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _nameError = l10n.errorEnterName);
      return;
    }

    setState(() {
      _nameError = null;
      _saving = true;
    });

    try {
      final profile = await ref.read(authRepositoryProvider).createProfile(
            fullName: name,
            language: ref.read(languageProvider),
            district: _district,
            targetExamDate: _examDate,
          );
      if (!mounted) return;
      ref.read(profileProvider.notifier).set(profile);
      context.go(Routes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _nameError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final language = ref.watch(languageProvider);

    return AuthScaffold(
      title: l10n.authSignupTitle,
      subtitle: l10n.authSignupSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiqField(
            label: l10n.fieldUserName,
            hint: l10n.fieldUserNameHint,
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          SizedBox(height: AppSpacing.xl.dp(context)),
          Text(
            l10n.settingsLanguage,
            style: context.text(
              AppTextStyles.bodySmall,
              weight: 600,
              color: colors.ink,
            ),
          ),
          SizedBox(height: 7.dp(context)),
          _LanguageRow(
            selected: language,
            onSelected: (value) =>
                ref.read(appSettingsProvider.notifier).setLanguage(value),
          ),
          SizedBox(height: AppSpacing.xl.dp(context)),

          // Everything below is optional. The heading says so, so the screen
          // does not read as a longer form than it is.
          Row(
            children: [
              Expanded(
                child: Divider(color: colors.border, thickness: 1.5),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.dp(context),
                ),
                child: Text(
                  'Optional',
                  style: context.text(
                    AppTextStyles.overline,
                    weight: 700,
                    color: colors.inkFaint,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: colors.border, thickness: 1.5),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          _PickerRow(
            label: 'District',
            value: _district ?? 'Not set',
            onTap: _pickDistrict,
          ),
          SizedBox(height: AppSpacing.sm.dp(context)),
          _PickerRow(
            label: 'Target exam date',
            value: _examDate == null
                ? 'Not set'
                : '${_examDate!.day}/${_examDate!.month}/${_examDate!.year}',
            onTap: _pickExamDate,
          ),
          SizedBox(height: 28.dp(context)),
          SiqButton(
            label: l10n.actionContinue,
            onPressed: _saving ? null : _submit,
            loading: _saving,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.sheet.dp(context)),
        ),
      ),
      builder: (context) => SafeArea(
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _districts.length,
          itemBuilder: (context, index) => ListTile(
            title: Text(
              _districts[index],
              style: context.text(
                AppTextStyles.body,
                color: context.colors.ink,
              ),
            ),
            onTap: () => Navigator.of(context).pop(_districts[index]),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _district = picked);
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.selected, required this.onSelected});

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

    return Row(
      children: [
        for (final language in AppLanguage.values)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: language == AppLanguage.values.last
                    ? 0
                    : 7.dp(context),
              ),
              child: _LanguageChip(
                label: labelFor(language),
                selected: language == selected,
                onTap: () => onSelected(language),
              ),
            ),
          ),
      ],
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(15.dp(context));

    return Material(
      color: colors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14.dp(context),
              vertical: AppSpacing.md.dp(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.text(
                      AppTextStyles.bodySmall,
                      weight: 600,
                      color: colors.ink,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: context.text(
                    AppTextStyles.captionSmall,
                    color: colors.inkMuted,
                  ),
                ),
                SizedBox(width: AppSpacing.xs.dp(context)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18.dp(context),
                  color: colors.inkFaint,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
