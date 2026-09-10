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
import '../application/signup_draft.dart';
import 'widgets/auth_scaffold.dart';

/// Profile creation, sitting between OTP and the first question.
///
/// PRD 6.2 says only name and language block progress, and warns that every
/// extra field here is a drop-off risk. By this point the app already has
/// both: the name came from the signup screen and the language was chosen on
/// the landing screen. So neither is asked for again, and what remains —
/// district and target exam date — is genuinely optional and skippable.
///
/// The name field reappears in one case only: a first-time number entered on
/// the login screen never passed through signup, so there is no name to
/// carry and it still has to be asked for.
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

  /// Creates the profile and enters the app.
  ///
  /// [skipOptional] drops district and exam date regardless of what was
  /// entered, which is what the skip action means.
  Future<void> _save({bool skipOptional = false}) async {
    final l10n = context.l10n;
    final carriedName = ref.read(signupNameProvider);
    final name = carriedName ?? _nameController.text.trim();

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
            // Chosen on the landing screen and already persisted.
            language: ref.read(languageProvider),
            district: skipOptional ? null : _district,
            targetExamDate: skipOptional ? null : _examDate,
          );
      if (!mounted) return;

      ref.read(profileProvider.notifier).set(profile);
      // The draft has done its job; leaving it set would let a later signup
      // inherit this name.
      ref.read(signupNameProvider.notifier).state = null;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    // Set when the user came through signup, which is the usual path.
    final carriedName = ref.watch(signupNameProvider);
    final needsName = carriedName == null;

    return AuthScaffold(
      title: l10n.profileSetupTitle,
      subtitle: l10n.profileSetupSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (needsName) ...[
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
          ],

          _OptionalDivider(label: l10n.labelOptional),
          SizedBox(height: AppSpacing.lg.dp(context)),

          _PickerRow(
            label: l10n.fieldDistrict,
            value: _district ?? l10n.statNoExamDate,
            onTap: _pickDistrict,
          ),
          SizedBox(height: AppSpacing.sm.dp(context)),
          _PickerRow(
            label: l10n.fieldTargetExamDate,
            value: _examDate == null
                ? l10n.statNoExamDate
                : MaterialLocalizations.of(context).formatMediumDate(_examDate!),
            onTap: _pickExamDate,
          ),

          SizedBox(height: AppSpacing.md.dp(context)),
          Text(
            l10n.profileSetupOptionalNote,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),

          SizedBox(height: 28.dp(context)),
          SiqButton(
            label: l10n.actionContinue,
            onPressed: _saving ? null : _save,
            loading: _saving,
          ),
          SizedBox(height: AppSpacing.md.dp(context)),
          Center(
            child: SiqButton(
              label: l10n.actionSkip,
              variant: SiqButtonVariant.secondary,
              expand: false,
              compact: true,
              onPressed: _saving ? null : () => _save(skipOptional: true),
            ),
          ),
          // An error on the name has nowhere to appear once the field is
          // hidden, so it is repeated here for the carried-name path.
          if (!needsName && _nameError != null) ...[
            SizedBox(height: AppSpacing.md.dp(context)),
            Text(
              _nameError!,
              textAlign: TextAlign.center,
              style: context.text(
                AppTextStyles.caption,
                weight: 600,
                color: colors.dangerInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionalDivider extends StatelessWidget {
  const _OptionalDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(child: Divider(color: colors.border, thickness: 1.5)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.dp(context)),
          child: Text(
            label.toUpperCase(),
            style: context.text(
              AppTextStyles.overline,
              weight: 700,
              color: colors.inkFaint,
            ),
          ),
        ),
        Expanded(child: Divider(color: colors.border, thickness: 1.5)),
      ],
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
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text(
                      AppTextStyles.captionSmall,
                      color: colors.inkMuted,
                    ),
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
