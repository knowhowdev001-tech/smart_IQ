import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/msisdn.dart';
import '../../../data/repositories/repositories.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_field.dart';
import '../../legal/presentation/terms_sheet.dart';
import '../application/signup_draft.dart';
import 'widgets/auth_scaffold.dart';

/// Name and number for a new account.
///
/// The name is collected here rather than after OTP so the profile step that
/// follows verification has one less field, keeping the gap between OTP and
/// the first question as short as PRD 6.2 asks for.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _nameError;
  String? _phoneError;
  bool _sending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final name = _nameController.text.trim();
    final normalised = Msisdn.normalise(_phoneController.text.trim());

    setState(() {
      _nameError = name.isEmpty ? l10n.errorEnterName : null;
      _phoneError = _phoneController.text.trim().isEmpty
          ? l10n.errorEnterMobile
          : (normalised == null ? l10n.errorInvalidMobile : null);
    });

    if (_nameError != null || _phoneError != null) return;

    setState(() => _sending = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestOtp(normalised!, fullName: name);
      if (!mounted) return;
      // Carried through OTP so profile creation does not ask for it again.
      ref.read(signupNameProvider.notifier).state = name;
      context.push('${Routes.otp}?msisdn=$normalised&signup=1');
    } on SmsDeliveryException {
      if (!mounted) return;
      setState(() => _phoneError = l10n.errorSmsFailed);
    } on AccountExistsException {
      // Against the number field rather than the name, because the number is
      // what is already taken and what they would change to proceed.
      if (!mounted) return;
      setState(() => _phoneError = l10n.errorAccountExists);
    } on OfflineException {
      // Distinguished from the generic failure because the remedy is the
      // user's, not ours. It is also the shape a missing INTERNET permission
      // takes on Android, where nothing reaches the server to explain itself.
      if (!mounted) return;
      setState(() => _phoneError = l10n.errorOffline);
    } catch (_) {
      if (!mounted) return;
      setState(() => _phoneError = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.authSignupTitle,
      subtitle: l10n.authSignupSubtitle,
      onBack: context.canPop() ? context.pop : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiqField(
            label: l10n.fieldUserName,
            hint: l10n.fieldUserNameHint,
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          SizedBox(height: 14.dp(context)),
          SiqField(
            label: l10n.fieldMobileNumber,
            hint: l10n.fieldMobileHint,
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d +\-()]')),
              LengthLimitingTextInputFormatter(15),
            ],
            errorText: _phoneError,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          SizedBox(height: AppSpacing.md.dp(context)),
          Text(
            l10n.authOtpNoteSignup,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          Text.rich(
            TextSpan(
              text: '${l10n.authTermsConsent}\n',
              children: [
                TextSpan(
                  text: l10n.authTermsConsentBold,
                  style: context.text(
                    AppTextStyles.captionSmall,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.sm.dp(context)),
          Center(
            child: SiqButton(
              label: l10n.authReadTerms,
              variant: SiqButtonVariant.secondary,
              expand: false,
              compact: true,
              onPressed: () => showTermsSheet(context),
            ),
          ),
          SizedBox(height: AppSpacing.xl.dp(context)),
          SiqButton(
            label: l10n.authSignupAction,
            onPressed: _sending ? null : _submit,
            loading: _sending,
          ),
          SizedBox(height: 28.dp(context)),
          AuthSwitchRow(
            prompt: l10n.authHasAccount,
            action: l10n.landingLogIn,
            onTap: () => context.pushReplacement(Routes.login),
          ),
        ],
      ),
    );
  }
}
