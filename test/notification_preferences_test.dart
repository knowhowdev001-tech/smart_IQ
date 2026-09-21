import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/providers/app_providers.dart';
import 'package:smart_iq/core/settings/app_settings.dart';
import 'package:smart_iq/core/theme/app_scale.dart';
import 'package:smart_iq/core/theme/app_theme.dart';
import 'package:smart_iq/data/mock/mock_repositories.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/app_notification.dart';
import 'package:smart_iq/features/settings/presentation/settings_screen.dart';
import 'package:smart_iq/l10n/generated/app_localizations.dart';

void main() {
  group('NotificationPreferences', () {
    test('every kind has its own switch', () {
      // PRD 6.8: individually toggleable. Charge-failed and renewal used to
      // share one switch, so turning one off silenced the other.
      for (final kind in NotificationKind.values) {
        final prefs = _off(kind);
        for (final other in NotificationKind.values) {
          expect(prefs.enabledFor(other), other != kind,
              reason: 'turning off $kind changed $other');
        }
      }
    });

    test('reads database rows, treating a missing kind as on', () {
      final prefs = NotificationPreferences.fromRows([
        {'kind': 'charge_failed', 'enabled': false},
        {'kind': 'streak', 'enabled': true},
      ]);

      expect(prefs.chargeFailed, isFalse);
      expect(prefs.renewal, isTrue);
      expect(prefs.streak, isTrue);
      expect(prefs.inactivity, isTrue);
    });

    test('kind keys match the database enum', () {
      for (final kind in NotificationKind.values) {
        expect(NotificationKind.fromKey(kind.key), kind);
      }
    });
  });

  testWidgets('settings saves charge-failed without touching renewal',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final backend = MockBackendState();

    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          mockBackendProvider.overrideWithValue(backend),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
          localizationsDelegates: AppL10n.localizationsDelegates,
          routerConfig: GoRouter(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const ResponsiveScope(child: SettingsScreen()),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppL10n(const Locale('en'));
    final chargeFailed = find.widgetWithText(
      SwitchListTile,
      l10n.notificationPrefChargeFailed,
    );
    await tester.scrollUntilVisible(chargeFailed, 200,
        scrollable: find.byType(Scrollable).first);

    expect(find.byType(SwitchListTile, skipOffstage: false), findsNWidgets(6));

    await tester.tap(chargeFailed);
    await tester.pumpAndSettle();

    expect(backend.notifyPrefs.chargeFailed, isFalse);
    expect(backend.notifyPrefs.renewal, isTrue);
  });
}

NotificationPreferences _off(NotificationKind kind) {
  const on = NotificationPreferences();
  return switch (kind) {
    NotificationKind.dailyChallenge => on.copyWith(dailyChallenge: false),
    NotificationKind.streak => on.copyWith(streak: false),
    NotificationKind.digest => on.copyWith(digest: false),
    NotificationKind.chargeFailed => on.copyWith(chargeFailed: false),
    NotificationKind.renewal => on.copyWith(renewal: false),
    NotificationKind.inactivity => on.copyWith(inactivity: false),
  };
}
