import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/enums.dart';

/// Theme and language, the two preferences that must be known before the
/// first frame.
///
/// PRD 6.9 forbids a flash of the wrong theme on cold start, and PRD 7.3
/// requires the splash and loading states to be themed correctly while
/// entitlement is still resolving. Both are satisfied by reading these
/// synchronously from disk in `main()` and seeding the provider with them,
/// so no frame is ever built against a default that is about to change.
@immutable
class AppSettings {
  const AppSettings({
    required this.theme,
    required this.language,
    this.languageChosen = false,
  });

  final ThemePreference theme;
  final AppLanguage language;

  /// False until the user has actually picked a language. Until then the
  /// device locale drives the UI, which is what PRD 6.2 means by
  /// pre-selecting from the device locale where it maps cleanly.
  final bool languageChosen;

  AppSettings copyWith({
    ThemePreference? theme,
    AppLanguage? language,
    bool? languageChosen,
  }) =>
      AppSettings(
        theme: theme ?? this.theme,
        language: language ?? this.language,
        languageChosen: languageChosen ?? this.languageChosen,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.theme == theme &&
          other.language == language &&
          other.languageChosen == languageChosen;

  @override
  int get hashCode => Object.hash(theme, language, languageChosen);
}

abstract final class _Keys {
  static const theme = 'settings.theme';
  static const language = 'settings.language';
  static const languageChosen = 'settings.language_chosen';
}

/// Set in `main()` once preferences are on disk. Kept as an override rather
/// than an async read so the first build already has real values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError(
    'sharedPreferencesProvider must be overridden in main() before runApp.',
  ),
);

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._prefs, AppSettings initial) : super(initial);

  final SharedPreferences _prefs;

  /// Reads settings synchronously. Falls back to the device locale for
  /// language and to System for theme, both of which are the PRD defaults.
  static AppSettings read(SharedPreferences prefs, Locale deviceLocale) {
    final chosen = prefs.getBool(_Keys.languageChosen) ?? false;
    return AppSettings(
      theme: ThemePreference.fromName(prefs.getString(_Keys.theme)),
      language: chosen
          ? AppLanguage.fromCode(prefs.getString(_Keys.language))
          : AppLanguage.fromDeviceLocale(deviceLocale),
      languageChosen: chosen,
    );
  }

  Future<void> setTheme(ThemePreference theme) async {
    state = state.copyWith(theme: theme);
    await _prefs.setString(_Keys.theme, theme.name);
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = state.copyWith(language: language, languageChosen: true);
    await _prefs.setString(_Keys.language, language.code);
    await _prefs.setBool(_Keys.languageChosen, true);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final locale =
      WidgetsBinding.instance.platformDispatcher.locale;
  return AppSettingsController(prefs, AppSettingsController.read(prefs, locale));
});

/// The active language, which drives both the UI locale and which variant of
/// each question is shown.
final languageProvider = Provider<AppLanguage>(
  (ref) => ref.watch(appSettingsProvider).language,
);
