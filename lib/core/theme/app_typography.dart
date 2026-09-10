import 'package:flutter/material.dart';

import 'app_scale.dart';

/// Font families bundled with the app. PRD 4.2 forbids relying on system
/// fonts for Sinhala and Tamil, which render inconsistently on older
/// Android builds and produce clipped or substituted glyphs.
abstract final class AppFonts {
  static const latin = 'Archivo';
  static const sinhala = 'NotoSansSinhala';
  static const tamil = 'NotoSansTamil';

  /// Resolves the primary family for a locale, with the other two behind it
  /// so a screen mixing scripts — an English label above a Sinhala
  /// sub-topic name — never falls back to a system font mid-string.
  static String primaryFor(Locale locale) => switch (locale.languageCode) {
        'si' => sinhala,
        'ta' => tamil,
        _ => latin,
      };

  static List<String> fallbackFor(Locale locale) => switch (
      locale.languageCode) {
        'si' => const [latin, tamil],
        'ta' => const [latin, sinhala],
        _ => const [sinhala, tamil],
      };
}

/// A design-space text style. Sizes are authored against the 372dp
/// reference width and scaled at the point of use.
@immutable
class AppTextStyles {
  const AppTextStyles._();

  /// Landing wordmark.
  static const display = TextStyle(fontSize: 30, height: 1.15, letterSpacing: -0.9);

  /// The 46px results percentage.
  static const score = TextStyle(fontSize: 46, height: 1, letterSpacing: -1.4);

  /// Auth screen headline.
  static const headline = TextStyle(fontSize: 25, height: 1.2, letterSpacing: -0.5);

  /// Screen titles in the mint band.
  static const title = TextStyle(fontSize: 20, height: 1.2, letterSpacing: -0.4);
  static const titleSmall = TextStyle(fontSize: 16, height: 1.25, letterSpacing: -0.2);

  /// Numeric values in stat tiles.
  static const stat = TextStyle(fontSize: 17, height: 1.2);

  /// Question stem.
  static const stem = TextStyle(fontSize: 15, height: 1.55);

  /// Section headers such as "Practice by category".
  static const section = TextStyle(fontSize: 12.5, height: 1.3);

  static const body = TextStyle(fontSize: 13, height: 1.55);
  static const bodySmall = TextStyle(fontSize: 12, height: 1.5);
  static const caption = TextStyle(fontSize: 11, height: 1.5);
  static const captionSmall = TextStyle(fontSize: 10.5, height: 1.5);

  /// Uppercase tracked labels: "STREAK", "READINESS", "THIS SESSION".
  static const overline =
      TextStyle(fontSize: 9.5, height: 1.3, letterSpacing: 0.66);

  static const button = TextStyle(fontSize: 14, height: 1.2);
  static const buttonSmall = TextStyle(fontSize: 12.5, height: 1.2);
}

/// Resolves design-space styles into painted, scaled, locale-correct ones.
extension AppTextContext on BuildContext {
  /// Scales a design-space style and binds it to the locale's font stack.
  ///
  /// [weight] maps onto the variable fonts' `wght` axis. All three bundled
  /// families ship as variable TTFs, so the weight must be applied as a
  /// [FontVariation] — a bare [FontWeight] on a variable font renders at the
  /// default weight and silently ignores the request.
  TextStyle text(
    TextStyle base, {
    double weight = 400,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    final scale = AppScale.of(this).scale;
    final locale = Localizations.maybeLocaleOf(this) ?? const Locale('en');

    return base.copyWith(
      fontSize: (base.fontSize ?? 14) * scale,
      fontFamily: AppFonts.primaryFor(locale),
      fontFamilyFallback: AppFonts.fallbackFor(locale),
      fontWeight: _nearestWeight(weight),
      fontVariations: [FontVariation('wght', weight)],
      color: color,
      height: height ?? base.height,
      letterSpacing: (letterSpacing ?? base.letterSpacing ?? 0) * scale,
      decoration: decoration,
      // Sinhala and Tamil carry tall ascenders and deep descenders. Letting
      // Flutter trim the first and last lines to the tight glyph box clips
      // them; keeping the full metrics is what stops that.
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// The `wght` axis is authoritative for rendering, but a matching
  /// [FontWeight] keeps `TextStyle` comparisons and any synthetic-bold
  /// fallback path sensible.
  static FontWeight _nearestWeight(double weight) {
    final index = ((weight / 100).round() - 1).clamp(0, 8);
    return FontWeight.values[index];
  }
}
