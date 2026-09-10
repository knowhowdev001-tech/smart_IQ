import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/settings/app_settings.dart';
import 'package:smart_iq/core/theme/app_scale.dart';
import 'package:smart_iq/core/theme/app_theme.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/features/tutor/presentation/tutor_screen.dart';
import 'package:smart_iq/l10n/generated/app_localizations.dart';

/// The tutor with an actual conversation in it.
///
/// The general screen suite renders every screen at every size, but the
/// tutor always starts empty, so its bubbles and composer were never
/// measured. Chat is the one screen whose content is user-supplied and
/// unbounded in length, which is exactly where width assumptions break.
const _devices = <String, Size>{
  'small phone 320x640': Size(320, 640),
  'Galaxy A-series 360x800': Size(360, 800),
  'Pixel 412x915': Size(412, 915),
  'large phone 480x1040': Size(480, 1040),
  'tablet 800x1280': Size(800, 1280),
};

late SharedPreferences _prefs;

Widget _host(
  Widget child, {
  AppLanguage language = AppLanguage.english,
  MediaQueryData? media,
}) {
  final scoped = ResponsiveScope(child: child);
  final body = media == null ? scoped : MediaQuery(data: media, child: scoped);
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, state) => body)],
  );

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(_prefs)],
    child: MaterialApp.router(
      theme: AppTheme.light(),
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      localizationsDelegates: AppL10n.localizationsDelegates,
      routerConfig: router,
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

/// Sends [text] and waits for the streamed reply to finish arriving.
Future<void> _converse(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  // A single word with no spaces cannot wrap, so it is the honest test of
  // whether the bubble is bounded by something real.
  const unbreakable =
      'antidisestablishmentarianismandthensomemorecharacters1234567890';

  group('a conversation lays out', () {
    for (final device in _devices.entries) {
      testWidgets('on ${device.key}', (tester) async {
        tester.view.physicalSize = device.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_host(const TutorScreen()));
        await _settle(tester);

        await _converse(tester, 'Explain ratio and proportion in detail');
        expect(
          tester.takeException(),
          isNull,
          reason: 'tutor conversation failed to lay out at ${device.value}',
        );
      });
    }
  });

  testWidgets('a bubble never grows wider than the column it sits in',
      (tester) async {
    // A tablet is where this bites: the content column caps at 520dp while
    // a width taken from the screen would allow far more.
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const TutorScreen()));
    await _settle(tester);

    await _converse(tester, unbreakable);

    final column = tester.getSize(find.byType(ContentColumn).first);
    for (final text in find.byType(Text).evaluate()) {
      final size = tester.getSize(find.byWidget(text.widget));
      expect(
        size.width,
        lessThanOrEqualTo(column.width),
        reason: 'a message is wider than the content column',
      );
    }
  });

  testWidgets('an unbreakable message does not overflow the narrowest phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_host(const TutorScreen()));
    await _settle(tester);

    await _converse(tester, unbreakable);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the composer and a conversation survive an enlarged font',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const TutorScreen(),
        media: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(2),
        ),
      ),
    );
    await _settle(tester);

    await _converse(tester, 'Give me a hint for time and work problems');
    expect(tester.takeException(), isNull);
  });

  for (final language in [AppLanguage.sinhala, AppLanguage.tamil]) {
    testWidgets('a conversation lays out in ${language.code}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(const TutorScreen(), language: language));
      await _settle(tester);

      await _converse(tester, 'ප්‍රතිශතය ගැන පැහැදිලි කරන්න');
      expect(tester.takeException(), isNull);
    });
  }
}
