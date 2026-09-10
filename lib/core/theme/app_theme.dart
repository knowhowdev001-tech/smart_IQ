import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Design-space corner radii, in the design's 372dp reference units.
abstract final class AppRadii {
  static const xs = 9.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 18.0;
  static const xl = 22.0;
  static const xxl = 26.0;

  /// Header bands curve into the page below them.
  static const headerBand = 26.0;

  /// Bottom sheets.
  static const sheet = 26.0;
}

/// Design-space spacing steps.
abstract final class AppSpacing {
  static const xxs = 3.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 26.0;

  /// Standard horizontal page gutter in the design.
  static const gutter = 22.0;
}

/// Design-space control heights.
abstract final class AppSizes {
  static const buttonHeight = 46.0;
  static const buttonHeightSmall = 38.0;
  static const fieldHeight = 46.0;
  static const iconButton = 34.0;
  static const minTapTarget = 48.0;
}

abstract final class AppTheme {
  static ThemeData light() => _build(AppColors.light, Brightness.light);
  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);

  static ThemeData _build(AppColors colors, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: colors.accentInk,
      secondary: colors.brand,
      onSecondary: colors.brandInk,
      surface: colors.surface,
      onSurface: colors.ink,
      error: colors.danger,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      fontFamily: AppFonts.latin,
      extensions: [colors],
      splashFactory: InkSparkle.splashFactory,
      // Every tappable surface in this design draws its own pressed state,
      // so the default Material overlays would double up.
      highlightColor: Colors.transparent,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.brand,
        foregroundColor: colors.brandInk,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: colors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(color: colors.inverseInk),
        behavior: SnackBarBehavior.floating,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  /// System bars matched to the band colour at the top of each screen.
  static SystemUiOverlayStyle overlayFor(Brightness brightness) {
    // The mint band is light in both themes, so status bar icons stay dark
    // on top of it regardless of the app theme.
    return const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ).copyWith(
      systemNavigationBarColor:
          brightness == Brightness.dark ? AppColors.dark.page : AppColors.light.page,
      systemNavigationBarIconBrightness:
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
    );
  }
}

/// Reads the token set out of the theme: `context.colors.accent`.
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
