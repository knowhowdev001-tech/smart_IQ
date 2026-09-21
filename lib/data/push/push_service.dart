import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/settings/app_settings.dart';
import '../../domain/enums.dart';
import '../../l10n/generated/app_localizations.dart';
import '../repositories/repositories.dart';

/// FCM on the device side (PRD 6.8): permission, token registration, and
/// what happens when a push arrives or is tapped.
///
/// What to send and when is decided entirely on the server (migration 0020
/// and the `push-dispatch` Edge Function). The app only has to hand over a
/// token and follow the `route` a push carries.
// Named parameters cannot be private field formals, so the analyzer's
// suggestion to use `this._repository` does not compile here.
// ignore_for_file: prefer_initializing_formals

class PushService {
  PushService({
    required NotificationRepository repository,
    required GoRouter router,
    required VoidCallback onInboxChanged,
  })  : _repository = repository,
        _router = router,
        _onInboxChanged = onInboxChanged;

  final NotificationRepository _repository;
  final GoRouter _router;
  final VoidCallback _onInboxChanged;

  final _local = FlutterLocalNotificationsPlugin();
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _listening = false;

  /// Called on every sign-in, including a cold start that restores one.
  ///
  /// Registration repeats each time because the token has to move to
  /// whichever account is signed in on this phone now; the listeners are
  /// attached once.
  Future<void> onSignedIn(AppL10n l10n) async {
    try {
      if (!_listening) {
        _listening = true;
        await _attach(l10n);
      }

      final messaging = FirebaseMessaging.instance;
      // On Android 13+ this is the POST_NOTIFICATIONS prompt. Asked after
      // sign-in rather than on first launch, when the user has a reason to
      // say yes.
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token != null) await _register(token);
    } catch (error) {
      // Push is an enhancement. A missing APNs setup or a flaky network must
      // never break sign-in, and the next launch tries again.
      debugPrint('push setup failed: $error');
    }
  }

  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
  }

  Future<void> _attach(AppL10n l10n) async {
    final messaging = FirebaseMessaging.instance;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_notify'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) _open(jsonDecode(payload) as Map<String, dynamic>);
      },
    );
    await _createChannels(l10n);

    // iOS shows a foreground push itself once asked to; Android does not,
    // which is why onMessage re-posts it locally there.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _subscriptions
      ..add(messaging.onTokenRefresh.listen(_register))
      ..add(FirebaseMessaging.onMessage.listen(_onForeground))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data)));

    // The push that cold-started the app, if one did.
    final initial = await messaging.getInitialMessage();
    if (initial != null) _open(initial.data);
  }

  /// One channel per kind, named after the settings toggle, so a user can
  /// also silence a kind from Android's own notification settings. The ids
  /// are the `notification_kind` values the dispatcher sends on.
  Future<void> _createChannels(AppL10n l10n) async {
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    for (final kind in NotificationKind.values) {
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          kind.key,
          _channelName(kind, l10n),
          importance: Importance.high,
        ),
      );
    }
  }

  String _channelName(NotificationKind kind, AppL10n l10n) => switch (kind) {
        NotificationKind.dailyChallenge => l10n.notificationPrefDaily,
        NotificationKind.streak => l10n.notificationPrefStreak,
        NotificationKind.digest => l10n.notificationPrefDigest,
        NotificationKind.chargeFailed => l10n.notificationPrefChargeFailed,
        NotificationKind.renewal => l10n.notificationPrefRenewal,
        NotificationKind.inactivity => l10n.notificationPrefInactivity,
      };

  Future<void> _register(String token) async {
    try {
      await _repository.registerDevice(
        token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
    } catch (error) {
      debugPrint('push token registration failed: $error');
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    _onInboxChanged();

    final notification = message.notification;
    if (notification == null || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final channel = message.data['kind'] as String? ??
        NotificationKind.dailyChallenge.key;
    await _local.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channel,
          icon: 'ic_stat_notify',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _open(Map<String, dynamic> data) {
    final id = data['notification_id'] as String?;
    if (id != null) {
      unawaited(
        _repository.markRead(id).then((_) => _onInboxChanged(), onError: (_) {}),
      );
    }
    final route = data['route'] as String?;
    _router.go(route != null && route.startsWith('/') ? route : Routes.notifications);
  }
}

/// Null when Firebase was not initialised: mock backend, widget tests, or an
/// init failure at startup.
final pushServiceProvider = Provider<PushService?>((ref) {
  if (!ref.watch(backendReadyProvider) || Firebase.apps.isEmpty) return null;
  // Read, not watched: the settings screen invalidates the repository on
  // every toggle, and rebuilding this would attach a second set of FCM
  // listeners each time. The repository holds no state worth following.
  final service = PushService(
    repository: ref.read(notificationRepositoryProvider),
    router: ref.read(routerProvider),
    onInboxChanged: () => ref.read(notificationsProvider.notifier).load(),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Registers for push whenever a profile appears, which is both a fresh
/// sign-in and a restored session on cold start. Watched from the app root.
final pushBootstrapProvider = Provider<void>((ref) {
  final signedIn = ref.watch(
    profileProvider.select((profile) => profile.valueOrNull != null),
  );
  final push = ref.watch(pushServiceProvider);
  if (!signedIn || push == null) return;

  final language = ref.read(appSettingsProvider).language;
  unawaited(push.onSignedIn(lookupAppL10n(language.locale)));
});
