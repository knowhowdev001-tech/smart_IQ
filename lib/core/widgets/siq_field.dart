import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// A labelled text field on the pale green fill from the design.
class SiqField extends StatelessWidget {
  const SiqField({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(AppRadii.md.dp(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.text(
            AppTextStyles.bodySmall,
            weight: 600,
            color: colors.ink,
          ),
        ),
        SizedBox(height: 7.dp(context)),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofillHints: autofillHints,
          style: context.text(
            AppTextStyles.body,
            weight: 600,
            color: colors.ink,
          ),
          cursorColor: colors.accent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.text(
              AppTextStyles.body,
              color: colors.inkMuted,
            ),
            filled: true,
            fillColor: colors.field,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.dp(context),
              vertical: 14.dp(context),
            ),
            border: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: colors.accent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: colors.danger, width: 1.5),
            ),
          ),
        ),
        if (errorText != null) ...[
          SizedBox(height: AppSpacing.xs.dp(context)),
          Text(
            errorText!,
            style: context.text(
              AppTextStyles.caption,
              weight: 600,
              color: colors.dangerInk,
            ),
          ),
        ],
      ],
    );
  }
}

/// The six circular OTP boxes with a single hidden field behind them.
///
/// One real input drives all six circles. That is what lets Android's SMS
/// autofill deliver the whole code at once, which a six-field arrangement
/// tends to break.
class OtpInput extends StatelessWidget {
  const OtpInput({
    required this.controller,
    required this.focusNode,
    this.length = 6,
    this.onCompleted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String>? onCompleted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'One time code, $length digits',
      child: Stack(
        alignment: Alignment.center,
        children: [
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final digits = value.text;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < length; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 4.5.dp(context),
                      ),
                      child: _OtpCircle(
                        value: i < digits.length ? digits[i] : '',
                        active: i == digits.length,
                      ),
                    ),
                ],
              );
            },
          ),
          Positioned.fill(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              maxLength: length,
              autofocus: true,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                if (value.length == length) onCompleted?.call(value);
              },
              showCursor: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 16),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpCircle extends StatelessWidget {
  const _OtpCircle({required this.value, required this.active});

  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = value.isNotEmpty;
    final size = 38.dp(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.accentSoft : colors.surface,
        border: Border.all(
          color: active
              ? colors.accent
              : (filled ? colors.accent : colors.borderStrong),
          width: 1.5,
        ),
      ),
      child: Text(
        value,
        style: context.text(
          AppTextStyles.body,
          weight: 700,
          color: colors.accentSoftInk,
        ),
      ),
    );
  }
}
