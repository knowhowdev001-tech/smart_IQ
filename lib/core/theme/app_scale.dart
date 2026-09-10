import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Width of the phone screen the design was drawn against.
const double kDesignWidth = 372;

/// Height of the design's inner phone screen, used only for proportional
/// vertical rhythm on very tall or very short devices.
const double kDesignHeight = 792;

/// Above this width the layout stops growing and centres instead. Android
/// tablets and foldables are far wider than any phone the design targets,
/// and stretching a single-column reading layout across 900dp produces
/// unreadably long lines rather than a better experience.
const double kMaxContentWidth = 520;

/// Device size buckets. Layouts branch on these only where the design
/// genuinely needs a different arrangement, not for routine sizing.
enum ScreenClass {
  /// Small phones, roughly 320-359dp wide. Galaxy A0x, older budget devices.
  compact,

  /// The mainstream Android phone, roughly 360-413dp wide.
  regular,

  /// Large phones, 414dp and up.
  large,

  /// Tablets, foldables opened, and anything past 600dp.
  expanded,
}

/// Resolved responsive metrics for the current device.
///
/// Every dimension in the app is authored at the design's 372dp reference
/// width and converted through [scale], so the same widget tree renders
/// proportionally on a 320dp budget phone and a 600dp tablet without any
/// per-device layout code.
@immutable
class AppScale {
  const AppScale({
    required this.scale,
    required this.contentWidth,
    required this.screenClass,
    required this.screenSize,
    required this.isLandscape,
  });

  /// Multiplier applied to every design-space dimension.
  final double scale;

  /// Width the content column actually occupies, after tablet capping.
  final double contentWidth;

  final ScreenClass screenClass;
  final Size screenSize;
  final bool isLandscape;

  bool get isExpanded => screenClass == ScreenClass.expanded;
  bool get isCompact => screenClass == ScreenClass.compact;

  /// Converts a design-space dimension to logical pixels.
  double dp(double designValue) => designValue * scale;

  static AppScale of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_AppScaleScope>();
    assert(
      inherited != null,
      'AppScale.of() called without a ResponsiveScope ancestor. Wrap the '
      'app (or the screen under test) in a ResponsiveScope.',
    );
    return inherited!.data;
  }

  /// Derives metrics from a raw screen size.
  factory AppScale.fromSize(Size size) {
    final shortestSide = math.min(size.width, size.height);
    final isLandscape = size.width > size.height;

    final screenClass = switch (shortestSide) {
      < 360 => ScreenClass.compact,
      < 414 => ScreenClass.regular,
      < 600 => ScreenClass.large,
      _ => ScreenClass.expanded,
    };

    // The column never exceeds kMaxContentWidth, so on tablets and in
    // landscape the content centres rather than stretching.
    final available = isLandscape ? size.height : size.width;
    final contentWidth = math.min(available, kMaxContentWidth);

    // Scale from the design width, but clamp hard at both ends. Below 0.88
    // Sinhala and Tamil glyphs start losing their descenders; above 1.18 the
    // layout reads as a blown-up phone screen rather than a designed one.
    final rawScale = contentWidth / kDesignWidth;
    final scale = rawScale.clamp(0.88, 1.18);

    return AppScale(
      scale: scale,
      contentWidth: contentWidth,
      screenClass: screenClass,
      screenSize: size,
      isLandscape: isLandscape,
    );
  }
}

/// Publishes [AppScale] to the subtree and constrains the content column.
///
/// Also clamps the platform text scale. Android lets the user push font
/// size to 2.0x, which would break the denser parts of this design outright;
/// clamping to 1.3 keeps the accessibility gain without shredding the layout,
/// and every screen additionally scrolls so clipped text is never possible.
class ResponsiveScope extends StatelessWidget {
  const ResponsiveScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final data = AppScale.fromSize(media.size);

    return _AppScaleScope(
      data: data,
      child: MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(
            minScaleFactor: 0.85,
            maxScaleFactor: 1.3,
          ),
        ),
        child: child,
      ),
    );
  }
}

class _AppScaleScope extends InheritedWidget {
  const _AppScaleScope({required this.data, required super.child});

  final AppScale data;

  @override
  bool updateShouldNotify(_AppScaleScope oldWidget) => data != oldWidget.data;
}

/// Sugar for reading scaled dimensions: `16.dp(context)`.
extension ScaledNum on num {
  double dp(BuildContext context) => AppScale.of(context).dp(toDouble());
}

/// Centres a page's content column on wide screens.
///
/// Phones get the full width and pay nothing; tablets and landscape get a
/// readable measure instead of a stretched one.
class ContentColumn extends StatelessWidget {
  const ContentColumn({required this.child, this.alignment, super.key});

  final Widget child;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment ?? Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );
  }
}
