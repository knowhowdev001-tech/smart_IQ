import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_iq/core/providers/app_providers.dart';
import 'package:smart_iq/core/settings/app_settings.dart';
import 'package:smart_iq/core/theme/app_scale.dart';
import 'package:smart_iq/core/theme/app_theme.dart';
import 'package:smart_iq/domain/enums.dart';
import 'package:smart_iq/domain/models/practice.dart';
import 'package:smart_iq/domain/models/user_profile.dart';
import 'package:smart_iq/features/auth/presentation/landing_screen.dart';
import 'package:smart_iq/features/auth/presentation/login_screen.dart';
import 'package:smart_iq/features/auth/presentation/otp_screen.dart';
import 'package:smart_iq/features/auth/presentation/signup_screen.dart';
import 'package:smart_iq/features/home/presentation/home_screen.dart';
import 'package:smart_iq/features/notifications/presentation/notifications_screen.dart';
import 'package:smart_iq/features/practice/presentation/practice_hub_screen.dart';
import 'package:smart_iq/features/practice/presentation/practice_screen.dart';
import 'package:smart_iq/features/profile/presentation/profile_screen.dart';
import 'package:smart_iq/features/progress/presentation/mastery_screen.dart';
import 'package:smart_iq/features/results/presentation/results_screen.dart';
import 'package:smart_iq/data/mock/mock_repositories.dart';
import 'package:smart_iq/features/settings/presentation/devices_screen.dart';
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
  List<Override> overrides = const [],
}) {
  // Screens ask go_router whether they can pop, so they need a real router
  // above them. A plain MaterialApp would fail on that rather than on
  // anything to do with layout, which is what this suite is measuring.
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => child),
    ],
  );

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(_prefs),
      ...overrides,
    ],
    child: MaterialApp.router(
      theme: theme ?? AppTheme.light(),
      locale: language.locale,
      supportedLocales: const [Locale('en'), Locale('si'), Locale('ta')],
      localizationsDelegates: AppL10n.localizationsDelegates,
      // Above the navigator, exactly as app.dart does it, so that a dialog
      // route inherits the scope too. Wrapping the screen instead would
      // leave dialogs without it and pass a test the app would fail.
      builder: (context, navigator) {
        final scoped = ResponsiveScope(
          child: navigator ?? const SizedBox.shrink(),
        );
        return media == null ? scoped : MediaQuery(data: media, child: scoped);
      },
      routerConfig: router,
    ),
  );
}

/// The status bar and navigation bar of an ordinary Android phone, in
/// logical pixels.
///
/// The app draws edge to edge, so these are live insets it has to pay for
/// itself. Every case below runs with them because a device with no system
/// bars is the one condition under which content hiding behind the
/// navigation bar looks fine.
const _statusBar = 24.0;
const _navBar = 48.0;

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget widget,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(
    top: _statusBar,
    bottom: _navBar,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: _statusBar,
    bottom: _navBar,
  );
  addTearDown(tester.view.reset);

  await tester.pumpWidget(widget);

  // The mock repositories answer on a delay, so a bare pump would only ever
  // assert the loading state. Pumping past the longest mock latency is what
  // puts real content on screen.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

/// A session at 100%, which is the tallest a history bar can be and so the
/// only case that can overflow the plot.
final _fullHistory = RangeStats(
  answered: 10,
  correct: 10,
  totalTime: const Duration(seconds: 40),
  breakdown: const [
    SubTopicScore(
      subTopicId: 'iq-age',
      name: 'Age-related problems',
      correct: 10,
      total: 10,
    ),
  ],
  // A full seven-day axis at 100%: the widest the chart gets, with the
  // tallest bars and seven date labels to fit across a 320dp phone.
  history: [
    for (var i = 6; i >= 0; i--)
      DayPoint(
        at: DateTime.now().subtract(Duration(days: i)),
        accuracyPct: 100,
      ),
  ],
);

