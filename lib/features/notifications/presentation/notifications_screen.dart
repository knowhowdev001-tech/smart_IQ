import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_scale.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/siq_states.dart';
import '../../../core/widgets/siq_surfaces.dart';
import '../../../domain/enums.dart';
import '../../../domain/models/app_notification.dart';

/// The notification inbox.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final l10n = context.l10n;
    final inbox = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: colors.page,
      body: Column(
        children: [
          BrandAppBar(
            title: l10n.notificationsTitle,
            onBack: context.pop,
            trailing: TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllRead(),
              child: Text(
                l10n.notificationsMarkAllRead,
                style: context.text(
                  AppTextStyles.captionSmall,
                  weight: 700,
                  color: colors.brandInk,
                ),
              ),
            ),
          ),
          Expanded(
            child: inbox.when(
              loading: () => const SiqLoader(),
              error: (_, __) => SiqMessageState.offline(
                context,
                onRetry: () => ref.read(notificationsProvider.notifier).load(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return SiqMessageState(
                    title: l10n.notificationsEmpty,
                    icon: Icons.notifications_none_rounded,
                  );
                }
                return ContentColumn(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg.dp(context),
                      14.dp(context),
                      AppSpacing.lg.dp(context),
                      AppSpacing.gutter.dp(context),
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: AppSpacing.sm.dp(context)),
                    itemBuilder: (context, index) => _NotificationTile(
                      notification: items[index],
                      onTap: () {
                        ref
                            .read(notificationsProvider.notifier)
                            .markRead(items[index].id);
                        final route = items[index].route;
                        if (route != null) context.push(route);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final unread = notification.unread;

    // A failed charge is the one notification that changes what the user can
    // do, so it carries the danger tint rather than the neutral one.
    final isBilling = notification.kind == NotificationKind.chargeFailed ||
        notification.kind == NotificationKind.renewal;

    final (icon, iconBackground, iconInk) = isBilling
        ? (
            Icons.credit_card_off_rounded,
            colors.dangerSurface,
            colors.dangerInk,
          )
        : (
            switch (notification.kind) {
              NotificationKind.dailyChallenge => Icons.bolt_rounded,
              NotificationKind.streak => Icons.local_fire_department_rounded,
              NotificationKind.digest => Icons.newspaper_rounded,
              _ => Icons.notifications_none_rounded,
            },
            colors.accentSoft,
            colors.accentSoftInk,
          );

    return SiqCard(
      onTap: onTap,
      background: unread ? colors.surfaceMuted : colors.surface,
      borderColor: unread ? colors.borderStrong : colors.border,
      radius: AppRadii.md,
      padding: EdgeInsets.symmetric(
        horizontal: 14.dp(context),
        vertical: 13.dp(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30.dp(context),
            height: 30.dp(context),
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(10.dp(context)),
            ),
            child: Icon(icon, size: 15.dp(context), color: iconInk),
          ),
          SizedBox(width: 11.dp(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: context.text(
                    AppTextStyles.bodySmall,
                    weight: 700,
                    color: colors.ink,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs.dp(context)),
                Text(
                  notification.body,
                  style: context.text(
                    AppTextStyles.caption,
                    color: colors.inkMuted,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs.dp(context)),
                Text(
                  _relativeTime(context, notification.createdAt),
                  style: context.text(
                    AppTextStyles.overline,
                    weight: 600,
                    color: colors.inkFaint,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (unread) ...[
            SizedBox(width: AppSpacing.sm.dp(context)),
            Container(
              width: 8.dp(context),
              height: 8.dp(context),
              margin: EdgeInsets.only(top: 4.dp(context)),
              decoration: BoxDecoration(
                color: colors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _relativeTime(BuildContext context, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}
