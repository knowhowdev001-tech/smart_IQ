import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/enums.dart';
import '../../domain/models/app_notification.dart';
import '../auth/session_store.dart';
import 'repositories.dart';
import 'supabase_guard.dart';

/// The inbox and push preferences, straight over PostgREST.
///
/// Every table here is the user's own and RLS scopes it (migration 0008), so
/// nothing needs an RPC except token registration, which has to reach across
/// to another user's row (migration 0020).
// ignore_for_file: prefer_initializing_formals

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({
    required SupabaseClient client,
    required SessionStore sessions,
  })  : _client = client,
        _sessions = sessions;

  final SupabaseClient _client;
  final SessionStore _sessions;

  /// The inbox shows recent history, not an archive.
  static const _inboxLimit = 50;

  @override
  Future<List<AppNotification>> inbox() async {
    final rows = await supabaseGuard(
      () => _client
          .from('notifications')
          .select('id, kind, title, body, payload, read_at, created_at')
          .order('created_at', ascending: false)
          .limit(_inboxLimit),
    );
    return [
      for (final row in rows)
        AppNotification(
          id: row['id'] as String,
          kind: NotificationKind.fromKey(row['kind'] as String?),
          title: row['title'] as String? ?? '',
          body: row['body'] as String? ?? '',
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          unread: row['read_at'] == null,
          route: (row['payload'] as Map?)?['route'] as String?,
        ),
    ];
  }

  @override
  Future<void> markAllRead() => supabaseGuard(
        () => _client
            .from('notifications')
            .update({'read_at': _now()})
            .isFilter('read_at', null),
      );

  @override
  Future<void> markRead(String id) => supabaseGuard(
        () => _client
            .from('notifications')
            .update({'read_at': _now()})
            .eq('id', id)
            .isFilter('read_at', null),
      );

  @override
  Future<NotificationPreferences> preferences() async {
    final rows = await supabaseGuard(
      () => _client.from('notification_preferences').select('kind, enabled'),
    );
    return NotificationPreferences.fromRows(rows);
  }

  @override
  Future<void> savePreferences(NotificationPreferences prefs) async {
    final userId = _sessions.userId;
    if (userId == null) throw const UnauthenticatedException();

    await supabaseGuard(
      () => _client.from('notification_preferences').upsert(
        [
          for (final kind in NotificationKind.values)
            {
              'user_id': userId,
              'kind': kind.key,
              'enabled': prefs.enabledFor(kind),
            },
        ],
        onConflict: 'user_id,kind',
      ),
    );
  }

  @override
  Future<void> registerDevice(String pushToken, {required String platform}) async {
    await supabaseGuard(
      () async => _client.rpc<void>('register_device_token', params: {
        'p_device_id': await _sessions.deviceId(),
        'p_token': pushToken,
        'p_platform': platform,
      }),
    );
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}
