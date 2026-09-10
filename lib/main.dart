import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preferences are read before the first frame so the theme and language
  // are already correct when it paints. PRD 6.9 forbids a flash of the
  // wrong theme on cold start, and that is only achievable by resolving
  // this ahead of runApp rather than inside a FutureBuilder.
  final prefs = await SharedPreferences.getInstance();

  // The app is portrait-only. The design is a single-column phone layout,
  // and landscape would stretch it without adding anything.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Draw behind the system bars so the mint header runs under the status
  // bar the way the design shows it.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SmartIqApp(),
    ),
  );
}
