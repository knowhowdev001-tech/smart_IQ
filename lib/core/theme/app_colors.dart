import 'package:flutter/material.dart';

/// The single design-token set that drives both themes.
///
/// PRD 6.9 forbids hardcoded colours anywhere in the widget tree: every
/// surface, border and ink in the app resolves through an [AppColors]
/// instance read from the theme, never through a literal.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brand,
    required this.brandInk,
    required this.brandInkMuted,
    required this.brandSurface,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.accentSoftInk,
    required this.page,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceSunken,
    required this.inverseSurface,
    required this.inverseInk,
    required this.inverseInkMuted,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.field,
    required this.danger,
    required this.dangerInk,
    required this.dangerSurface,
    required this.dangerBorder,
    required this.success,
    required this.warning,
    required this.shadow,
    required this.mediaCanvas,
    required this.mediaCanvasInk,
  });

  /// Mint header band that anchors nearly every screen in the design.
  final Color brand;

  /// Deep green used for text and icons sitting on [brand].
  final Color brandInk;
  final Color brandInkMuted;

  /// Translucent white cards that sit inside the mint band.
  final Color brandSurface;

  /// Primary call-to-action green.
  final Color accent;
  final Color accentInk;

  /// Pale green used for chips, icon tiles and quiet fills.
  final Color accentSoft;
  final Color accentSoftInk;

  final Color page;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceSunken;

  /// Near-black panel used for the daily challenge and plan cards.
  final Color inverseSurface;
  final Color inverseInk;
  final Color inverseInkMuted;

  final Color ink;
  final Color inkMuted;
  final Color inkFaint;

  final Color border;
  final Color borderStrong;
  final Color divider;
  final Color field;

  final Color danger;
  final Color dangerInk;
  final Color dangerSurface;
  final Color dangerBorder;

  final Color success;
  final Color warning;
  final Color shadow;

  /// Question diagrams are black line art. PRD 6.9 requires them to stay
  /// legible in dark mode, so they always render on this fixed light
  /// surface rather than inheriting the page background.
  final Color mediaCanvas;
  final Color mediaCanvasInk;

  static const light = AppColors(
    brand: Color(0xFF12E29B),
    brandInk: Color(0xFF0B2A1E),
    brandInkMuted: Color(0xB30B2A1E),
    brandSurface: Color(0x9EFFFFFF),
    accent: Color(0xFF0BC886),
    accentInk: Color(0xFF04291D),
    accentSoft: Color(0xFFDEF6EB),
    accentSoftInk: Color(0xFF0A6A49),
    page: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF1FBF5),
    surfaceSunken: Color(0xFFF7FAF8),
    inverseSurface: Color(0xFF12211B),
    inverseInk: Color(0xFFF1FBF5),
    inverseInkMuted: Color(0xADF1FBF5),
    ink: Color(0xFF12211B),
    inkMuted: Color(0xFF7F9289),
    inkFaint: Color(0xFFA3B5AC),
    border: Color(0xFFE6F2EC),
    borderStrong: Color(0xFFCFE7DC),
    divider: Color(0xFFEEF4F1),
    field: Color(0xFFDEF6EB),
    danger: Color(0xFFEC3013),
    dangerInk: Color(0xFFB4310F),
    dangerSurface: Color(0xFFFDEEE9),
    dangerBorder: Color(0xFFF6CFC3),
    success: Color(0xFF0BC886),
    warning: Color(0xFFE9973F),
    shadow: Color(0x3D0B2A1E),
    mediaCanvas: Color(0xFFF7FAF8),
    mediaCanvasInk: Color(0xFF12211B),
  );

  /// Dark theme keeps the mint brand band — it is the product's identity —
  /// but drops the page and card surfaces to deep green-black. Body inks
  /// are deliberately high-contrast: PRD 6.9 flags that Sinhala and Tamil
  /// lose legibility faster than Latin on low-contrast dark grounds.
  static const dark = AppColors(
    brand: Color(0xFF0BC886),
    brandInk: Color(0xFF03170F),
    brandInkMuted: Color(0xC203170F),
    brandSurface: Color(0x2E04291D),
    accent: Color(0xFF12E29B),
    accentInk: Color(0xFF03170F),
    accentSoft: Color(0xFF12362A),
    accentSoftInk: Color(0xFF6FE7BE),
    page: Color(0xFF0A1410),
    surface: Color(0xFF11201A),
    surfaceMuted: Color(0xFF16291F),
    surfaceSunken: Color(0xFF0E1B15),
    inverseSurface: Color(0xFF1D3329),
    inverseInk: Color(0xFFEFFBF4),
    inverseInkMuted: Color(0xADEFFBF4),
    ink: Color(0xFFEFFBF4),
    inkMuted: Color(0xFF9BB3A7),
    inkFaint: Color(0xFF74907F),
    border: Color(0xFF24382E),
    borderStrong: Color(0xFF33513F),
    divider: Color(0xFF1E3128),
    field: Color(0xFF172C22),
    danger: Color(0xFFFF6B4A),
    dangerInk: Color(0xFFFF9C82),
    dangerSurface: Color(0xFF33150D),
    dangerBorder: Color(0xFF5C2417),
    success: Color(0xFF12E29B),
    warning: Color(0xFFF0AC5E),
    shadow: Color(0x66000000),
    mediaCanvas: Color(0xFFF4F8F6),
    mediaCanvasInk: Color(0xFF12211B),
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandInk,
    Color? brandInkMuted,
    Color? brandSurface,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? accentSoftInk,
    Color? page,
    Color? surface,
    Color? surfaceMuted,
    Color? surfaceSunken,
    Color? inverseSurface,
    Color? inverseInk,
    Color? inverseInkMuted,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? field,
    Color? danger,
    Color? dangerInk,
    Color? dangerSurface,
    Color? dangerBorder,
    Color? success,
    Color? warning,
    Color? shadow,
    Color? mediaCanvas,
    Color? mediaCanvasInk,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandInk: brandInk ?? this.brandInk,
      brandInkMuted: brandInkMuted ?? this.brandInkMuted,
      brandSurface: brandSurface ?? this.brandSurface,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      accentSoftInk: accentSoftInk ?? this.accentSoftInk,
      page: page ?? this.page,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      inverseSurface: inverseSurface ?? this.inverseSurface,
      inverseInk: inverseInk ?? this.inverseInk,
      inverseInkMuted: inverseInkMuted ?? this.inverseInkMuted,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      field: field ?? this.field,
      danger: danger ?? this.danger,
      dangerInk: dangerInk ?? this.dangerInk,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      shadow: shadow ?? this.shadow,
      mediaCanvas: mediaCanvas ?? this.mediaCanvas,
      mediaCanvasInk: mediaCanvasInk ?? this.mediaCanvasInk,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      brand: mix(brand, other.brand),
      brandInk: mix(brandInk, other.brandInk),
      brandInkMuted: mix(brandInkMuted, other.brandInkMuted),
      brandSurface: mix(brandSurface, other.brandSurface),
      accent: mix(accent, other.accent),
      accentInk: mix(accentInk, other.accentInk),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentSoftInk: mix(accentSoftInk, other.accentSoftInk),
      page: mix(page, other.page),
      surface: mix(surface, other.surface),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      inverseSurface: mix(inverseSurface, other.inverseSurface),
      inverseInk: mix(inverseInk, other.inverseInk),
      inverseInkMuted: mix(inverseInkMuted, other.inverseInkMuted),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      divider: mix(divider, other.divider),
      field: mix(field, other.field),
      danger: mix(danger, other.danger),
      dangerInk: mix(dangerInk, other.dangerInk),
      dangerSurface: mix(dangerSurface, other.dangerSurface),
      dangerBorder: mix(dangerBorder, other.dangerBorder),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      shadow: mix(shadow, other.shadow),
      mediaCanvas: mix(mediaCanvas, other.mediaCanvas),
      mediaCanvasInk: mix(mediaCanvasInk, other.mediaCanvasInk),
    );
  }
}
