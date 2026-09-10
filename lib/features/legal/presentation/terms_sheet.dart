import 'package:flutter/material.dart';

import '../../../app.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_button.dart';

/// One clause of the terms.
class _Clause {
  const _Clause(this.heading, this.body);

  final String heading;
  final String body;
}

/// The terms dialog from the design.
///
/// The billing clauses restate PRD 7.2 and 12 in user-facing terms:
/// charging starts on day one with no trial, and a failed charge drops to
/// Free Fallback immediately with no grace period. Those are commitments the
/// user is agreeing to, so they are stated plainly rather than buried.
Future<void> showTermsSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (context) => const _TermsDialog(),
  );
}

class _TermsDialog extends StatelessWidget {
  const _TermsDialog();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    // English source text. These are commercial terms and must be reviewed
    // and translated by the legal and content teams before release rather
    // than localised in the app's own string files.
    const clauses = [
      _Clause(
        'Subscription and charging',
        'Basic is billed daily through your mobile operator. Pro and Pro+ '
            'are billed monthly through the app store. Charging begins on '
            'the first day of your subscription. There is no free trial.',
      ),
      _Clause(
        'Failed charges',
        'If a charge fails, your account moves to Free Fallback limits '
            'immediately. There is no grace period. The daily cycle retries '
            'the next day, and a successful charge restores your tier at the '
            'next status check.',
      ),
      _Clause(
        'Cancellation',
        'You can stop a daily telco subscription at any time through your '
            'operator. Monthly subscriptions are managed in your app store '
            'account. Charges already taken are not refunded.',
      ),
      _Clause(
        'Your account',
        'Your mobile number identifies your account and is the number used '
            'for telco charging. You may view your signed-in devices and '
            'sign out of others at any time.',
      ),
      _Clause(
        'Your data',
        'Your practice history and progress are private to you. Nothing in '
            'Smart IQ compares you to another user, and no other user can '
            'see your profile or results. You may export your data or delete '
            'your account from Settings.',
      ),
      _Clause(
        'Content and AI answers',
        'Questions and explanations are provided for exam preparation and '
            'are not guaranteed to match any specific examination syllabus. '
            'AI tutor responses are generated automatically and may contain '
            'errors, so check them against the written explanation.',
      ),
      _Clause(
        'Connection required',
        'Smart IQ needs an active internet connection. There is no offline '
            'practice mode and questions are not stored on your device.',
      ),
    ];

    return Dialog(
      insetPadding: EdgeInsets.all(AppSpacing.xl.dp(context)),
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl.dp(context)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl.dp(context),
                AppSpacing.lg.dp(context),
                AppSpacing.md.dp(context),
                14.dp(context),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.termsTitle,
                          style: context.text(
                            AppTextStyles.titleSmall,
                            weight: 700,
                            color: colors.ink,
                          ),
                        ),
                        SizedBox(height: AppSpacing.xxs.dp(context)),
                        Text(
                          l10n.termsUpdated('1 September 2026'),
                          style: context.text(
                            AppTextStyles.captionSmall,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: Navigator.of(context).pop,
                    icon: Icon(Icons.close_rounded, size: 20.dp(context)),
                    color: colors.ink,
                    tooltip: l10n.actionClose,
                  ),
                ],
              ),
            ),
            Divider(color: colors.divider, height: 1),
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.all(AppSpacing.xl.dp(context)),
                itemCount: clauses.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: 14.dp(context)),
                itemBuilder: (context, index) {
                  final clause = clauses[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clause.heading,
                        style: context.text(
                          AppTextStyles.caption,
                          weight: 700,
                          color: colors.ink,
                        ),
                      ),
                      SizedBox(height: 5.dp(context)),
                      Text(
                        clause.body,
                        style: context.text(
                          AppTextStyles.caption,
                          color: colors.inkMuted,
                          height: 1.6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Divider(color: colors.divider, height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl.dp(context),
                14.dp(context),
                AppSpacing.xl.dp(context),
                AppSpacing.lg.dp(context),
              ),
              child: SiqButton(
                label: l10n.actionClose,
                compact: true,
                onPressed: Navigator.of(context).pop,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
