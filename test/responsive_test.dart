import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_iq/core/theme/app_scale.dart';

void main() {
  group('AppScale', () {
    test('classifies the Android device sizes the app has to cover', () {
      // A 320dp budget phone, the mainstream 360-412dp band, a large phone
      // and a tablet. These are the four cases every screen must survive.
      expect(
        AppScale.fromSize(const Size(320, 640)).screenClass,
        ScreenClass.compact,
      );
      expect(
        AppScale.fromSize(const Size(360, 800)).screenClass,
        ScreenClass.regular,
      );
      expect(
        AppScale.fromSize(const Size(412, 915)).screenClass,
        ScreenClass.regular,
      );
      expect(
        AppScale.fromSize(const Size(480, 1040)).screenClass,
        ScreenClass.large,
      );
      expect(
        AppScale.fromSize(const Size(800, 1280)).screenClass,
        ScreenClass.expanded,
      );
    });

    test('scales up and down from the design width', () {
      // The design was drawn at 372dp. A narrower device scales below 1 and
      // a wider one above, so layouts keep their proportions rather than
      // stretching only in one axis.
      final small = AppScale.fromSize(const Size(320, 640));
      final wide = AppScale.fromSize(const Size(480, 1040));

      expect(small.scale, lessThan(1));
      expect(wide.scale, greaterThan(1));
    });

    test('clamps the scale so text stays legible and layouts stay honest',
        () {
      // Below 0.88 Sinhala and Tamil descenders start clipping; above 1.18
      // the design reads as a blown-up phone screen.
      final tiny = AppScale.fromSize(const Size(200, 400));
      final huge = AppScale.fromSize(const Size(1600, 2560));

      expect(tiny.scale, greaterThanOrEqualTo(0.88));
      expect(huge.scale, lessThanOrEqualTo(1.18));
    });

    test('caps the content column so tablets centre rather than stretch', () {
      final tablet = AppScale.fromSize(const Size(1024, 1366));
      expect(tablet.contentWidth, kMaxContentWidth);

      // A phone is never capped, so it pays nothing for the tablet rule.
      final phone = AppScale.fromSize(const Size(360, 800));
      expect(phone.contentWidth, 360);
    });

    test('measures landscape against the short edge', () {
      // In landscape the usable measure for a single-column reading layout
      // is the height, not the very wide width.
      final landscape = AppScale.fromSize(const Size(915, 412));
      expect(landscape.isLandscape, isTrue);
      expect(landscape.contentWidth, 412);
    });
  });

  group('ResponsiveScope', () {
    testWidgets('clamps an extreme platform text scale', (tester) async {
      late AppScale scale;
      late TextScaler textScaler;

      await tester.pumpWidget(
        MediaQuery(
          // Android allows font scaling up to 2.0, which would break the
          // denser screens outright.
          data: const MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(2),
          ),
          child: ResponsiveScope(
            child: Builder(
              builder: (context) {
                scale = AppScale.of(context);
                textScaler = MediaQuery.textScalerOf(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(scale.screenClass, ScreenClass.regular);
      expect(textScaler.scale(10), lessThanOrEqualTo(13.0));
    });

    testWidgets('publishes metrics to the subtree', (tester) async {
      late double dp;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(372, 792)),
          child: ResponsiveScope(
            child: Builder(
              builder: (context) {
                dp = 16.dp(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // At exactly the design width, a design-space value passes through
      // unchanged.
      expect(dp, closeTo(16, 0.01));
    });
  });
}
