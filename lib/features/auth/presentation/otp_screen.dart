import 'dart:async';

import 'package:flutter/material.dart';
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
import '../../../data/mock/mock_repositories.dart';
import '../../../domain/otp_policy.dart';
import 'widgets/auth_scaffold.dart';

/// OTP entry, with the expiry countdown and resend cooldown from PRD 6.1.
///
/// Two separate clocks run here and they are not the same thing: the code
/// expires after five minutes, while resend unlocks after sixty seconds. The
/// cooldown exists because each SMS is a direct cost, not merely a security
/// control.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.msisdn, this.isSignup = false, super.key});

  final String msisdn;
  final bool isSignup;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  static const _expiry = kOtpValidity;
  static const _resendCooldown = kOtpResendCooldown;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _timer;
  int _secondsToExpiry = _expiry.inSeconds;
  int _secondsToResend = _resendCooldown.inSeconds;
  String? _error;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _startClocks();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startClocks() {
    _timer?.cancel();
    setState(() {
      _secondsToExpiry = _expiry.inSeconds;
      _secondsToResend = _resendCooldown.inSeconds;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_secondsToExpiry > 0) _secondsToExpiry--;
        if (_secondsToResend > 0) _secondsToResend--;
      });
      if (_secondsToExpiry == 0) _timer?.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.msisdn);
      _controller.clear();
      _startClocks();
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.errorGeneric);
    }
  }

  Future<void> _verify() async {
    final l10n = context.l10n;
    if (_controller.text.length != 6) return;

    setState(() {
      _verifying = true;
      _error = null;
    });

    try {
      final profile = await ref.read(authRepositoryProvider).verifyOtp(
            msisdn: widget.msisdn,
            code: _controller.text,
          );
      if (!mounted) return;

      // A verified user without a profile cannot reach the app until they
      // create one (PRD 6.1, step 5).
      if (profile == null || widget.isSignup) {
        context.go(Routes.profileSetup);
      } else {
        ref.read(profileProvider.notifier).set(profile);
        context.go(Routes.home);
      }
    } on OtpInvalidException {
      if (mounted) setState(() => _error = l10n.otpErrorInvalid);
    } on OtpExpiredException {
      if (mounted) setState(() => _error = l10n.otpErrorExpired);
    } catch (_) {
      if (mounted) setState(() => _error = l10n.errorGeneric);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  String get _expiryLabel {
    final minutes = _secondsToExpiry ~/ 60;
    final seconds = _secondsToExpiry % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final expired = _secondsToExpiry == 0;

    return AuthScaffold(
      title: l10n.authOtpTitle,
      subtitle: l10n.authOtpSubtitle,
      onBack: context.canPop() ? context.pop : null,
      child: Column(
        children: [
          Text(
            l10n.otpEnterTitle,
            style: context.text(
              AppTextStyles.body,
              weight: 700,
              color: colors.ink,
            ),
          ),
          SizedBox(height: AppSpacing.sm.dp(context)),
          Text(
            l10n.otpSentTo(Msisdn.format(widget.msisdn)),
            style: context.text(
              AppTextStyles.caption,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          OtpInput(
            controller: _controller,
            focusNode: _focusNode,
            onCompleted: (_) => _verify(),
          ),
          SizedBox(height: AppSpacing.md.dp(context)),
          Text(
            l10n.otpHelp,
            textAlign: TextAlign.center,
            style: context.text(
              AppTextStyles.captionSmall,
              color: colors.inkMuted,
            ),
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          _ExpiryChip(label: expired ? l10n.otpExpired : _expiryLabel,
              expired: expired),
          if (_error != null) ...[
            SizedBox(height: AppSpacing.md.dp(context)),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: context.text(
                AppTextStyles.caption,
                weight: 600,
                color: colors.dangerInk,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.xl.dp(context)),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) => SiqButton(
              label: l10n.otpVerify,
              loading: _verifying,
              onPressed: value.text.length == 6 && !expired && !_verifying
                  ? _verify
                  : null,
            ),
          ),
          SizedBox(height: AppSpacing.lg.dp(context)),
          if (_secondsToResend > 0)
            Text(
              l10n.otpResendIn(_secondsToResend),
              style: context.text(
                AppTextStyles.caption,
                color: colors.inkMuted,
              ),
            )
          else
            SiqButton(
              label: l10n.otpResend,
              variant: SiqButtonVariant.secondary,
              expand: false,
              compact: true,
              onPressed: _resend,
            ),
        ],
      ),
    );
  }
}

class _ExpiryChip extends StatelessWidget {
  const _ExpiryChip({required this.label, required this.expired});

  final String label;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = expired ? colors.dangerInk : colors.accentSoftInk;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: 7.dp(context),
      ),
      decoration: BoxDecoration(
        color: expired ? colors.dangerSurface : colors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadii.md.dp(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 13.dp(context), color: tint),
          SizedBox(width: AppSpacing.xs.dp(context)),
          Text(
            label,
            style: context.text(
              AppTextStyles.bodySmall,
              weight: 700,
              color: tint,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
