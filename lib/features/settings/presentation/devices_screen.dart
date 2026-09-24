import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/relative_time.dart';
import '../../../core/widgets/siq_button.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/models/user_profile.dart';

/// Every device signed in to the account, with a way to sign the others out
/// (PRD 6.1).
///
/// Signing out revokes that device's refresh token. Its current access token
/// still works until it expires, so it loses access within the hour, not
/// instantly - the intro says so rather than promising more.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final sessions = ref.watch(activeSessionsProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(title: l10n.settingsDevices, onBack: context.pop),
          Expanded(
            child: sessions.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () => ref.invalidate(activeSessionsProvider),
              ),
              data: (list) => _DeviceList(sessions: list),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends ConsumerStatefulWidget {
  const _DeviceList({required this.sessions});

  final List<DeviceSession> sessions;

  @override
  ConsumerState<_DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends ConsumerState<_DeviceList> {
  /// Sessions being signed out right now, so their buttons spin and a
  /// second tap cannot send a second request.
  final Set<String> _busy = {};

  List<DeviceSession> get _others => [
    for (final s in widget.sessions)
      if (!s.isCurrent) s,
  ];

  Future<void> _signOut(List<DeviceSession> targets, String title) async {
    final l10n = context.l10n;
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          title,
          style: context.text(
            AppTextStyles.titleSmall,
            weight: 700,
            color: colors.ink,
          ),
        ),
        content: Text(
          l10n.devicesConfirmBody,
          style: context.text(AppTextStyles.bodySmall, color: colors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.settingsSignOut,
              style: TextStyle(color: colors.dangerInk),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy.addAll(targets.map((s) => s.id)));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final auth = ref.read(authRepositoryProvider);
      for (final session in targets) {
        await auth.revokeSession(session.id);
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.devicesSignedOut)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    } finally {
      // Re-read either way: after a partial failure the list should show
      // what actually happened, not what was attempted.
      if (mounted) setState(() => _busy.clear());
      ref.invalidate(activeSessionsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final others = _others;
    // The current device first, then the rest as the server ordered them
    // (most recently active first).
    final ordered = [
      for (final s in widget.sessions)
        if (s.isCurrent) s,
      ...others,
    ];

    return RefreshIndicator(
      color: colors.accent,
      onRefresh: () => ref.refresh(activeSessionsProvider.future),
      child: ContentColumn(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter.dp(context),
            AppSpacing.lg.dp(context),
            AppSpacing.gutter.dp(context),
            context.safeBottom(AppSpacing.gutter),
          ),
          children: [
            Text(
              l10n.devicesIntro,
              style: context.text(
                AppTextStyles.captionSmall,
                color: colors.inkMuted,
              ),
            ),
            SizedBox(height: AppSpacing.lg.dp(context)),
            for (final session in ordered) ...[
              _DeviceRow(
                session: session,
                busy: _busy.contains(session.id),
                onSignOut: session.isCurrent
                    ? null
                    : () => _signOut([
                        session,
                      ], l10n.devicesConfirmTitle(session.deviceName)),
              ),
              SizedBox(height: AppSpacing.sm.dp(context)),
            ],
            SizedBox(height: AppSpacing.md.dp(context)),
            if (others.isEmpty)
              Text(
                l10n.devicesOnlyThis,
                textAlign: TextAlign.center,
                style: context.text(
                  AppTextStyles.caption,
                  color: colors.inkMuted,
                ),
              )
            else if (others.length > 1)
              SiqButton(
                label: l10n.devicesSignOutOthers,
                variant: SiqButtonVariant.secondary,
                loading: _busy.isNotEmpty,
                onPressed: _busy.isNotEmpty
                    ? null
                    : () => _signOut(others, l10n.devicesConfirmAllTitle),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.session,
    required this.busy,
    required this.onSignOut,
  });

  final DeviceSession session;
  final bool busy;

  /// Null for this device: signing yourself out lives in Settings, where it
  /// also clears the local session.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;

    return SiqCard(
      radius: 15,
      borderColor: session.isCurrent ? colors.accent : null,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: AppSpacing.md.dp(context),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smartphone_rounded,
            size: 22.dp(context),
            color: session.isCurrent ? colors.accent : colors.inkMuted,
          ),
          SizedBox(width: AppSpacing.md.dp(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: 2.dp(context)),
                Text(
                  session.isCurrent
                      ? l10n.devicesThisDevice
                      : l10n.devicesLastActive(
                          relativeTime(l10n, session.lastSeenAt.toLocal()),
                        ),
                  style: context.text(
                    AppTextStyles.captionSmall,
                    weight: session.isCurrent ? 700 : 400,
                    color: session.isCurrent
                        ? colors.accentSoftInk
                        : colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onSignOut != null)
            SiqButton(
              label: l10n.settingsSignOut,
              variant: SiqButtonVariant.chip,
              expand: false,
              loading: busy,
              onPressed: busy ? null : onSignOut,
            ),
        ],
      ),
    );
  }
}
