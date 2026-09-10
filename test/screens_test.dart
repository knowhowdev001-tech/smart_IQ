import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/settings/app_settings.dart';
import 'package:smart_iq/core/theme/app_scale.dart';
import 'package:smart_iq/core/theme/app_theme.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/features/auth/presentation/landing_screen.dart';
import 'package:smart_iq/features/auth/presentation/login_screen.dart';
import 'package:smart_iq/features/auth/presentation/otp_screen.dart';
import 'package:smart_iq/features/auth/presentation/signup_screen.dart';
import 'package:smart_iq/features/home/presentation/home_screen.dart';
import 'package:smart_iq/features/notifications/presentation/notifications_screen.dart';
import 'package:smart_iq/features/practice/presentation/practice_hub_screen.dart';
import 'package:smart_iq/features/practice/presentation/practice_screen.dart';
import 'package:smart_iq/features/profile/presentation/profile_screen.dart';
import 'package:smart_iq/features/settings/presentation/settings_screen.dart';
import 'package:smart_iq/features/tutor/presentation/tutor_screen.dart';
import 'package:smart_iq/l10n/generated/app_localizations.dart';

/// The Android screen sizes the app has to survive, in logical pixels.
///
/// These are real devices, not round numbers: the smallest budget phones
/// still in service, the mainstream band, a large phone, and a tablet.
const _devices = <String, Size>{
  'small phone 320x640': Size(320, 640),
  'Galaxy A-series 360x800': Size(360, 800),
  'Pixel 412x915': Size(412, 915),
  'large phone 480x1040': Size(480, 1040),
  'tablet 800x1280': Size(800, 1280),
};

/// The settings provider reads preferences synchronously so the first frame
/// is already themed, which means tests must supply a real instance rather
/// than letting it resolve lazily.
late SharedPreferences _prefs;

Widget _host(
  Widget child, {
  AppLanguage language = AppLanguage.english,
  ThemeData? theme,
  MediaQueryData? media,
}) {
  final scoped = ResponsiveScope(child: child);
  final body = media == null ? scoped : MediaQuery(data: media, child: scoped);

  // Screens ask go_router whether they can pop, so they need a real router
  // above them. A plain MaterialApp would fail on that rather than on
  // anything to do with layout, which is what this suite is measuring.
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => body),
    ],
  );

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light(),
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      localizationsDelegates: AppL10n.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget widget,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);

  // The mock repositories answer on a delay, so a bare pump would only ever
  // assert the loading state. Pumping past the longest mock latency is what
  // puts real content on screen.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  final screens = <String, Widget Function()>{
    'landing': LandingScreen.new,
    'login': LoginScreen.new,
    'signup': SignupScreen.new,
    'otp': () => const OtpScreen(msisdn: '0771234821'),
    'home': HomeScreen.new,
    'practice hub': PracticeHubScreen.new,
    'practice category': () => const PracticeScreen(categoryKey: 'iq'),
    'tutor': TutorScreen.new,
    'profile': ProfileScreen.new,
    'settings': SettingsScreen.new,
    'notifications': NotificationsScreen.new,
  };

  group('every screen lays out on every Android size', () {
    for (final device in _devices.entries) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} on ${device.key}', (tester) async {
          await _pumpAt(tester, device.value, _host(screen.value()));

          // A RenderFlex overflow is reported as a Flutter error rather than
          // a thrown exception, so it surfaces through takeException.
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.key} failed to lay out at ${device.value}',
          );
        });
      }
    }
  });

  group('screens render in Sinhala and Tamil', () {
    // Both scripts run considerably longer than English for the same string,
    // which is exactly where a fixed-height row or an unwrapped Row starts
    // to overflow. The narrowest device is the honest test.
    for (final language in [AppLanguage.sinhala, AppLanguage.tamil]) {
      for (final name in ['landing', 'home', 'practice category', 'settings']) {
        testWidgets('$name in ${language.code}', (tester) async {
          await _pumpAt(
            tester,
            const Size(320, 640),
            _host(screens[name]!(), language: language),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('screens survive an enlarged system font', () {
    // Android lets the user push font size well past the default. The scope
    // clamps it to 1.3, but the layouts still have to absorb what is left.
    for (final name in ['home', 'profile', 'settings', 'practice category']) {
      testWidgets('$name at 2.0x requested text scale', (tester) async {
        await _pumpAt(
          tester,
          const Size(360, 800),
          _host(
            screens[name]!(),
            media: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(2),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('dark theme', () {
    // PRD 6.9 requires both themes verified across every screen, including
    // the error, empty and loading states these pumps pass through.
    for (final name in ['home', 'settings', 'notifications', 'tutor']) {
      testWidgets('$name renders in dark mode', (tester) async {
        await _pumpAt(
          tester,
          const Size(360, 800),
          _host(screens[name]!(), theme: AppTheme.dark()),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