/// A results page long enough to scroll on a short phone: a full week of
/// bars and the dozen sub-topic rows a real account accumulates.
final _longStats = RangeStats(
  answered: 120,
  correct: 48,
  skipped: 6,
  totalTime: const Duration(minutes: 12),
  breakdown: [
    for (var i = 0; i < 12; i++)
      SubTopicScore(
        subTopicId: 'sub-$i',
        name: 'Sub-topic number $i',
        correct: i,
        total: 12,
      ),
  ],
  history: _fullHistory.history,
);

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
    'devices': DevicesScreen.new,
    'mastery': MasteryScreen.new,
    'notifications': NotificationsScreen.new,
    'results': ResultsScreen.new,
  };

  // Results reads its figures from a provider rather than from the mock
  // repositories, so it needs its own data to render anything at all.
  final resultsOverrides = [
    rangeStatsProvider.overrideWith((ref, range) async => _fullHistory),
  ];

  group('every screen lays out on every Android size', () {
    for (final device in _devices.entries) {
      for (final screen in screens.entries) {
        testWidgets('${screen.key} on ${device.key}', (tester) async {
          await _pumpAt(
            tester,
            device.value,
            _host(
              screen.value(),
              overrides: screen.key == 'results' ? resultsOverrides : const [],
            ),
          );

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

  testWidgets('a history bar fills its track to the accuracy', (tester) async {
    final half = RangeStats(
      answered: 2,
      correct: 1,
      totalTime: const Duration(seconds: 8),
      history: [
        DayPoint(at: DateTime.now(), accuracyPct: 50),
      ],
    );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, range) async => half),
        ],
      ),
    );

    // One bar renders two of these: the full-height ash track, then the
    // green fill stacked on top of it.
    final columns = tester.widgetList<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(columns, hasLength(2));

    final sizes = tester
        .renderObjectList<RenderBox>(find.byType(FractionallySizedBox))
        .map((box) => box.size.height)
        .toList();

    expect(sizes.first, greaterThan(0));
    expect(sizes.last, closeTo(sizes.first / 2, 0.5));
  });

  testWidgets('a long history scrolls rather than overflowing', (tester) async {
    // Sixty days is more bars than any phone can show at a legible width.
    final long = RangeStats(
      answered: 60,
      correct: 30,
      totalTime: const Duration(minutes: 4),
      history: [
        for (var i = 59; i >= 0; i--)
          DayPoint(
            at: DateTime.now().subtract(Duration(days: i)),
            accuracyPct: 100,
          ),
      ],
    );

    await _pumpAt(
      tester,
      const Size(320, 640),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, range) async => long),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    // The chart is the only horizontal scroller on this screen once the
    // range chips fit, and it must exist for sixty bars.
    expect(
      find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      ),
      findsWidgets,
    );
  });

  group('root screens clear the navigation bar', () {
    // These four have no bottom bar under them, so nothing consumes the
    // navigation-bar inset on their behalf. Settings is the one that was
    // reported: "Delete account" sat behind the bar.
    //
    // The short viewport matters: on a tall one these lists fit without
    // scrolling, so the last row clears the bar whatever the padding says.
    const size = Size(320, 640);

    Future<void> scrollToEnd(WidgetTester tester) async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    // The last row of each list, by the text it actually renders.
    const lastRow = <String, String>{
      'settings': 'Delete account',
      // MockContent's IQ sub-topics end here.
      'practice category': 'Sets and Venn diagrams',
    };

    for (final entry in lastRow.entries) {
      testWidgets('${entry.key}: its last row is above the bar',
          (tester) async {
        await _pumpAt(tester, size, _host(screens[entry.key]!()));
        await scrollToEnd(tester);

        final target = find.text(entry.value).last;
        expect(target, findsOneWidget, reason: entry.key);
        expect(
          tester.getRect(target).bottom,
          lessThanOrEqualTo(size.height - _navBar),
          reason: '${entry.key} runs under the navigation bar',
        );
      });
    }

    testWidgets('notifications: its list is padded past the bar',
        (tester) async {
      await _pumpAt(tester, size, _host(screens['notifications']!()));

      // Its rows come from mock data, so the list's own padding is the
      // stable thing to assert on.
      final list = tester.widget<ListView>(find.byType(ListView).first);
      expect(
        (list.padding! as EdgeInsets).bottom,
        greaterThanOrEqualTo(_navBar),
      );
    });

    testWidgets('results: its buttons are above the bar', (tester) async {
      await _pumpAt(
        tester,
        size,
        _host(
          const ResultsScreen(),
          overrides: [
            rangeStatsProvider.overrideWith((ref, range) async => _longStats),
          ],
        ),
      );
      await scrollToEnd(tester);

      expect(
        tester.getRect(find.text('Home').last).bottom,
        lessThanOrEqualTo(size.height - _navBar),
      );
    });
  });

  testWidgets('settings renames the account through the repository',
      (tester) async {
    // Seeded directly rather than through createProfile: the mock answers
    // on a delay, and awaiting one before the first pump deadlocks against
    // the test's fake clock.
    final state = MockBackendState(tier: Tier.basic)
      // currentProfile() returns null unless the session is signed in.
      ..signedIn = true
      ..profile = const UserProfile(
        userId: 'user-mock-1',
        fullName: 'Old Name',
        language: AppLanguage.english,
        msisdn: '0771234821',
      );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const SettingsScreen(),
        overrides: [mockBackendProvider.overrideWithValue(state)],
      ),
    );

    // The name and its Edit button sit in the header's right corner.
    expect(find.text('Old Name'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // The dialog shows the current name above the field for the new one.
    // OverlineLabel renders its text uppercased.
    expect(find.text('CURRENT NAME'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Confirm'));

    // Not pumpAndSettle: the confirm button spins while the write is in
    // flight, and an indefinite animation never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));

    // Written through to the repository, not merely to the widget.
    expect(state.profile!.fullName, 'New Name');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('a rename reaches every screen watching the profile',
      (tester) async {
    final state = MockBackendState(tier: Tier.basic)
      ..signedIn = true
      ..profile = const UserProfile(
        userId: 'user-mock-1',
        // Two words: the home greeting used to show only the first, so a
        // change to the second looked like nothing had happened.
        fullName: 'lakshan vpt',
        language: AppLanguage.english,
        msisdn: '0771234821',
      );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        // Settings above, and a stand-in for every other screen that shows
        // the name, so the assertion is about the profile and not about one
        // screen's plumbing.
        Column(
          children: [
            const Expanded(child: SettingsScreen()),
            Consumer(
              builder: (context, ref, _) => Text(
                ref.watch(profileProvider).valueOrNull?.fullName ?? '',
                textDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
        overrides: [mockBackendProvider.overrideWithValue(state)],
      ),
    );

    // Both the header and the watcher start on the old name.
    expect(find.text('lakshan vpt'), findsNWidgets(2));

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lakshan perera');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('lakshan vpt'), findsNothing);
    expect(find.text('lakshan perera'), findsNWidgets(2));
  });

  testWidgets('home greets the user by their whole name', (tester) async {
    final state = MockBackendState(tier: Tier.basic)
      ..signedIn = true
      ..profile = const UserProfile(
        userId: 'user-mock-1',
        fullName: 'lakshan vpt',
        language: AppLanguage.english,
        msisdn: '0771234821',
      );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const HomeScreen(),
        overrides: [mockBackendProvider.overrideWithValue(state)],
      ),
    );

    expect(find.text('lakshan vpt'), findsOneWidget);
  });

  testWidgets('settings refuses an empty name', (tester) async {
    // Seeded directly rather than through createProfile: the mock answers
    // on a delay, and awaiting one before the first pump deadlocks against
    // the test's fake clock.
    final state = MockBackendState(tier: Tier.basic)
      // currentProfile() returns null unless the session is signed in.
      ..signedIn = true
      ..profile = const UserProfile(
        userId: 'user-mock-1',
        fullName: 'Old Name',
        language: AppLanguage.english,
        msisdn: '0771234821',
      );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const SettingsScreen(),
        overrides: [mockBackendProvider.overrideWithValue(state)],
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Confirm'));
    await tester.pump();

    expect(find.text('Enter your name.'), findsOneWidget);
    expect(state.profile!.fullName, 'Old Name');
  });

  testWidgets('results header falls back to the fetched last session',
      (tester) async {
    // Nothing live: this is the screen opened from home, or after a
    // restart, which is when the header used to read 0%.
    final stats = RangeStats(
      answered: 5,
      correct: 4,
      totalTime: const Duration(seconds: 30),
      history: _fullHistory.history,
      lastSession: const SessionTotals(correct: 4, incorrect: 1, skipped: 0),
    );

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, window) async => stats),
        ],
      ),
    );

    expect(find.text('80%'), findsWidgets);
    expect(find.text('4 of 5 correct'), findsOneWidget);
    expect(find.textContaining('no answers yet'), findsNothing);
  });

  testWidgets('results header says so when there is no session at all',
      (tester) async {
    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, window) async =>
              const RangeStats()),
        ],
      ),
    );

    expect(find.textContaining('no answers yet'), findsOneWidget);
  });

  testWidgets('results custom range asks for days and applies them',
      (tester) async {
    final asked = <ResultsWindow>[];

    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, window) async {
            asked.add(window);
            return _longStats;
          }),
        ],
      ),
    );

    // The fourth chip offers a custom window and asks for its length.
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.text('Custom range'), findsOneWidget);
    // The unit sits beside the field, so the number needs no explaining.
    expect(find.text('days'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '12');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // The chip now names the window, and the figures were re-fetched for it.
    expect(asked.last, const ResultsWindow.custom(12));
    expect(find.text('12 days'), findsWidgets);
  });

  testWidgets('results custom range can be changed once it is active',
      (tester) async {
    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, window) async => _longStats),
        ],
      ),
    );

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('4 days'), findsWidgets);

    // The chip is now the selected one, and tapping it must still ask again
    // rather than being inert.
    await tester.tap(find.text('4 days').first);
    await tester.pumpAndSettle();
    expect(find.text('Custom range'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(find.text('9 days'), findsWidgets);
  });

  testWidgets('results custom range refuses a silly number', (tester) async {
    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const ResultsScreen(),
        overrides: [
          rangeStatsProvider.overrideWith((ref, window) async => _longStats),
        ],
      ),
    );

    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Still open, with the reason shown.
    expect(find.text('Custom range'), findsOneWidget);
    expect(find.text('Enter a whole number of days, 1 to 365.'), findsOneWidget);
  });

  testWidgets('devices signs another device out after confirming',
      (tester) async {
    await _pumpAt(tester, const Size(360, 800), _host(const DevicesScreen()));

    expect(find.text('Redmi Note 12'), findsOneWidget);
    // This device carries no sign-out button of its own.
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out Redmi Note 12?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Redmi Note 12'), findsNothing);
    expect(find.text('Only this device is signed in.'), findsOneWidget);
  });

  testWidgets('mastery lists every sub-topic and marks the weak ones',
      (tester) async {
    final areas = [
      for (var i = 0; i < 6; i++)
        WeakArea(
          subTopicId: 'st-$i',
          name: 'Sub-topic $i',
          accuracy: 30 + i * 12,
          sampleSize: 10 + i,
        ),
    ];
    await _pumpAt(
      tester,
      const Size(412, 915),
      _host(
        const MasteryScreen(),
        overrides: [
          progressProvider.overrideWith(
            (ref) async => ProgressSummary(
              overallAccuracy: 0.55,
              subTopicAccuracy: areas,
              // The server's finding, not every low number: st-1 is below
              // 70 too but is not named, so it must not be tagged.
              weakAreas: [areas.first],
            ),
          ),
        ],
      ),
    );

    // Home stops at three; this screen shows them all.
    for (final area in areas) {
      await tester.scrollUntilVisible(find.text(area.name), 200);
      expect(find.text(area.name), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.text('Sub-topic 0'), -200);
    expect(find.text('10 answered'), findsOneWidget);
    // One tag in the list, plus the "Weak" stat tile label.
    expect(find.text('Weak'), findsOneWidget);
    expect(find.text('WEAK'), findsOneWidget);
  });

  group('screens render in Sinhala and Tamil', () {
    // Both scripts run considerably longer than English for the same string,
    // which is exactly where a fixed-height row or an unwrapped Row starts
    // to overflow. The narrowest device is the honest test.
    for (final language in [AppLanguage.sinhala, AppLanguage.tamil]) {
      for (final name in [
        'landing',
        'home',
        'practice category',
        'settings',
        'devices',
        'mastery',
      ]) {
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
    for (final name in [
      'home',
      'settings',
      'notifications',
      'tutor',
      'devices',
      'mastery',
    ]) {
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
