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
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_field.dart';
import 'widgets/auth_scaffold.dart';

/// Phone-number entry for an existing account.
///
/// Phone and OTP only. PRD 6.1 rules out social authentication entirely, now
/// and later.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final raw = _controller.text.trim();

    if (raw.isEmpty) {
      setState(() => _error = l10n.errorEnterMobile);
      return;
    }
    final normalised = Msisdn.normalise(raw);
    if (normalised == null) {
      setState(() => _error = l10n.errorInvalidMobile);
      return;
    }

    setState(() {
      _error = null;
      _sending = true;
    });

    try {
      await ref.read(authRepositoryProvider).requestOtp(normalised);
      if (!mounted) return;
      context.push('${Routes.otp}?msisdn=$normalised');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return AuthScaffold(
      title: l10n.authLoginTitle,
      subtitle: l10n.authLoginSubtitle,
      onBack: context.canPop() ? context.pop : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiqField(
            label: l10n.fieldMobileNumber,
            hint: l10n.fieldMobileHint,
            controller: _controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d +\-()]')),
              LengthLimitingTextInputFormatter(15),
            ],
            onSubmitted: (_) => _send(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            errorText: _error,
          ),
          SizedBox(height: AppSpacing.md.dp(context)),
          Text(
            l10n.authOtpNoteLogin,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.xl.dp(context)),
          SiqButton(
            label: l10n.authSendOtp,
            onPressed: _sending ? null : _send,
            loading: _sending,
          ),
          SizedBox(height: 28.dp(context)),
          AuthSwitchRow(
            prompt: l10n.authNoAccount,
            action: l10n.authSignupAction,
            onTap: () => context.pushReplacement(Routes.signup),
          ),
        ],
      ),
    );
  }
}
